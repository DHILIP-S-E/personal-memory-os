import 'package:flutter/foundation.dart';
import 'package:personal_memory_os/core/models/account_settings.dart';
import 'package:personal_memory_os/core/services/account_service.dart';
import 'package:personal_memory_os/core/services/device_timezone.dart';

typedef TimezoneSource = Future<String?> Function();

// A region/city name like Asia/Kolkata or America/Argentina/Buenos_Aires; not "GMT+5" or "Unknown".
final _ianaName = RegExp(r'^[A-Za-z]+(?:/[A-Za-z0-9_+\-]+)+$');

/// Makes the server's timezone match the phone's, so quiet hours and recurring reminders
/// follow the clock the user actually lives by. Returns the new settings if it changed
/// them, otherwise null. It never throws: a failed sync must not get in the way of signing in.
Future<AccountSettings?> syncDeviceTimezone(
  AccountService account, {
  TimezoneSource source = deviceTimezone,
}) async {
  try {
    final device = (await source())?.trim();
    if (device == null || !_ianaName.hasMatch(device)) return null;
    final saved = await account.getSettings();
    if (saved.timezone == device) return null;
    return await account.updateSettings(timezone: device);
  } catch (e) {
    debugPrint('Timezone sync skipped: $e');
    return null;
  }
}
