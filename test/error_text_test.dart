import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/utils/error_text.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';

void main() {
  group('friendlyError', () {
    test('network failures say the server cannot be reached', () {
      for (final raw in [
        'ClientException with SocketException: Connection timed out (OS Error: Connection timed out, errno = 110)',
        'TimeoutException after 0:00:20.000000: Future not completed',
        'SocketException: Failed host lookup',
      ]) {
        expect(friendlyError(raw), contains("Can't reach the server"));
      }
    });

    test('API errors map to something actionable, never the raw class name', () {
      expect(friendlyError('ApiException(401): Not authenticated'), contains('sign in again'));
      expect(friendlyError('ApiException(500): boom'), contains('server had a problem'));
      expect(friendlyError('ApiException(422): Enter a valid email address'), 'Enter a valid email address');
      expect(friendlyError('ApiException(422): {"detail":[...]}'), isNot(contains('ApiException')));
    });

    test('an already readable message is kept, an unknown exception is not leaked', () {
      expect(friendlyError('Invalid email or password'), 'Invalid email or password');
      expect(friendlyError("type 'Null' is not a subtype of type 'String' Exception"), 'Something went wrong. Please try again.');
      expect(friendlyError(''), 'Something went wrong. Please try again.');
    });
  });

  testWidgets('ErrorBanner shows the friendly text and Retry works', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ErrorBanner(message: 'SocketException: x', onRetry: () => retried++)),
    ));
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });
}
