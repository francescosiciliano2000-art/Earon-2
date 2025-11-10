// lib/features/time_tracking/data/models/time_entry_model.dart

/// Modello per la tabella time_entries
class TimeEntry {
  final String timeId;
  final String firmId;
  final String matterId;
  final String userId;
  final DateTime startedAt;
  final int minutes;
  final String? type; // enum time_type: work, meeting, hearing, travel, admin
  final String? description;
  final double? rateUsed;
  final bool billable;
  final DateTime? createdAt;

  const TimeEntry({
    required this.timeId,
    required this.firmId,
    required this.matterId,
    required this.userId,
    required this.startedAt,
    required this.minutes,
    this.type,
    this.description,
    this.rateUsed,
    this.billable = true,
    this.createdAt,
  });

  // Nomi colonna: aderenti allo schema Supabase
  static const colId = 'time_id';
  static const colFirmId = 'firm_id';
  static const colMatterId = 'matter_id';
  static const colUserId = 'user_id';
  static const colStartedAt = 'started_at';
  static const colMinutes = 'minutes';
  static const colType = 'type';
  static const colDescription = 'description';
  static const colRateUsed = 'rate_used';
  static const colBillable = 'billable';
  static const colCreatedAt = 'created_at';

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
        timeId: json[colId] as String,
        firmId: json[colFirmId] as String,
        matterId: json[colMatterId] as String,
        userId: json[colUserId] as String,
        startedAt: DateTime.parse(json[colStartedAt] as String),
        minutes: json[colMinutes] as int,
        type: json[colType] as String?,
        description: json[colDescription] as String?,
        rateUsed: json[colRateUsed] != null 
            ? double.parse(json[colRateUsed].toString()) 
            : null,
        billable: json[colBillable] as bool? ?? true,
        createdAt: json[colCreatedAt] != null
            ? DateTime.parse(json[colCreatedAt] as String)
            : null,
      );

  /// Per insert: non includo time_id/created_at (gestiti dal DB)
  Map<String, dynamic> toInsertJson() => {
        colFirmId: firmId,
        colMatterId: matterId,
        colUserId: userId,
        colStartedAt: startedAt.toIso8601String(),
        colMinutes: minutes,
        if (type != null) colType: type,
        if (description != null) colDescription: description,
        if (rateUsed != null) colRateUsed: rateUsed,
        colBillable: billable,
      };

  /// Per update: includo solo i campi modificabili
  Map<String, dynamic> toUpdateJson() => {
        if (type != null) colType: type,
        if (description != null) colDescription: description,
        if (rateUsed != null) colRateUsed: rateUsed,
        colBillable: billable,
      };

  TimeEntry copyWith({
    String? timeId,
    String? firmId,
    String? matterId,
    String? userId,
    DateTime? startedAt,
    int? minutes,
    String? type,
    String? description,
    double? rateUsed,
    bool? billable,
    DateTime? createdAt,
  }) =>
      TimeEntry(
        timeId: timeId ?? this.timeId,
        firmId: firmId ?? this.firmId,
        matterId: matterId ?? this.matterId,
        userId: userId ?? this.userId,
        startedAt: startedAt ?? this.startedAt,
        minutes: minutes ?? this.minutes,
        type: type ?? this.type,
        description: description ?? this.description,
        rateUsed: rateUsed ?? this.rateUsed,
        billable: billable ?? this.billable,
        createdAt: createdAt ?? this.createdAt,
      );

  // Getters utili
  double get hours => minutes / 60.0;
  bool get isBillable => billable;
  String get displayType => type ?? 'work';
  
  @override
  String toString() => 'TimeEntry(id: $timeId, matter: $matterId, minutes: $minutes, billable: $billable)';
}