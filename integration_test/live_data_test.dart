// Runs the REAL app on a device against the LIVE backend and proves the screens show the
// user's own data, not placeholders:
//   flutter test integration_test/live_data_test.dart -d <device-id>
// Creates a throwaway account with a reminder, an event and a note through the API, signs in
// through the real login screen, checks what the app displays, then deletes the account.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:personal_memory_os/core/config.dart';
import 'package:personal_memory_os/core/services/app_auth_service.dart';
import 'package:personal_memory_os/main.dart' as app;

const _json = {'Content-Type': 'application/json'};

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
  final r = await http.post(Uri.parse('${AppConfig.backendUrl}$path'),
      headers: {..._json, if (token != null) 'Authorization': 'Bearer $token'}, body: jsonEncode(body));
  expect(r.statusCode, inInclusiveRange(200, 201), reason: '$path -> ${r.statusCode} ${r.body}');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<void> _waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 2 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every screen shows this account\'s real data from the backend', (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'live-$stamp@example.com';
    const password = 'correct horse battery';
    final reminderTitle = 'Live reminder $stamp';
    final eventTitle = 'Live event $stamp';
    final noteText = 'Live note $stamp: call the vendor and send the invoice by 15 October';

    // --- seed the account through the API ---
    final auth = await _post('/auth/register', {'email': email, 'password': password});
    final token = auth['access_token'] as String;
    final soon = DateTime.now().add(const Duration(minutes: 5));
    await _post('/reminders', {
      'title': reminderTitle,
      'scheduled_at': soon.toUtc().toIso8601String(),
      'timezone': 'UTC',
    }, token: token);
    await _post('/events', {
      'title': eventTitle,
      'start_at': soon.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    }, token: token);
    await _post('/captures/note', {'content': noteText}, token: token);

    // --- sign in through the real login screen ---
    await AppAuthService().signOut();
    app.main();
    await _waitFor(tester, find.text('Welcome back'));
    expect(find.text('Welcome back'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _waitFor(tester, find.text("TODAY'S BRIEF"));
    expect(find.text("TODAY'S BRIEF"), findsOneWidget, reason: 'signed in and on Today');

    // --- Today: the real reminder and counts, none of the old placeholders ---
    await _waitFor(tester, find.text(reminderTitle, skipOffstage: false));
    expect(find.text(reminderTitle, skipOffstage: false), findsWidgets,
        reason: 'Today shows the reminder created on the backend');
    expect(find.text('1  To Do'), findsOneWidget, reason: 'real count');
    expect(find.textContaining(email.split('@').first), findsWidgets, reason: 'real name');
    for (final fake in ['Olivia Reed', 'Design Landing page', '72%', 'Meeting with Client']) {
      expect(find.textContaining(fake, skipOffstage: false), findsNothing, reason: 'no placeholder "$fake"');
    }

    // --- Tasks tab ---
    await tester.tap(find.byIcon(Icons.task_alt_rounded));
    await _waitFor(tester, find.text(reminderTitle));
    expect(find.text(reminderTitle), findsWidgets, reason: 'Tasks lists the real reminder');

    // --- Schedule tab ---
    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await _waitFor(tester, find.text(eventTitle, skipOffstage: false));
    expect(find.text(eventTitle, skipOffstage: false), findsWidgets, reason: 'Schedule lists the real event');

    // --- Notes tab: the note is there, and its AI summary arrives from the cloud worker ---
    await tester.tap(find.byIcon(Icons.sticky_note_2_rounded));
    await _waitFor(tester, find.textContaining('Live note $stamp', skipOffstage: false));
    expect(find.textContaining('Live note $stamp', skipOffstage: false), findsWidgets,
        reason: 'Notes shows the real note');

    // --- the backend agrees the note was analysed ---
    final captures = await http.get(Uri.parse('${AppConfig.backendUrl}/captures'),
        headers: {'Authorization': 'Bearer $token'});
    expect(captures.statusCode, 200);
    expect(captures.body, contains('Live note $stamp'));

    // --- clean up ---
    final del = await http.delete(Uri.parse('${AppConfig.backendUrl}/account'),
        headers: {'Authorization': 'Bearer $token'});
    expect(del.statusCode, 200);
  });
}
