// lib/features/agenda/data/models/hearing_model.dart

/// Modello per la tabella hearings
class Hearing {
  final String hearingId;
  final String firmId;
  final String matterId;
  final String title;
  final String? description;
  final String? court;
  final String? judge;
  final String? courtroom;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? notes;
  final String? outcome;
  final String status; // enum record_status: active, deleted
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Hearing({
    required this.hearingId,
    required this.firmId,
    required this.matterId,
    required this.title,
    this.description,
    this.court,
    this.judge,
    this.courtroom,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.notes,
    this.outcome,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  // Nomi colonna: aderenti allo schema Supabase
  static const colId = 'hearing_id';
  static const colFirmId = 'firm_id';
  static const colMatterId = 'matter_id';
  static const colTitle = 'title';
  static const colDescription = 'description';
  static const colCourt = 'court';
  static const colJudge = 'judge';
  static const colCourtroom = 'courtroom';
  static const colScheduledAt = 'scheduled_at';
  static const colDurationMinutes = 'duration_minutes';
  static const colNotes = 'notes';
  static const colOutcome = 'outcome';
  static const colStatus = 'status';
  static const colCreatedAt = 'created_at';
  static const colUpdatedAt = 'updated_at';

  factory Hearing.fromJson(Map<String, dynamic> json) => Hearing(
        hearingId: json[colId] as String,
        firmId: json[colFirmId] as String,
        matterId: json[colMatterId] as String,
        title: json[colTitle] as String,
        description: json[colDescription] as String?,
        court: json[colCourt] as String?,
        judge: json[colJudge] as String?,
        courtroom: json[colCourtroom] as String?,
        scheduledAt: DateTime.parse(json[colScheduledAt] as String),
        durationMinutes: json[colDurationMinutes] as int? ?? 60,
        notes: json[colNotes] as String?,
        outcome: json[colOutcome] as String?,
        status: json[colStatus] as String? ?? 'active',
        createdAt: json[colCreatedAt] != null
            ? DateTime.parse(json[colCreatedAt] as String)
            : null,
        updatedAt: json[colUpdatedAt] != null
            ? DateTime.parse(json[colUpdatedAt] as String)
            : null,
      );

  /// Per insert: non includo hearing_id/created_at/updated_at (gestiti dal DB)
  Map<String, dynamic> toInsertJson() => {
        colFirmId: firmId,
        colMatterId: matterId,
        colTitle: title,
        if (description != null) colDescription: description,
        if (court != null) colCourt: court,
        if (judge != null) colJudge: judge,
        if (courtroom != null) colCourtroom: courtroom,
        colScheduledAt: scheduledAt.toIso8601String(),
        colDurationMinutes: durationMinutes,
        if (notes != null) colNotes: notes,
        if (outcome != null) colOutcome: outcome,
        colStatus: status,
      };

  /// Per update: includo solo i campi modificabili
  Map<String, dynamic> toUpdateJson() => {
        colTitle: title,
        if (description != null) colDescription: description,
        if (court != null) colCourt: court,
        if (judge != null) colJudge: judge,
        if (courtroom != null) colCourtroom: courtroom,
        colScheduledAt: scheduledAt.toIso8601String(),
        colDurationMinutes: durationMinutes,
        if (notes != null) colNotes: notes,
        if (outcome != null) colOutcome: outcome,
        colStatus: status,
      };

  Hearing copyWith({
    String? hearingId,
    String? firmId,
    String? matterId,
    String? title,
    String? description,
    String? court,
    String? judge,
    String? courtroom,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? notes,
    String? outcome,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Hearing(
        hearingId: hearingId ?? this.hearingId,
        firmId: firmId ?? this.firmId,
        matterId: matterId ?? this.matterId,
        title: title ?? this.title,
        description: description ?? this.description,
        court: court ?? this.court,
        judge: judge ?? this.judge,
        courtroom: courtroom ?? this.courtroom,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        notes: notes ?? this.notes,
        outcome: outcome ?? this.outcome,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // Getters utili
  bool get isActive => status == 'active';
  bool get isPast => scheduledAt.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hearingDate = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    return hearingDate.isAtSameMomentAs(today);
  }
  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
  DateTime get endTime => scheduledAt.add(Duration(minutes: durationMinutes));
  String get displayCourt => court ?? 'Tribunale non specificato';
  String get displayCourtroom => courtroom ?? 'Aula non specificata';
  bool get hasOutcome => outcome != null && outcome!.isNotEmpty;
  
  @override
  String toString() => 'Hearing(id: $hearingId, title: $title, scheduledAt: $scheduledAt, court: $court)';
}