import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/services/ai_service.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/features/events/widgets/extraction_review.dart';
import 'package:personal_memory_os/shared/widgets/error_banner.dart';

class EventCreateScreen extends StatefulWidget {
  /// Text shared into the app (share sheet) or pasted before opening: it is
  /// dropped into the extract tab and parsed straight away.
  final String? initialText;

  const EventCreateScreen({super.key, this.initialText});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual fields
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _urlController = TextEditingController();
  final _organizerController = TextEditingController();
  EventType _eventType = EventType.hackathon;
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _registrationDeadline;
  bool _isVirtual = false;

  // NLP / paste fields
  final _pasteController = TextEditingController();
  bool _isParsing = false;
  EventExtractionResult? _extracted;
  String? _extractError;
  DateTime? _pickedStart; // chosen by the user when the page gave no start date

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final shared = widget.initialText?.trim();
    if (shared != null && shared.isNotEmpty) {
      _tabController.index = 1;
      _pasteController.text = shared;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parseText();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _urlController.dispose();
    _organizerController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  /// Capture-first: copy an event page anywhere, then paste and extract in one tap.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _pasteController.text = text;
    await _parseText();
  }

  Future<void> _parseText() async {
    if (_pasteController.text.trim().isEmpty) return;
    setState(() {
      _isParsing = true;
      _extracted = null;
      _extractError = null;
      _pickedStart = null;
    });
    try {
      final result = await context.read<AiService>().extractEventFromText(_pasteController.text);
      if (mounted) setState(() => _extracted = result);
    } catch (e) {
      // Say what went wrong. A blank placeholder event would look like a result.
      if (mounted) setState(() => _extractError = e.toString());
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  /// The page did not give a start date, so the user chooses it. It is never filled in for them.
  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted) return;
    setState(() => _pickedStart = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _saveManual() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter an event title');
      return;
    }
    if (_startAt == null) {
      _showError('Please set the event date and time');
      return;
    }
    await _createEvent(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      type: _eventType,
      startAt: _startAt!,
      endAt: _endAt,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      eventUrl: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      organizer: _organizerController.text.trim().isEmpty
          ? null
          : _organizerController.text.trim(),
      isVirtual: _isVirtual,
      registrationDeadline: _registrationDeadline,
    );
  }

  Future<void> _saveExtracted() async {
    final extracted = _extracted;
    if (extracted == null) return;
    final start = _pickedStart ?? extracted.startAt;
    if (start == null) {
      await _pickStart();
      return;
    }
    await _createEvent(
      title: extracted.title,
      description: extracted.description,
      type: extracted.eventType,
      startAt: start,
      endAt: extracted.endAt,
      location: extracted.location,
      eventUrl: extracted.eventUrl,
      organizer: extracted.organizer,
      isVirtual: extracted.isVirtual ?? false,
      registrationDeadline: extracted.registrationDeadline,
      submissionDeadline: extracted.submissionDeadline,
      registrationUrl: extracted.registrationUrl,
    );
  }

  Future<void> _createEvent({
    required String title,
    String? description,
    required EventType type,
    required DateTime startAt,
    DateTime? endAt,
    String? location,
    String? eventUrl,
    String? organizer,
    required bool isVirtual,
    DateTime? registrationDeadline,
    DateTime? submissionDeadline,
    String? registrationUrl,
  }) async {
    final userId = context.read<AuthProvider>().user?.id ?? 'local';
    final now = DateTime.now();
    final deadlines = <EventDeadline>[];

    if (registrationDeadline != null) {
      deadlines.add(EventDeadline(
        id: const Uuid().v4(),
        eventId: '',
        userId: userId,
        title: 'Registration deadline',
        deadlineType: DeadlineType.registration,
        deadlineAt: registrationDeadline,
        createdAt: now,
      ));
    }
    if (submissionDeadline != null) {
      deadlines.add(EventDeadline(
        id: const Uuid().v4(),
        eventId: '',
        userId: userId,
        title: 'Submission deadline',
        deadlineType: DeadlineType.submission,
        deadlineAt: submissionDeadline,
        createdAt: now,
      ));
    }

    final event = Event(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      description: description,
      eventType: type,
      startAt: startAt,
      endAt: endAt,
      location: location,
      eventUrl: eventUrl,
      organizer: organizer,
      registrationUrl: registrationUrl,
      isVirtual: isVirtual,
      deadlines: deadlines,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final created = await context.read<EventProvider>().createEvent(event);
      // Open the new event: its reminder plan is offered there.
      if (mounted) context.pushReplacement('/events/${created.id}');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.urgent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Manual'),
            Tab(text: 'Paste / AI Extract'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManualForm(),
          _buildPasteForm(),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Event Title'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(hintText: 'Event name'),
          ),
          const SizedBox(height: 16),
          _label('Event Type'),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 16),
          _label('Start Date & Time'),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            value: _startAt,
            hint: 'Set start date & time',
            onTap: () => _pickDateTime(isStart: true),
            onClear: () => setState(() => _startAt = null),
          ),
          const SizedBox(height: 12),
          _label('End Date & Time (optional)'),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            value: _endAt,
            hint: 'Set end date & time',
            onTap: () => _pickDateTime(isStart: false),
            onClear: () => setState(() => _endAt = null),
          ),
          const SizedBox(height: 12),
          _label('Registration Deadline (optional)'),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            value: _registrationDeadline,
            hint: 'Set registration deadline',
            onTap: _pickRegistrationDeadline,
            onClear: () => setState(() => _registrationDeadline = null),
            icon: Icons.flag_outlined,
            color: AppColors.urgent,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Virtual Event', style: AppTextStyles.titleMedium),
              Switch(
                value: _isVirtual,
                onChanged: (v) => setState(() => _isVirtual = v),
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Location / URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _isVirtual ? _urlController : _locationController,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: _isVirtual ? 'Meeting link' : 'Venue or address',
            ),
          ),
          const SizedBox(height: 12),
          _label('Organizer (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _organizerController,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(hintText: 'Who is organising it?'),
          ),
          const SizedBox(height: 12),
          _label('Description (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            style: AppTextStyles.bodyLarge,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Event details…'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveManual,
              child: const Text('Add Event'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPasteForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paste event text, a URL, or an email. AI will extract the event details.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('Paste event information'),
              TextButton.icon(
                onPressed: _isParsing ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste, size: 16),
                label: const Text('Paste & extract'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            style: AppTextStyles.bodyLarge,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste an invitation, message or announcement here',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isParsing ? null : _parseText,
              icon: _isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : const Icon(Icons.psychology_outlined),
              label: Text(_isParsing ? 'Extracting…' : 'Extract with AI'),
            ),
          ),
          if (_extractError != null)
            ErrorBanner(message: _extractError!, onRetry: _isParsing ? null : _parseText),
          if (_extracted != null) ...[
            const SizedBox(height: 20),
            ExtractionReview(
              result: _extracted!,
              pickedStart: _pickedStart,
              onPickStart: _pickStart,
              onCreate: _saveExtracted,
              onEdit: () {
                // Populate the manual form, then switch to it.
                final extracted = _extracted!;
                _titleController.text = extracted.title;
                final start = _pickedStart ?? extracted.startAt;
                if (start != null) _startAt = start;
                if (extracted.endAt != null) _endAt = extracted.endAt;
                if (extracted.registrationDeadline != null) {
                  _registrationDeadline = extracted.registrationDeadline;
                }
                if (extracted.location != null) {
                  _locationController.text = extracted.location!;
                }
                if (extracted.eventUrl != null) {
                  _urlController.text = extracted.eventUrl!;
                }
                _eventType = extracted.eventType;
                _tabController.animateTo(0);
                setState(() => _extracted = null);
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style:
            AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
      );

  Widget _buildTypeSelector() {
    const types = [
      (EventType.hackathon, 'Hackathon', Icons.code),
      (EventType.workshop, 'Workshop', Icons.build_outlined),
      (EventType.conference, 'Conference', Icons.groups_outlined),
      (EventType.webinar, 'Webinar', Icons.videocam_outlined),
      (EventType.meetup, 'Meetup', Icons.people_outline),
      (EventType.meeting, 'Meeting', Icons.calendar_today_outlined),
      (EventType.deadline, 'Deadline', Icons.flag_outlined),
      (EventType.custom, 'Custom', Icons.star_border),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final (type, label, icon) = t;
        final selected = _eventType == type;
        return GestureDetector(
          onTap: () => setState(() => _eventType = type),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: selected ? Colors.white : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeTile({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
    required VoidCallback onClear,
    IconData icon = Icons.calendar_today_outlined,
    Color color = AppColors.accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null ? hint : '${value.toLocal()}',
                style: value == null
                    ? AppTextStyles.bodyMedium
                    : AppTextStyles.bodyLarge,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear,
                    size: 16, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_startAt ?? DateTime.now().add(const Duration(days: 1)))
        : (_endAt ?? (_startAt ?? DateTime.now()).add(const Duration(hours: 4)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = dt;
      } else {
        _endAt = dt;
      }
    });
  }

  Future<void> _pickRegistrationDeadline() async {
    final initial = _registrationDeadline ??
        (_startAt != null
            ? _startAt!.subtract(const Duration(days: 3))
            : DateTime.now().add(const Duration(days: 7)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _registrationDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}
