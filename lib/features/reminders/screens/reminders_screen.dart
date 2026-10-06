import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/shared/widgets/reminder_card.dart';
import 'package:personal_memory_os/shared/widgets/empty_state.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ReminderProvider>().loadReminders(),
    );
  }

  static const _filters = [
    (ReminderFilter.today, 'Today'),
    (ReminderFilter.upcoming, 'Upcoming'),
    (ReminderFilter.recurring, 'Recurring'),
    (ReminderFilter.deadlines, 'Deadlines'),
    (ReminderFilter.overdue, 'Overdue'),
    (ReminderFilter.completed, 'Completed'),
    (ReminderFilter.all, 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildFilterBar(context),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.reminderCreate),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Reminder',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Reminders', style: AppTextStyles.displayMedium),
          ),
          Consumer<ReminderProvider>(
            builder: (context, provider, _) {
              final overdue = provider.overdueReminders.length;
              if (overdue == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.urgent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.urgent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$overdue overdue',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.urgent,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (filter, label) = _filters[i];
              final selected = provider.activeFilter == filter;
              return GestureDetector(
                onTap: () => provider.setFilter(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.cardBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final reminders = provider.filteredReminders;

        if (provider.error != null && reminders.isEmpty) {
          return Center(
            child: ErrorBanner(message: provider.error!, onRetry: provider.loadReminders),
          );
        }

        if (reminders.isEmpty) {
          return EmptyState(
            icon: Icons.notifications_none,
            title: 'No reminders here',
            subtitle: 'Create a reminder to get started',
            actionLabel: '+ New Reminder',
            onAction: () => context.push(AppRoutes.reminderCreate),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadReminders,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 100),
            itemCount: reminders.length,
            itemBuilder: (context, i) {
              final r = reminders[i];
              return Dismissible(
                key: Key(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.urgent, size: 24),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Delete reminder?',
                          style: AppTextStyles.titleMedium),
                      content: Text(
                        r.title,
                        style: AppTextStyles.bodyMedium,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.urgent),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) =>
                    context.read<ReminderProvider>().deleteReminder(r.id),
                child: ReminderCard(
                  reminder: r,
                  onComplete: () =>
                      context.read<ReminderProvider>().completeReminder(r.id),
                  onSnooze: () =>
                      context.read<ReminderProvider>().snoozeReminder(
                            r.id,
                            const Duration(minutes: 30),
                          ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
