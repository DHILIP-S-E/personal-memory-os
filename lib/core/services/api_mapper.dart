import 'package:personal_memory_os/core/models/ai_message.dart';
import 'package:personal_memory_os/core/models/capture.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/memory_document.dart';
import 'package:personal_memory_os/core/models/reminder.dart';

/// Adapts FastAPI JSON (snake_case keys, snake_case enum values, string
/// offsets) to the camelCase shapes the Dart models parse. All API services go
/// through here so the wire contract lives in one place.

String camelize(String s) {
  final parts = s.split('_');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();
}

/// Recursively converts map keys from snake_case to camelCase.
dynamic camelizeKeys(dynamic value) {
  if (value is Map) {
    return value.map<String, dynamic>((k, v) => MapEntry(camelize(k as String), camelizeKeys(v)));
  }
  if (value is List) return value.map(camelizeKeys).toList();
  return value;
}

Map<String, dynamic> _obj(dynamic raw) =>
    Map<String, dynamic>.from(camelizeKeys(raw) as Map);

/// 'follow_up' → 'followUp'. Null stays null.
String? _enumValue(dynamic v) => v is String ? camelize(v) : null;

/// The camel-cased value if it names one of [values], else [fallback]. The server stores some
/// of these as free text, and one unknown value must never stop a whole list from loading.
String _oneOf(dynamic v, Iterable<Enum> values, String fallback) {
  final name = _enumValue(v);
  return name != null && values.any((e) => e.name == name) ? name : fallback;
}

List<Map<String, dynamic>> _titledItems(dynamic list) =>
    (list as List<dynamic>? ?? []).map((e) {
      if (e is String) return <String, dynamic>{'title': e};
      return Map<String, dynamic>.from(e as Map);
    }).toList();

Reminder reminderFromApi(dynamic raw) {
  final j = _obj(raw);
  j['reminderType'] = _oneOf(j['reminderType'], ReminderType.values, 'time');
  j['priority'] = _oneOf(j['priority'], ReminderPriority.values, 'medium');
  j['status'] = _oneOf(j['status'], ReminderStatus.values, 'active');
  // Backend stores the event-policy source as 'event'.
  final source = _enumValue(j['source']) ?? 'manual';
  j['source'] = source == 'event' ? 'eventPolicy' : _oneOf(source, ReminderSource.values, 'manual');
  j['offsets'] = (j['offsets'] as List<dynamic>? ?? [])
      .map((o) => o is String ? {'offset': o, 'sent': false} : o)
      .toList();
  j['syncStatus'] = 'SYNCED';
  j['serverId'] = j['id'];
  return Reminder.fromJson(j);
}

Capture captureFromApi(dynamic raw) {
  final j = _obj(raw);
  j['type'] = _enumValue(j['captureType']) ?? 'note';
  j['processingStatus'] = _enumValue(j['processingStatus']) ?? 'uploaded';
  final ai = j['aiResult'];
  if (ai is Map) {
    j['aiResult'] = <String, dynamic>{
      ...Map<String, dynamic>.from(ai),
      'actions': _titledItems(ai['actions']),
    };
  }
  return Capture.fromJson(j);
}

Event eventFromApi(dynamic raw) {
  final j = _obj(raw);
  j['eventType'] = _oneOf(j['eventType'], EventType.values, 'custom');
  j['status'] = _oneOf(j['status'], EventStatus.values, 'upcoming');
  j['registrationStatus'] = _oneOf(j['registrationStatus'], RegistrationStatus.values, 'notStarted');
  j['deadlines'] = (j['deadlines'] as List<dynamic>? ?? []).map((d) {
    final m = Map<String, dynamic>.from(d as Map);
    m['deadlineType'] = _oneOf(m['deadlineType'], DeadlineType.values, 'custom');
    return m;
  }).toList();
  return Event.fromJson(j);
}

MemoryDocument memoryFromApi(dynamic raw) {
  final j = _obj(raw);
  j['actionItems'] = _titledItems(j['actionItems']);
  j['deadlines'] = (j['deadlines'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .map((d) => Map<String, dynamic>.from(d))
      .toList();
  return MemoryDocument.fromJson(j);
}

AiMessageSource aiSourceFromApi(dynamic raw) =>
    AiMessageSource.fromJson(_obj(raw));
