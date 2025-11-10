// lib/features/agenda/data/models/task_model.dart
// Modello Task aderente allo schema reale (public.tasks)

class Task {
  // Colonne principali secondo lo schema reale
  final String taskId; // PK
  final String firmId;
  final String? matterId;
  final String? assignedTo;
  final String createdBy;
  final String title;
  final String? description;
  final String? priority; // default: 'medium'
  final String? status; // default: 'pending'
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double? estimatedHours;
  final double? actualHours;
  final List<String>? tags;
  final List<String>? dependencies; // UUID array
  final Map<String, dynamic>? attachments; // JSONB
  final Map<String, dynamic>? comments; // JSONB
  final Map<String, dynamic>? recurringPattern; // JSONB
  final String? parentTaskId;
  final String? performedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Task({
    required this.taskId,
    required this.firmId,
    this.matterId,
    this.assignedTo,
    required this.createdBy,
    required this.title,
    this.description,
    this.priority,
    this.status,
    this.dueDate,
    this.completedAt,
    this.estimatedHours,
    this.actualHours,
    this.tags,
    this.dependencies,
    this.attachments,
    this.comments,
    this.recurringPattern,
    this.parentTaskId,
    this.performedBy,
    this.createdAt,
    this.updatedAt,
  });

  // Nomi colonna: aderenti allo schema Supabase/Postgres
  static const colId = 'task_id';
  static const colFirmId = 'firm_id';
  static const colMatterId = 'matter_id';
  static const colAssignedTo = 'assigned_to';
  static const colCreatedBy = 'created_by';
  static const colTitle = 'title';
  static const colDescription = 'description';
  static const colPriority = 'priority';
  static const colStatus = 'status';
  static const colDueDate = 'due_date';
  static const colCompletedAt = 'completed_at';
  static const colEstimatedHours = 'estimated_hours';
  static const colActualHours = 'actual_hours';
  static const colTags = 'tags';
  static const colDependencies = 'dependencies';
  static const colAttachments = 'attachments';
  static const colComments = 'comments';
  static const colRecurringPattern = 'recurring_pattern';
  static const colParentTaskId = 'parent_task_id';
  static const colPerformedBy = 'performed_by';
  static const colCreatedAt = 'created_at';
  static const colUpdatedAt = 'updated_at';

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: (json[colId] ?? '').toString(),
      firmId: (json[colFirmId] ?? '').toString(),
      matterId: json[colMatterId]?.toString(),
      assignedTo: json[colAssignedTo]?.toString(),
      createdBy: (json[colCreatedBy] ?? '').toString(),
      title: (json[colTitle] ?? '').toString(),
      description: json[colDescription]?.toString(),
      priority: json[colPriority]?.toString(),
      status: json[colStatus]?.toString(),
      dueDate: json[colDueDate] != null
          ? DateTime.tryParse(json[colDueDate].toString())
          : null,
      completedAt: json[colCompletedAt] != null
          ? DateTime.tryParse(json[colCompletedAt].toString())
          : null,
      estimatedHours: json[colEstimatedHours] != null
          ? double.tryParse(json[colEstimatedHours].toString())
          : null,
      actualHours: json[colActualHours] != null
          ? double.tryParse(json[colActualHours].toString())
          : null,
      tags: (json[colTags] as List?)?.map((e) => e.toString()).toList(),
      dependencies: (json[colDependencies] as List?)?.map((e) => e.toString()).toList(),
      attachments: json[colAttachments] as Map<String, dynamic>?,
      comments: json[colComments] as Map<String, dynamic>?,
      recurringPattern: json[colRecurringPattern] as Map<String, dynamic>?,
      parentTaskId: json[colParentTaskId]?.toString(),
      performedBy: json[colPerformedBy]?.toString(),
      createdAt: json[colCreatedAt] != null
          ? DateTime.tryParse(json[colCreatedAt].toString())
          : null,
      updatedAt: json[colUpdatedAt] != null
          ? DateTime.tryParse(json[colUpdatedAt].toString())
          : null,
    );
  }

  /// Per insert: non includo task_id/created_at/updated_at (gestiti dal DB)
  Map<String, dynamic> toInsertJson() => {
        colFirmId: firmId,
        if (matterId != null) colMatterId: matterId,
        if (assignedTo != null) colAssignedTo: assignedTo,
        colCreatedBy: createdBy,
        colTitle: title,
        if (description != null) colDescription: description,
        if (priority != null) colPriority: priority,
        if (status != null) colStatus: status,
        if (dueDate != null) colDueDate: dueDate!.toIso8601String().split('T')[0],
        if (completedAt != null) colCompletedAt: completedAt!.toIso8601String(),
        if (estimatedHours != null) colEstimatedHours: estimatedHours,
        if (actualHours != null) colActualHours: actualHours,
        if (tags != null) colTags: tags,
        if (dependencies != null) colDependencies: dependencies,
        if (attachments != null) colAttachments: attachments,
        if (comments != null) colComments: comments,
        if (recurringPattern != null) colRecurringPattern: recurringPattern,
        if (parentTaskId != null) colParentTaskId: parentTaskId,
        if (performedBy != null) colPerformedBy: performedBy,
      };

  /// Per update: includo solo i campi modificabili
  Map<String, dynamic> toUpdateJson() => {
        if (matterId != null) colMatterId: matterId,
        if (assignedTo != null) colAssignedTo: assignedTo,
        colTitle: title,
        if (description != null) colDescription: description,
        if (priority != null) colPriority: priority,
        if (status != null) colStatus: status,
        if (dueDate != null) colDueDate: dueDate!.toIso8601String().split('T')[0],
        if (completedAt != null) colCompletedAt: completedAt!.toIso8601String(),
        if (estimatedHours != null) colEstimatedHours: estimatedHours,
        if (actualHours != null) colActualHours: actualHours,
        if (tags != null) colTags: tags,
        if (dependencies != null) colDependencies: dependencies,
        if (attachments != null) colAttachments: attachments,
        if (comments != null) colComments: comments,
        if (recurringPattern != null) colRecurringPattern: recurringPattern,
        if (parentTaskId != null) colParentTaskId: parentTaskId,
        if (performedBy != null) colPerformedBy: performedBy,
      };

  /// Copia con modifiche
  Task copyWith({
    String? taskId,
    String? firmId,
    String? matterId,
    String? assignedTo,
    String? createdBy,
    String? title,
    String? description,
    String? priority,
    String? status,
    DateTime? dueDate,
    DateTime? completedAt,
    double? estimatedHours,
    double? actualHours,
    List<String>? tags,
    List<String>? dependencies,
    Map<String, dynamic>? attachments,
    Map<String, dynamic>? comments,
    Map<String, dynamic>? recurringPattern,
    String? parentTaskId,
    String? performedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      taskId: taskId ?? this.taskId,
      firmId: firmId ?? this.firmId,
      matterId: matterId ?? this.matterId,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      tags: tags ?? this.tags,
      dependencies: dependencies ?? this.dependencies,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      performedBy: performedBy ?? this.performedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verifica se il task è completato
  bool get isCompleted => status == 'completed' || completedAt != null;

  /// Verifica se il task è in ritardo
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Verifica se il task è in scadenza (entro 24 ore)
  bool get isDueSoon {
    if (dueDate == null || isCompleted) return false;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return dueDate!.isBefore(tomorrow) && dueDate!.isAfter(now);
  }
}