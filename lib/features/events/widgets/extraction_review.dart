import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/services/ai_service.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';

/// One line of the review: what the AI found for a field, and what to tell the user about it.
class ReviewRow {
  final String field;
  final String label;
  final String? value;

  /// The words on the page this value came from.
  final String? evidence;

  /// The time of day was not stated on the page, so a default was used.
  final bool assumedTime;

  const ReviewRow({
    required this.field,
    required this.label,
    this.value,
    this.evidence,
    this.assumedTime = false,
  });

  bool get missing => value == null;
}

/// What to show for each extracted field. A field the page did not state is "missing";
/// nothing is guessed to fill it. [startAt] is what the user will save with, which may be
/// a date they picked themselves.
List<ReviewRow> buildReviewRows(EventExtractionResult r, {DateTime? startAt}) {
  String? date(DateTime? d) => d == null ? null : AppDateUtils.formatDateTime(d);
  ReviewRow row(String field, String label, String? value) => ReviewRow(
        field: field,
        label: label,
        value: value,
        evidence: value == null ? null : r.evidence[field],
        assumedTime: value != null && r.assumedTimes.contains(field),
      );

  return [
    row('title', 'Title', r.title),
    row('start_at', 'Starts', date(startAt ?? r.startAt)),
    row('end_at', 'Ends', date(r.endAt)),
    row('registration_deadline', 'Registration deadline', date(r.registrationDeadline)),
    row('submission_deadline', 'Submission deadline', date(r.submissionDeadline)),
    row('registration_url', 'Registration link', r.registrationUrl),
    row('location', 'Location', r.location),
  ];
}

/// The AI's proposal, shown for checking before anything is saved (spec 8: AI proposes,
/// the user confirms). The event can only be created once it has a start date, and that
/// date is never filled in on the user's behalf.
class ExtractionReview extends StatelessWidget {
  final EventExtractionResult result;

  /// A start date the user chose because the page did not give one.
  final DateTime? pickedStart;
  final VoidCallback onPickStart;
  final VoidCallback onCreate;
  final VoidCallback onEdit;

  const ExtractionReview({
    super.key,
    required this.result,
    required this.pickedStart,
    required this.onPickStart,
    required this.onCreate,
    required this.onEdit,
  });

  bool get _hasStart => (pickedStart ?? result.startAt) != null;

  @override
  Widget build(BuildContext context) {
    final rows = buildReviewRows(result, startAt: pickedStart);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review what was found', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Check each line against the page. Anything the page did not say is left empty, not guessed.',
            style: AppTextStyles.caption,
          ),
          if (result.ambiguousDates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'These dates could be read two ways, so please check them: ${result.ambiguousDates.join(', ')}',
              key: const ValueKey('ambiguous-dates'),
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 12),
          for (final row in rows) _RowView(row),
          const SizedBox(height: 12),
          if (!_hasStart)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "The page doesn't say when the event starts. Choose the start date to continue.",
                key: ValueKey('needs-start'),
                style: TextStyle(fontSize: 12, color: AppColors.urgent),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('create-or-pick'),
                  onPressed: _hasStart ? onCreate : onPickStart,
                  child: Text(_hasStart ? 'Create event' : 'Choose start date'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: onEdit, child: const Text('Edit manually')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  final ReviewRow row;

  const _RowView(this.row);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: AppTextStyles.caption),
          Text(
            row.value ?? 'Not found on the page',
            key: ValueKey('value-${row.field}'),
            style: row.missing
                ? AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)
                : AppTextStyles.bodyLarge,
          ),
          if (row.assumedTime)
            Text(
              'The time was not stated, please check it.',
              key: ValueKey('assumed-${row.field}'),
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          if (row.evidence != null)
            Text(
              'From the page: "${row.evidence}"',
              key: ValueKey('evidence-${row.field}'),
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}
