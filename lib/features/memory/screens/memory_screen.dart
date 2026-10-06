import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';
import 'package:personal_memory_os/core/providers/memory_provider.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/shared/widgets/empty_state.dart';
import 'package:personal_memory_os/shared/widgets/section_header.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemoryProvider>().loadMemory();
      context.read<EventProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeader(context),
            _buildEventTimeline(context),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Memory', style: AppTextStyles.displayMedium),
                  SizedBox(height: 2),
                  Text(
                    'Your personal knowledge base',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push(AppRoutes.memorySearch),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTimeline(BuildContext context) {
    return Consumer2<EventProvider, MemoryProvider>(
      builder: (context, eventP, memoryP, _) {
        if (eventP.isLoading || memoryP.isLoading) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          );
        }

        final events = eventP.events
          ..sort((a, b) => b.startAt.compareTo(a.startAt));

        if (eventP.error != null && events.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorBanner(message: eventP.error!, onRetry: eventP.loadEvents),
          );
        }

        if (events.isEmpty) {
          return SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.history_edu_outlined,
              title: 'No memory yet',
              subtitle:
                  'Capture photos, voice notes, and notes from events to build your personal knowledge base',
              actionLabel: '+ Create Event',
              onAction: () => context.push(AppRoutes.eventCreate),
            ),
          );
        }

        // Group by month
        final grouped = <String, List<dynamic>>{};
        for (final e in events) {
          final key =
              '${e.startAt.year}-${e.startAt.month.toString().padLeft(2, '0')}';
          grouped.putIfAbsent(key, () => []).add(e);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final entries = grouped.entries.toList();
              final entry = entries[i];
              final date = DateTime.parse('${entry.key}-01');
              final monthLabel =
                  '${_monthName(date.month)} ${date.year}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: monthLabel),
                  for (final e in entry.value)
                    _EventMemoryCard(
                      event: e,
                      onTap: () => context.push('/events/${e.id}'),
                    ),
                ],
              );
            },
            childCount: grouped.length,
          ),
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }
}

class _EventMemoryCard extends StatelessWidget {
  final dynamic event;
  final VoidCallback onTap;

  const _EventMemoryCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (event.summaryId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 10, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.formatDateFull(event.startAt),
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CountChip(
                  icon: Icons.image_outlined,
                  count: event.photoCount ?? 0,
                  label: 'photos',
                  color: AppColors.capturePhoto,
                ),
                const SizedBox(width: 8),
                _CountChip(
                  icon: Icons.mic_outlined,
                  count: event.voiceNoteCount ?? 0,
                  label: 'voice',
                  color: AppColors.captureVoice,
                ),
                const SizedBox(width: 8),
                _CountChip(
                  icon: Icons.description_outlined,
                  count: event.documentCount ?? 0,
                  label: 'docs',
                  color: AppColors.captureDoc,
                ),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
