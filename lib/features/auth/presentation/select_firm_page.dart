import 'package:flutter/material.dart';
import '../../../design system/components/top_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_router.dart';
import '../../../core/supa_helpers.dart';
import '../../../design system/icons/app_icons.dart';

import '../../../design system/components/spinner.dart';
import '../../../design system/components/list_tile.dart';

class SelectFirmPage extends StatefulWidget {
  const SelectFirmPage({super.key});
  @override
  State<SelectFirmPage> createState() => _SelectFirmPageState();
}

class _SelectFirmPageState extends State<SelectFirmPage> {
  List<Map<String, dynamic>> firms = [];
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = sb.auth.currentUser;
      if (user == null) {
        err = 'Utente non autenticato. Accedi per selezionare uno studio.';
        return;
      }
      debugPrint(
          '[SelectFirm] loading firms for uid=${user.id} email=${user.email ?? 'null'}');

      // Prendi tutte le firm_id collegate al profilo utente
      final profs =
          await sb.from('profiles').select('firm_id').eq('user_id', user.id);

      final ids = (profs as List)
          .map((e) => e['firm_id'])
          .where((v) => v != null && v.toString().isNotEmpty)
          .map((v) => v.toString())
          .toList();

      // Se non ci sono firm, stop
      if (ids.isEmpty) {
        firms = [];
      } else {
        // Usa inFilter al posto di in_
        debugPrint('[SelectFirm] querying firms for ids=$ids');
        firms = await sb.from('firms').select('id,name').inFilter('id', ids);
      }
    } on AuthException catch (e) {
      err = 'Autenticazione richiesta. ${e.message}';
      debugPrint('[SelectFirm] AuthException: ${e.message}');
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('permission denied')) {
        err =
            'Impossibile caricare gli studi: permesso negato (RLS). Controlla le policy di accesso.';
      } else {
        err = 'Impossibile caricare gli studi: ${e.message}';
      }
      debugPrint('[SelectFirm] PostgrestException: ${e.message}');
    } catch (e) {
      err = 'Impossibile caricare gli studi.';
      debugPrint('[SelectFirm] errore generico: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: Center(child: Spinner(size: 24)));
    }
    if (err != null) {
      return Scaffold(
        appBar: const TopBar(leading: Text('Seleziona Studio')),
        body: Center(
            child: Text(
          err!,
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Theme.of(context).colorScheme.error),
        )),
      );
    }
    if (firms.isEmpty) {
      return Scaffold(
        appBar: const TopBar(leading: Text('Seleziona Studio')),
        body: const Center(
            child: Text('Nessuna firm associata. Contatta l’amministratore.')),
      );
    }
    return Scaffold(
      appBar: const TopBar(leading: Text('Seleziona Studio')),
      body: ListView.builder(
        itemCount: firms.length,
        itemBuilder: (_, i) {
          final f = firms[i];
          return AppListTile(
            title: Text(f['name']),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () async {
              final id = f['id'] as String;
              await setCurrentFirmId(id);
              debugPrint('[SelectFirm] firm selezionata: id=$id');
              appNavigatorKey.currentState?.pushReplacementNamed('/dashboard');
            },
          );
        },
      ),
    );
  }
}
