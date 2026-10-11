import 'package:flutter/foundation.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/services/reminder_service.dart';
import 'package:personal_memory_os/core/services/notification_service.dart';

enum ReminderFilter { all, today, upcoming, recurring, deadlines, completed, overdue }

class ReminderProvider extends ChangeNotifier {
  final ReminderService _service;

  ReminderProvider(this._service);

  List<Reminder> _reminders = [];
  ReminderFilter _activeFilter = ReminderFilter.today;
  bool _isLoading = false;
  String? _error;

  List<Reminder> get reminders => _reminders;
  ReminderFilter get activeFilter => _activeFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Computed lists ────────────────────────────────────────────────────────

  List<Reminder> get todayReminders {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return _reminders
        .where((r) =>
            r.status == ReminderStatus.active &&
            r.scheduledAt != null &&
            r.scheduledAt!.isAfter(todayStart) &&
            r.scheduledAt!.isBefore(todayEnd))
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }

  List<Reminder> get upcomingReminders {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _reminders
        .where((r) =>
            r.status == ReminderStatus.active &&
            r.scheduledAt != null &&
            r.scheduledAt!.isAfter(tomorrow))
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  }

  List<Reminder> get overdueReminders {
    final now = DateTime.now();
    return _reminders
        .where((r) =>
            r.status == ReminderStatus.active &&
            r.scheduledAt != null &&
            r.scheduledAt!.isBefore(now))
        .toList()
      ..sort((a, b) => b.scheduledAt!.compareTo(a.scheduledAt!));
  }

  List<Reminder> get nextReminder {
    final now = DateTime.now();
    final upcoming = _reminders
        .where((r) =>
            r.status == ReminderStatus.active &&
            r.scheduledAt != null &&
            r.scheduledAt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return upcoming.take(1).toList();
  }

  List<Reminder> get filteredReminders {
    switch (_activeFilter) {
      case ReminderFilter.today:
        return todayReminders;
      case ReminderFilter.upcoming:
        return upcomingReminders;
      case ReminderFilter.overdue:
        return overdueReminders;
      case ReminderFilter.recurring:
        return _reminders.where((r) => r.recurrenceRule != null).toList();
      case ReminderFilter.deadlines:
        return _reminders
            .where((r) => r.reminderType == ReminderType.deadline)
            .toList();
      case ReminderFilter.completed:
        return _reminders
            .where((r) => r.status == ReminderStatus.completed)
            .toList();
      case ReminderFilter.all:
        return _reminders;
    }
  }

  void setFilter(ReminderFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> loadReminders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reminders = await _service.fetchReminders();
      // Keep the device layer in step with the server: schedule what is active, and silence
      // what was stopped elsewhere (a finished milestone, the web, another phone).
      for (final r in _reminders) {
        if (r.status == ReminderStatus.active && r.alarmEnabled) {
          await NotificationService.scheduleReminder(r);
        } else if (r.status == ReminderStatus.cancelled || r.status == ReminderStatus.completed) {
          await NotificationService.cancelReminder(r.id);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> createReminder(Reminder reminder) async {
    try {
      final created = await _service.createReminder(reminder);
      _reminders.add(created);
      // Schedule device-side local notification (layer 2 of two-layer alarm)
      if (created.alarmEnabled) {
        try {
          await NotificationService.scheduleReminder(created);
        } catch (e) {
          // The reminder exists (and the cloud layer will still fire it); a failed
          // local alarm must not make creation look failed and invite a duplicate.
          _error = 'Reminder saved, but the device alarm could not be set: $e';
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> completeReminder(String id) async {
    try {
      await _service.updateReminderStatus(id, ReminderStatus.completed);
      // Cancel local notification — reminder is done
      await NotificationService.cancelReminder(id);
      // Conditional reminders ("if not done by Friday") are moot once this is done.
      for (final dependent in _reminders.where((r) => r.dependsOnId == id)) {
        await NotificationService.cancelReminder(dependent.id);
      }
      final index = _reminders.indexWhere((r) => r.id == id);
      if (index != -1) {
        _reminders[index] =
            _reminders[index].copyWith(status: ReminderStatus.completed);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> snoozeReminder(String id, Duration duration) async {
    try {
      final newTime = DateTime.now().add(duration);
      await _service.snoozeReminder(id, newTime);
      final index = _reminders.indexWhere((r) => r.id == id);
      if (index != -1) {
        final updated = _reminders[index].copyWith(
          status: ReminderStatus.snoozed,
          scheduledAt: newTime,
        );
        _reminders[index] = updated;
        // Cancel old notification and reschedule at new time
        await NotificationService.cancelReminder(id);
        if (updated.alarmEnabled) {
          await NotificationService.scheduleReminder(updated);
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _service.deleteReminder(id);
      // Cancel local notification before removing from list
      await NotificationService.cancelReminder(id);
      _reminders.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
