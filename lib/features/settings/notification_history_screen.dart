import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/models/notification_delivery.dart';
import 'package:personal_memory_os/core/services/account_service.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';
import 'package:personal_memory_os/shared/widgets/empty_state.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';

/// Every time the cloud tried to deliver a reminder, newest first (spec 4.6).
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  static const _pageSize = 50;

  final List<NotificationDelivery> _items = [];
  bool _loading = true;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items.clear();
    });
    try {
      final page = await context.read<AccountService>().notificationHistory(limit: _pageSize, offset: _items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Notification history'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
      if (_error != null) {
        return Center(child: ErrorBanner(message: _error!, onRetry: () => _load(reset: true)));
      }
      return const EmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications yet',
        subtitle: 'When a reminder fires from the cloud, it is listed here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (_error != null) ErrorBanner(message: _error!, onRetry: () => _load()),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Sent means the notification service accepted it. It does not prove it was shown on your phone.',
              style: AppTextStyles.caption,
            ),
          ),
          for (final item in _items) _DeliveryTile(item),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: _loading ? null : () => _load(),
                child: Text(_loading ? 'Loading…' : 'Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final NotificationDelivery item;

  const _DeliveryTile(this.item);

  Color get _color => switch (item.status) {
        'failed' => AppColors.urgent,
        'sent' || 'delivered' => AppColors.success,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final when = item.fireAt ?? item.createdAt;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.reminderTitle ?? 'Reminder', style: AppTextStyles.titleMedium),
              ),
              Text(
                item.statusLabel,
                key: ValueKey('status-${item.id}'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _color),
              ),
            ],
          ),
          if (when != null) Text(AppDateUtils.formatDateTime(when), style: AppTextStyles.caption),
          if (item.explanation != null) ...[
            const SizedBox(height: 4),
            Text(item.explanation!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
