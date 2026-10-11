import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/models/account_settings.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/core/services/account_service.dart';
import 'package:personal_memory_os/core/services/device_timezone.dart';
import 'package:personal_memory_os/core/services/timezone_sync.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/error_text.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';

/// Timezone, quiet hours and notification history, kept on the server so the cloud alarm
/// follows them even when the phone is off.
class ReminderSettingsSection extends StatefulWidget {
  final TimezoneSource timezoneSource;

  const ReminderSettingsSection({super.key, this.timezoneSource = deviceTimezone});

  @override
  State<ReminderSettingsSection> createState() => _ReminderSettingsSectionState();
}

class _ReminderSettingsSectionState extends State<ReminderSettingsSection> {
  AccountSettings? _settings;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final settings = await context.read<AccountService>().getSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _say(String text, {bool problem = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: problem ? AppColors.urgent : null),
    );
  }

  Future<void> _update({String? timezone, bool? enabled, int? start, int? end}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settings = await context.read<AccountService>().updateSettings(
            timezone: timezone,
            quietHoursEnabled: enabled,
            quietHoursStart: start,
            quietHoursEnd: end,
          );
      if (mounted) setState(() => _settings = settings);
    } catch (e) {
      if (mounted) _say(friendlyError(e.toString()), problem: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useDeviceTimezone() async {
    final device = await widget.timezoneSource();
    if (!mounted) return;
    if (device == null) {
      _say("Couldn't read this phone's time zone.", problem: true);
      return;
    }
    await _update(timezone: device);
    if (mounted && _error == null) _say('Time zone set to $device');
  }

  Future<void> _editWindow(AccountSettings current) async {
    var start = current.quietHoursStart;
    var end = current.quietHoursEnd;
    final chosen = await showDialog<(int, int)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Quiet hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reminders in this window are held back. High-priority reminders still ring.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              _HourPicker(label: 'From', value: start, onChanged: (h) => setDialog(() => start = h)),
              _HourPicker(label: 'Until', value: end, onChanged: (h) => setDialog(() => end = h)),
              if (start == end)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Start and end must be different.', style: TextStyle(color: AppColors.urgent, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: start == end ? null : () => Navigator.of(dialog).pop((start, end)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) await _update(start: chosen.$1, end: chosen.$2);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'REMINDERS',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted, letterSpacing: 1.2),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              if (_error != null)
                ErrorBanner(message: _error!, onRetry: _load)
              else if (settings == null)
                const ListTile(
                  leading: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Loading your reminder settings…'),
                )
              else ...[
                ListTile(
                  key: const ValueKey('timezone-tile'),
                  leading: const Icon(Icons.public, color: AppColors.textSecondary, size: 22),
                  title: Text('Time zone', style: AppTextStyles.bodyLarge),
                  subtitle: Text(
                    '${settings.timezone}. Tap to use this phone\'s time zone.',
                    style: AppTextStyles.caption,
                  ),
                  onTap: _busy ? null : _useDeviceTimezone,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const ValueKey('quiet-switch'),
                  secondary: const Icon(Icons.bedtime_outlined, color: AppColors.textSecondary, size: 22),
                  title: Text('Quiet hours', style: AppTextStyles.bodyLarge),
                  subtitle: Text(
                    settings.quietHoursEnabled
                        ? 'Held back from ${settings.quietHoursLabel}'
                        : 'Off: reminders can ring at any hour',
                    style: AppTextStyles.caption,
                  ),
                  value: settings.quietHoursEnabled,
                  onChanged: _busy ? null : (on) => _update(enabled: on),
                ),
                if (settings.quietHoursEnabled)
                  ListTile(
                    key: const ValueKey('quiet-window-tile'),
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: const Text('Change the hours'),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                    onTap: _busy ? null : () => _editWindow(settings),
                  ),
              ],
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('history-tile'),
                leading: const Icon(Icons.history, color: AppColors.textSecondary, size: 22),
                title: Text('Notification history', style: AppTextStyles.bodyLarge),
                subtitle: const Text('Every time a reminder was sent from the cloud', style: AppTextStyles.caption),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                onTap: () => context.push(AppRoutes.notificationHistory),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _HourPicker({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: value,
            items: [
              for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(AccountSettings.hourLabel(h))),
            ],
            onChanged: (h) {
              if (h != null) onChanged(h);
            },
          ),
        ),
      ],
    );
  }
}
