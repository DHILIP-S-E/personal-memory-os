import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';

/// Events you still need to register for, soonest deadline first. Shows nothing when there are none.
class PendingRegistrationsCard extends StatelessWidget {
  static const _maxShown = 3;

  const PendingRegistrationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<EventProvider>().pendingRegistrations;
    if (pending.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pending.length == 1 ? 'REGISTRATION TO FINISH' : 'REGISTRATIONS TO FINISH',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (final item in pending.take(_maxShown))
            InkWell(
              key: ValueKey('pending-${item.event.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.push('/events/${item.event.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.how_to_reg_outlined,
                      size: 20,
                      color: item.overdue ? AppColors.urgent : AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.event.title, style: AppTextStyles.titleMedium),
                          Text(
                            item.overdue
                                ? 'The registration deadline has passed'
                                : 'Register by ${AppDateUtils.formatDateTime(item.deadline.deadlineAt)}',
                            key: ValueKey('when-${item.event.id}'),
                            style: AppTextStyles.caption.copyWith(
                              color: item.overdue ? AppColors.urgent : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(item.event.registrationStatus.label, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
          if (pending.length > _maxShown)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('and ${pending.length - _maxShown} more', style: AppTextStyles.caption),
            ),
        ],
      ),
    );
  }
}
