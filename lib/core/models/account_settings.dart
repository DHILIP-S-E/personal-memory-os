/// The user's timezone and quiet hours, as the server holds them. The cloud alarm reads these
/// at the moment a reminder fires, so a change here applies to reminders already scheduled.
class AccountSettings {
  final String timezone;
  final bool quietHoursEnabled;

  /// Hours of the day, 0 to 23, in [timezone]. The window may wrap past midnight (22 to 7).
  final int quietHoursStart;
  final int quietHoursEnd;

  const AccountSettings({
    this.timezone = 'UTC',
    this.quietHoursEnabled = true,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
  });

  factory AccountSettings.fromJson(Map<String, dynamic> json) => AccountSettings(
        timezone: json['timezone'] as String? ?? 'UTC',
        quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? true,
        quietHoursStart: (json['quiet_hours_start'] as num?)?.toInt() ?? 22,
        quietHoursEnd: (json['quiet_hours_end'] as num?)?.toInt() ?? 7,
      );

  AccountSettings copyWith({
    String? timezone,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) =>
      AccountSettings(
        timezone: timezone ?? this.timezone,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietHoursStart: quietHoursStart ?? this.quietHoursStart,
        quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      );

  /// 0 -> "12 AM", 13 -> "1 PM".
  static String hourLabel(int hour) => '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}';

  String get quietHoursLabel =>
      quietHoursEnabled ? '${hourLabel(quietHoursStart)} to ${hourLabel(quietHoursEnd)}' : 'Off';

  @override
  bool operator ==(Object other) =>
      other is AccountSettings &&
      other.timezone == timezone &&
      other.quietHoursEnabled == quietHoursEnabled &&
      other.quietHoursStart == quietHoursStart &&
      other.quietHoursEnd == quietHoursEnd;

  @override
  int get hashCode => Object.hash(timezone, quietHoursEnabled, quietHoursStart, quietHoursEnd);
}
