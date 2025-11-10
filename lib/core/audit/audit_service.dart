import 'package:supabase_flutter/supabase_flutter.dart';

/// AuditService: invia eventi di audit al backend tramite RPC.
///
/// Usa la funzione Postgres `audit_log_event(p_entity, p_entity_id, p_action, p_diff)`.
/// Tutte le eccezioni vengono catturate silenziosamente per non interrompere il flusso UI.
class AuditService {
  const AuditService();

  /// Registra un evento di audit.
  ///
  /// Esempi:
  /// - logEvent(entity: 'auth', action: 'LOGIN')
  /// - logEvent(entity: 'auth', action: 'LOGOUT')
  /// - logEvent(entity: 'matters', action: 'EXPORT', entityId: '123')
  static Future<void> logEvent({
    required String entity,
    String? entityId,
    required String action,
    Map<String, dynamic>? diff,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.rpc(
        'audit_log_event',
        params: {
          'p_entity': entity,
          'p_entity_id': entityId,
          'p_action': action,
          'p_diff': diff,
        },
      );
    } catch (_) {
      // Silently ignore errors: audit non deve bloccare l'app.
    }
  }
}