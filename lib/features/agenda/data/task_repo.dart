// lib/features/agenda/data/task_repo.dart
// Repository per la gestione dei Task con Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/task_model.dart';

class TaskRepo {
  static const _table = 'tasks';
  final _supabase = Supabase.instance.client;

  /// Ottiene tutti i task per una firm
  Future<List<Task>> getTasksByFirm(String firmId, {
    String? status,
    String? assignedTo,
    String? matterId,
    int? limit,
    int? offset,
  }) async {
    try {
      PostgrestFilterBuilder query = _supabase
          .from(_table)
          .select()
          .eq(Task.colFirmId, firmId);

      if (status != null) {
        query = query.eq(Task.colStatus, status);
      }
      if (assignedTo != null) {
        query = query.eq(Task.colAssignedTo, assignedTo);
      }
      if (matterId != null) {
        query = query.eq(Task.colMatterId, matterId);
      }

      var orderedQuery = query.order(Task.colCreatedAt, ascending: false);

      if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }
      if (offset != null) {
        orderedQuery = orderedQuery.range(offset, offset + (limit ?? 50) - 1);
      }

      final response = await orderedQuery;
      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero dei task: $e');
    }
  }

  /// Ottiene un task per ID
  Future<Task?> getTaskById(String taskId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colId, taskId)
          .maybeSingle();

      return response != null ? Task.fromJson(response) : null;
    } catch (e) {
      throw Exception('Errore nel recupero del task: $e');
    }
  }

  /// Crea un nuovo task
  Future<Task> createTask(Task task) async {
    try {
      final response = await _supabase
          .from(_table)
          .insert(task.toInsertJson())
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      throw Exception('Errore nella creazione del task: $e');
    }
  }

  /// Aggiorna un task esistente
  Future<Task> updateTask(String taskId, Task task) async {
    try {
      final response = await _supabase
          .from(_table)
          .update(task.toUpdateJson())
          .eq(Task.colId, taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      throw Exception('Errore nell\'aggiornamento del task: $e');
    }
  }

  /// Elimina un task
  Future<void> deleteTask(String taskId) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq(Task.colId, taskId);
    } catch (e) {
      throw Exception('Errore nell\'eliminazione del task: $e');
    }
  }

  /// Marca un task come completato
  Future<Task> completeTask(String taskId) async {
    try {
      final response = await _supabase
          .from(_table)
          .update({
            Task.colStatus: 'completed',
            Task.colCompletedAt: DateTime.now().toIso8601String(),
          })
          .eq(Task.colId, taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      throw Exception('Errore nel completamento del task: $e');
    }
  }

  /// Riapre un task completato
  Future<Task> reopenTask(String taskId) async {
    try {
      final response = await _supabase
          .from(_table)
          .update({
            Task.colStatus: 'pending',
            Task.colCompletedAt: null,
          })
          .eq(Task.colId, taskId)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      throw Exception('Errore nella riapertura del task: $e');
    }
  }

  /// Ottiene i task in scadenza per una firm
  Future<List<Task>> getUpcomingTasks(String firmId, {int days = 7}) async {
    try {
      final endDate = DateTime.now().add(Duration(days: days));
      
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colFirmId, firmId)
          .neq(Task.colStatus, 'completed')
          .lte(Task.colDueDate, endDate.toIso8601String().split('T')[0])
          .order(Task.colDueDate, ascending: true);

      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero dei task in scadenza: $e');
    }
  }

  /// Ottiene i task in ritardo per una firm
  Future<List<Task>> getOverdueTasks(String firmId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colFirmId, firmId)
          .neq(Task.colStatus, 'completed')
          .lt(Task.colDueDate, today)
          .order(Task.colDueDate, ascending: true);

      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero dei task in ritardo: $e');
    }
  }

  /// Ottiene i task per una pratica specifica
  Future<List<Task>> getTasksByMatter(String matterId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colMatterId, matterId)
          .order(Task.colCreatedAt, ascending: false);

      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero dei task per la pratica: $e');
    }
  }

  /// Ottiene i task assegnati a un utente
  Future<List<Task>> getTasksByAssignee(String userId, String firmId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colFirmId, firmId)
          .eq(Task.colAssignedTo, userId)
          .order(Task.colDueDate, ascending: true);

      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero dei task assegnati: $e');
    }
  }

  /// Conta i task per stato
  Future<Map<String, int>> getTaskCountsByStatus(String firmId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('status')
          .eq(Task.colFirmId, firmId);

      final counts = <String, int>{};
      for (final row in response as List) {
        final status = row['status'] as String? ?? 'pending';
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Errore nel conteggio dei task: $e');
    }
  }

  /// Cerca task per titolo o descrizione
  Future<List<Task>> searchTasks(String firmId, String query) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq(Task.colFirmId, firmId)
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order(Task.colCreatedAt, ascending: false);

      return (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Errore nella ricerca dei task: $e');
    }
  }
}