/// Turns whatever a provider stored (`e.toString()`) into a sentence a person can act on.
String friendlyError(String raw) {
  final r = raw.trim();
  if (RegExp(r'SocketException|ClientException|TimeoutException|Failed host lookup|Connection (timed out|refused|reset)|Network is unreachable',
          caseSensitive: false)
      .hasMatch(r)) {
    return "Can't reach the server. Check your internet connection and try again.";
  }
  final api = RegExp(r'^ApiException\((\d+)\): ?(.*)$', dotAll: true).firstMatch(r);
  if (api != null) {
    final code = int.parse(api.group(1)!);
    final detail = (api.group(2) ?? '').trim();
    if (code == 401 || code == 403) return 'Your session has expired. Please sign in again.';
    if (code >= 500) return 'The server had a problem. Please try again in a moment.';
    if (detail.isNotEmpty && detail.length < 140 && !detail.startsWith('{')) return detail;
    return 'The request was not accepted. Please check what you entered.';
  }
  // Already a readable message (for example from AuthException).
  if (r.isNotEmpty && r.length < 140 && !r.contains('Exception') && !r.contains('Error:')) return r;
  return 'Something went wrong. Please try again.';
}
