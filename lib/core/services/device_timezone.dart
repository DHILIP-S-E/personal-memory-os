import 'package:flutter_timezone/flutter_timezone.dart';

/// The phone's own IANA timezone, such as "Asia/Kolkata", or null if it cannot be read.
Future<String?> deviceTimezone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
}
