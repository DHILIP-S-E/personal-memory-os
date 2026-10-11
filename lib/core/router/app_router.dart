import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_memory_os/features/auth/auth_screen.dart';
import 'package:personal_memory_os/features/today/today_screen.dart';
import 'package:personal_memory_os/features/reminders/screens/reminders_screen.dart';
import 'package:personal_memory_os/features/reminders/screens/reminder_create_screen.dart';
import 'package:personal_memory_os/features/capture/screens/capture_screen.dart';
import 'package:personal_memory_os/features/memory/screens/memory_screen.dart';
import 'package:personal_memory_os/features/memory/screens/memory_search_screen.dart';
import 'package:personal_memory_os/features/memory/screens/ai_chat_screen.dart';
import 'package:personal_memory_os/features/events/screens/event_create_screen.dart';
import 'package:personal_memory_os/features/events/screens/event_detail_screen.dart';
import 'package:personal_memory_os/features/settings/notification_history_screen.dart';
import 'package:personal_memory_os/features/settings/settings_screen.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/shell.dart';

class AppRoutes {
  static const splash = '/splash';
  static const auth = '/auth';
  static const shell = '/';
  static const today = '/today';
  static const reminders = '/reminders';
  static const reminderCreate = '/reminders/create';
  static const capture = '/capture';
  static const memory = '/memory';
  static const memorySearch = '/memory/search';
  static const aiChat = '/memory/ai-chat';
  static const eventCreate = '/events/create';
  static const eventDetail = '/events/:id';
  static const settings = '/settings';
  static const notificationHistory = '/settings/notifications';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Where an unauthenticated / authenticated user must be. Null = stay put.
/// Pure so it can be unit-tested without a widget tree.
String? authRedirect(AuthStatus status, String location) {
  final onAuth = location == AppRoutes.auth;
  final onSplash = location == AppRoutes.splash;
  switch (status) {
    case AuthStatus.unknown:
      // Still restoring the session: show a loading screen. Never the real
      // screens (they would look signed-in with no data) and not the login either.
      return onSplash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return onAuth ? null : AppRoutes.auth;
    case AuthStatus.authenticated:
      return (onAuth || onSplash) ? AppRoutes.today : null;
  }
}

GoRouter createAppRouter(AuthProvider auth) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable: auth,
  redirect: (context, state) => authRedirect(auth.status, state.matchedLocation),
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.today,
          pageBuilder: (context, state) => const NoTransitionPage(child: TodayScreen()),
        ),
        GoRoute(
          path: AppRoutes.reminders,
          pageBuilder: (context, state) => const NoTransitionPage(child: RemindersScreen()),
        ),
        GoRoute(
          path: AppRoutes.capture,
          pageBuilder: (context, state) => const NoTransitionPage(child: CaptureScreen()),
        ),
        GoRoute(
          path: AppRoutes.memory,
          pageBuilder: (context, state) => const NoTransitionPage(child: MemoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
    // Full-screen routes (above the shell)
    GoRoute(
      path: AppRoutes.reminderCreate,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReminderCreateScreen(),
    ),
    GoRoute(
      path: AppRoutes.notificationHistory,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.memorySearch,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MemorySearchScreen(),
    ),
    GoRoute(
      path: AppRoutes.aiChat,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AiChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.eventCreate,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          EventCreateScreen(initialText: state.extra is String ? state.extra as String : null),
    ),
    GoRoute(
      path: '/events/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => EventDetailScreen(
        eventId: state.pathParameters['id']!,
      ),
    ),
  ],
);
