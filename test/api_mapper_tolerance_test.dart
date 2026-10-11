import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/services/api_mapper.dart';

Map<String, dynamic> eventJson({
  String eventType = 'hackathon',
  String? registrationStatus,
  List<Map<String, dynamic>> deadlines = const [],
}) =>
    {
      'id': 'e1',
      'user_id': 'u1',
      'title': 'Hack',
      'event_type': eventType,
      'start_at': '2031-03-01T10:00:00+00:00',
      'timezone': 'UTC',
      'status': 'upcoming',
      if (registrationStatus != null) 'registration_status': registrationStatus,
      'deadlines': deadlines,
      'created_at': '2031-01-01T00:00:00+00:00',
      'updated_at': '2031-01-01T00:00:00+00:00',
    };

Map<String, dynamic> deadline(String type, {String status = 'active'}) => {
      'id': 'd-$type',
      'event_id': 'e1',
      'user_id': 'u1',
      'title': 'Something',
      'deadline_type': type,
      'deadline_at': '2031-02-01T10:00:00+00:00',
      'status': status,
      'created_at': '2031-01-01T00:00:00+00:00',
    };

void main() {
  group('one unknown value never stops an event from loading', () {
    test('a deadline type the app does not know becomes custom', () {
      final event = eventFromApi(eventJson(deadlines: [
        deadline('team_formation'),
        deadline('registration_deadline'),
        deadline('registration'),
      ]));
      expect(event.deadlines.map((d) => d.deadlineType), [
        DeadlineType.custom,
        DeadlineType.custom,
        DeadlineType.registration,
      ]);
    });

    test('an unknown event type becomes custom', () {
      expect(eventFromApi(eventJson(eventType: 'Party time')).eventType, EventType.custom);
    });

    test('an unknown or missing registration status becomes not started', () {
      expect(eventFromApi(eventJson()).registrationStatus, RegistrationStatus.notStarted);
      expect(eventFromApi(eventJson(registrationStatus: 'mystery')).registrationStatus, RegistrationStatus.notStarted);
    });
  });

  group('registration status', () {
    test('reads the backend values, including the snake_case ones', () {
      expect(eventFromApi(eventJson(registrationStatus: 'in_progress')).registrationStatus, RegistrationStatus.inProgress);
      expect(eventFromApi(eventJson(registrationStatus: 'not_eligible')).registrationStatus, RegistrationStatus.notEligible);
      expect(eventFromApi(eventJson(registrationStatus: 'registered')).registrationStatus, RegistrationStatus.registered);
    });

    test('every status round-trips through its wire value', () {
      for (final status in RegistrationStatus.values) {
        final back = eventFromApi(eventJson(registrationStatus: status.apiValue)).registrationStatus;
        expect(back, status, reason: status.apiValue);
      }
    });

    test('the wire values are the ones the backend accepts', () {
      expect(RegistrationStatus.values.map((s) => s.apiValue).toSet(), {
        'not_started', 'planned', 'in_progress', 'registered',
        'waitlisted', 'failed', 'not_eligible', 'skipped', 'expired',
      });
    });

    test('only the finished states stop reminders, like the backend', () {
      expect(
        RegistrationStatus.values.where((s) => s.stopsReminders).toSet(),
        {RegistrationStatus.registered, RegistrationStatus.skipped, RegistrationStatus.notEligible, RegistrationStatus.expired},
      );
    });

    test('an event survives toJson and fromJson with its status', () {
      final event = eventFromApi(eventJson(registrationStatus: 'waitlisted'));
      expect(Event.fromJson(event.toJson()).registrationStatus, RegistrationStatus.waitlisted);
    });
  });

  group('reminders with values the app does not know', () {
    Map<String, dynamic> reminder({String? type, String? priority, String? status, String? source}) => {
          'id': 'r1',
          'user_id': 'u1',
          'title': 'Pay rent',
          'reminder_type': type ?? 'time',
          'priority': priority ?? 'medium',
          'status': status ?? 'active',
          'source': source ?? 'manual',
          'scheduled_at': '2031-01-01T05:00:00+00:00',
          'timezone': 'UTC',
          'offsets': [],
          'created_at': '2031-01-01T00:00:00+00:00',
          'updated_at': '2031-01-01T00:00:00+00:00',
        };

    test('fall back to safe defaults instead of throwing', () {
      final r = reminderFromApi(reminder(type: 'weird', priority: 'urgent', status: 'bogus', source: 'robot'));
      expect(r.title, 'Pay rent');
      expect(r.priority.name, 'medium');
      expect(r.status.name, 'active');
    });

    test('still understand every value the app itself sends', () {
      expect(reminderFromApi(reminder(type: 'follow_up')).reminderType.name, 'followUp');
      expect(reminderFromApi(reminder(source: 'event')).source.name, 'eventPolicy');
      expect(reminderFromApi(reminder(source: 'ai_extracted')).source.name, 'aiExtracted');
    });
  });
}
