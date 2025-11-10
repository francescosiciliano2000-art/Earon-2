import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../../design system/icons/app_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design system/theme/themes.dart';

class StatusBanner extends StatefulWidget {
  const StatusBanner({super.key});

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _tokenTimer; // timer periodico per controllo token
  bool _offline = false;
  bool _tokenExpiring = false;
  String? _envLabel;

  @override
  void initState() {
    super.initState();
    // ENV label (molto semplice: mostriamo "DEV" se debugMode; per staging/prod in futuro leggiamo da Env)
    const bool dev =
        bool.fromEnvironment('dart.vm.product') == false; // false in release
    _envLabel = dev ? 'DEV' : null;

    // Offline/online
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final off = results.every((r) => r == ConnectivityResult.none);
      if (!mounted) return; // evita setState dopo dispose
      setState(() => _offline = off);
    });

    // Controllo token (ogni 30s)
    _tokenTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return; // evita setState dopo dispose
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() => _tokenExpiring = false);
        return;
      }
      final exp = session.expiresAt; // seconds since epoch
      if (exp != null) {
        final expiry =
            DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
                .toLocal();
        final remaining = expiry.difference(DateTime.now());
        setState(() =>
            _tokenExpiring = remaining.inMinutes <= 5); // avvisa se < 5 min
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tokenTimer?.cancel(); // ferma timer quando il widget viene smontato
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = <(_BannerKind, String)>[];
    if (_envLabel != null) {
      messages.add((_BannerKind.primary, 'Ambiente: ${_envLabel!}'));
    }
    if (_offline) {
      messages.add((
        _BannerKind.secondary,
        'Sei offline — i dati potrebbero non aggiornarsi'
      ));
    }
    if (_tokenExpiring) {
      messages.add(
          (_BannerKind.error, 'Sessione in scadenza — riaccedi se necessario'));
    }

    if (messages.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in messages) _Banner(message: m.$2, kind: m.$1),
      ],
    );
  }
}

enum _BannerKind { primary, secondary, error }

class _Banner extends StatelessWidget {
  final String message;
  final _BannerKind kind;
  const _Banner({required this.message, required this.kind});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final Color ic;
    switch (kind) {
      case _BannerKind.primary:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        ic = cs.primary;
        break;
      case _BannerKind.secondary:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        ic = cs.secondary;
        break;
      case _BannerKind.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        ic = cs.error;
        break;
    }

    final double unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return Container(
      width: double.infinity,
      color: bg,
      padding: EdgeInsets.symmetric(
        vertical: unit,
        horizontal: unit * 1.5,
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, color: ic),
          SizedBox(width: unit),
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
