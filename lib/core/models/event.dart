enum EventType {
  hackathon,
  conference,
  workshop,
  webinar,
  meetup,
  meeting,
  appointment,
  application,
  deadline,
  subscription,
  custom,
}

enum EventStatus {
  draft,
  registered,
  upcoming,
  active,
  attended,
  missed,
  completed,
  cancelled,
}

/// Where the user stands on registering for an event (spec 4.4).
enum RegistrationStatus {
  notStarted,
  planned,
  inProgress,
  registered,
  waitlisted,
  failed,
  notEligible,
  skipped,
  expired;

  /// The wire value the backend uses, e.g. `in_progress`.
  String get apiValue => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  String get label => switch (this) {
        notStarted => 'Not started',
        planned => 'Planned',
        inProgress => 'In progress',
        registered => 'Registered',
        waitlisted => 'Waitlisted',
        failed => 'Failed',
        notEligible => 'Not eligible',
        skipped => 'Skipped',
        expired => 'Expired',
      };

  /// Reaching one of these stops the registration reminders (and only those).
  bool get stopsReminders =>
      this == registered || this == skipped || this == notEligible || this == expired;
}

class Event {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final EventType eventType;
  final DateTime startAt;
  final DateTime? endAt;
  final String timezone;
  final String? location;
  final bool isVirtual;
  final String? eventUrl;
  final String? organizer;
  final String? registrationUrl;
  final RegistrationStatus registrationStatus;
  final EventStatus status;
  final List<EventDeadline> deadlines;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Memory
  final String? summaryId;
  final int? photoCount;
  final int? voiceNoteCount;
  final int? documentCount;

  const Event({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.eventType,
    required this.startAt,
    this.endAt,
    this.timezone = 'UTC',
    this.location,
    this.isVirtual = false,
    this.eventUrl,
    this.organizer,
    this.registrationUrl,
    this.registrationStatus = RegistrationStatus.notStarted,
    this.status = EventStatus.upcoming,
    this.deadlines = const [],
    required this.createdAt,
    required this.updatedAt,
    this.summaryId,
    this.photoCount,
    this.voiceNoteCount,
    this.documentCount,
  });

  Event copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? startAt,
    DateTime? endAt,
    String? timezone,
    String? location,
    bool? isVirtual,
    String? eventUrl,
    String? organizer,
    String? registrationUrl,
    RegistrationStatus? registrationStatus,
    EventStatus? status,
    List<EventDeadline>? deadlines,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? summaryId,
    int? photoCount,
    int? voiceNoteCount,
    int? documentCount,
  }) {
    return Event(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      timezone: timezone ?? this.timezone,
      location: location ?? this.location,
      isVirtual: isVirtual ?? this.isVirtual,
      eventUrl: eventUrl ?? this.eventUrl,
      organizer: organizer ?? this.organizer,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      status: status ?? this.status,
      deadlines: deadlines ?? this.deadlines,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      summaryId: summaryId ?? this.summaryId,
      photoCount: photoCount ?? this.photoCount,
      voiceNoteCount: voiceNoteCount ?? this.voiceNoteCount,
      documentCount: documentCount ?? this.documentCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'eventType': eventType.name,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'timezone': timezone,
        'location': location,
        'isVirtual': isVirtual,
        'eventUrl': eventUrl,
        'organizer': organizer,
        'registrationUrl': registrationUrl,
        'registrationStatus': registrationStatus.name,
        'status': status.name,
        'deadlines': deadlines.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'summaryId': summaryId,
        'photoCount': photoCount,
        'voiceNoteCount': voiceNoteCount,
        'documentCount': documentCount,
      };

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'],
        userId: json['userId'],
        title: json['title'],
        description: json['description'],
        eventType: EventType.values.byName(json['eventType'] ?? 'custom'),
        startAt: DateTime.parse(json['startAt']),
        endAt: json['endAt'] != null ? DateTime.parse(json['endAt']) : null,
        timezone: json['timezone'] ?? 'UTC',
        location: json['location'],
        isVirtual: json['isVirtual'] ?? false,
        eventUrl: json['eventUrl'],
        organizer: json['organizer'],
        registrationUrl: json['registrationUrl'],
        registrationStatus: RegistrationStatus.values
            .byName(json['registrationStatus'] ?? 'notStarted'),
        status: EventStatus.values.byName(json['status'] ?? 'upcoming'),
        deadlines: (json['deadlines'] as List<dynamic>? ?? [])
            .map((d) => EventDeadline.fromJson(d))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        summaryId: json['summaryId'],
        photoCount: json['photoCount'],
        voiceNoteCount: json['voiceNoteCount'],
        documentCount: json['documentCount'],
      );
}

enum DeadlineType {
  registration,
  submission,
  payment,
  application,
  attendance,
  custom,
}

class EventDeadline {
  final String id;
  final String eventId;
  final String userId;
  final String title;
  final DeadlineType deadlineType;
  final DateTime deadlineAt;
  final String? source;
  final String status;
  final DateTime createdAt;

  const EventDeadline({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.title,
    required this.deadlineType,
    required this.deadlineAt,
    this.source,
    this.status = 'active',
    required this.createdAt,
  });

  EventDeadline withStatus(String newStatus) => EventDeadline(
        id: id,
        eventId: eventId,
        userId: userId,
        title: title,
        deadlineType: deadlineType,
        deadlineAt: deadlineAt,
        source: source,
        status: newStatus,
        createdAt: createdAt,
      );

  /// Done, skipped or expired: nothing left to chase.
  bool get isClosed => status != 'active';

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'userId': userId,
        'title': title,
        'deadlineType': deadlineType.name,
        'deadlineAt': deadlineAt.toIso8601String(),
        'source': source,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EventDeadline.fromJson(Map<String, dynamic> json) => EventDeadline(
        id: json['id'],
        eventId: json['eventId'],
        userId: json['userId'],
        title: json['title'],
        deadlineType: DeadlineType.values.byName(json['deadlineType']),
        deadlineAt: DateTime.parse(json['deadlineAt']),
        source: json['source'],
        status: json['status'] ?? 'active',
        createdAt: DateTime.parse(json['createdAt']),
      );
}
