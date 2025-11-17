import 'package:flutter/material.dart';
import 'dart:async' show unawaited;
import 'dart:io' show HandshakeException;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/audit/audit_service.dart';
import '../../../app_router.dart';
import '../../../core/supa_helpers.dart';
import '../../../core/validators.dart';
import '../../../core/shared_prefs.dart' as sp;

// DS components
import '../../../design system/components/input.dart';
import '../../../design system/components/input_group.dart';
import '../../../design system/components/checkbox.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/label.dart';
import '../../../design system/components/app_logo.dart';
import '../../../design system/theme/themes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool loading = false;
  String? error;
  String? emailErr, passErr;
  bool rememberMe = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    emailCtl.dispose();
    passCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final flag = await sp.getRememberMe();
    final savedEmail = await sp.getRememberedEmail();
    if (mounted) {
      setState(() {
        rememberMe = flag;
        if (flag && (savedEmail ?? '').isNotEmpty) {
          emailCtl.text = savedEmail!;
        }
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      error = null;
      emailErr = Validators.email(emailCtl.text);
      passErr = Validators.required(passCtl.text, field: 'Password');
    });
    if (emailErr != null || passErr != null) return;

    setState(() => loading = true);
    try {
      await sb.auth.signInWithPassword(
        email: emailCtl.text.trim(),
        password: passCtl.text,
      );

      // Aggiorna preferenze Remember Me (solo email, mai password)
      await sp.setRememberMe(rememberMe);
      if (rememberMe) {
        await sp.setRememberedEmail(emailCtl.text.trim());
      } else {
        await sp.clearRememberedEmail();
      }

      final uid = sb.auth.currentUser!.id;
      final prof = await sb
          .from('profiles')
          .select('firm_id, role, full_name')
          .eq('user_id', uid)
          .limit(1)
          .maybeSingle();

      final firmId = prof == null ? null : prof['firm_id'] as String?;
      final nav = appNavigatorKey.currentState;
      if (firmId == null) {
        nav?.pushReplacementNamed('/auth/select_firm');
        // Audit: login riuscito (anche se necessita selezione studio)
        // Non blocca UI in caso di errore.
        unawaited(AuditService.logEvent(entity: 'auth', action: 'LOGIN'));
      } else {
        await setCurrentFirmId(firmId);
        nav?.pushReplacementNamed('/clienti');
        // Audit: login riuscito
        unawaited(AuditService.logEvent(entity: 'auth', action: 'LOGIN'));
      }
    } on AuthException catch (e) {
      final rawMsg = e.message.trim();
      final lower = rawMsg.toLowerCase();
      if (e.statusCode == '400' ||
          e.statusCode == '401' ||
          lower.contains('invalid') ||
          lower.contains('credentials')) {
        error = 'Credenziali non valide.';
      } else if (lower.contains('email not confirmed') ||
          lower.contains('email_not_confirmed') ||
          lower.contains('not confirmed')) {
        error =
            'Email non confermata. Controlla la casella di posta o richiedi una nuova email di verifica.';
      } else {
        error = rawMsg.isNotEmpty ? rawMsg : 'Errore di autenticazione.';
      }
    } on HandshakeException catch (_) {
      // Errore tipico su Windows quando mancano le CA di sistema o proxy aziendale.
      error =
          'Errore di connessione sicura (TLS). Aggiorna i certificati di Windows o verifica il proxy aziendale.';
    } catch (_) {
      error = 'Connessione non disponibile.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dt = t.extension<DefaultTokens>();
    final spacing = (dt?.spacingUnit ?? 8.0) * 2;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900; // usa i tuoi breakpoints se preferisci

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // --- Colonna sinistra (form) ---
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing * 2,
                    vertical: spacing * 3,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppLogo(),
                        SizedBox(height: spacing * 2),
                        Text(
                          'Accedi al tuo account',
                          style: t.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inserisci la tua mail qui sotto per accedere al tuo account',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.hintColor,
                          ),
                        ),
                        SizedBox(height: spacing * 2.5),

                        // Email (Label sopra input) — niente 'const'
                        AppLabel(text: 'Email'),
                        const SizedBox(height: 8),
                        AppInput(
                          controller: emailCtl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          hintText: 'm@example.com',
                          onChanged: (_) => setState(() => emailErr = null),
                        ),
                        if (emailErr != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              emailErr!,
                              style: t.textTheme.bodySmall!
                                  .copyWith(color: t.colorScheme.error),
                            ),
                          ),

                        SizedBox(height: spacing * 2),

                        // Password (Label sopra input) — niente 'const'
                        AppLabel(text: 'Password'),
                        const SizedBox(height: 8),
                        AppInputGroup(
                          controller: passCtl,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          hintText: '••••••••',
                          onSubmitted: (_) => loading ? null : _login(),
                          onChanged: (_) => setState(() => passErr = null),
                          trailing: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                            child: Icon(
                              _passwordVisible ? AppIcons.eyeSlash : AppIcons.eye,
                              size: 16,
                            ),
                          ),
                        ),
                        if (passErr != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              passErr!,
                              style: t.textTheme.bodySmall!
                                  .copyWith(color: t.colorScheme.error),
                            ),
                          ),

                        // Reduce spacing between password input and the checkbox
                        SizedBox(height: spacing * 0.75),
                        Row(
                          children: [
                            AppCheckbox(
                              value: rememberMe,
                              enabled: !loading,
                              onChanged: (v) => setState(() => rememberMe = v),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ricordami su questo dispositivo',
                              style: t.textTheme.bodySmall,
                            ),
                          ],
                        ),

                        if (error != null)
                          Padding(
                            padding: EdgeInsets.only(top: spacing),
                            child: Text(
                              error!,
                              style: t.textTheme.bodySmall!
                                  .copyWith(color: t.colorScheme.error),
                            ),
                          ),

                        // Increase spacing between the checkbox row (and optional error)
                        // and the "Accedi" button — further enlarged per request
                        SizedBox(height: spacing * 2.0),
                        AppButton(
                          variant: AppButtonVariant.default_,
                          onPressed: loading ? null : _login,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (loading)
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: Spinner(size: 18),
                                ),
                              if (!loading) const SizedBox(width: 0),
                              const SizedBox(width: 8),
                              Text(loading ? 'Accesso…' : 'Accedi'),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing * 0.75),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            variant: AppButtonVariant.link,
                            onPressed: () => appRouter.go('/auth/forgot'),
                            child: const Text('Password dimenticata?'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- Colonna destra (immagine) ---
            if (isWide)
              Expanded(
                flex: 6,
                child: Container(
                  height: double.infinity,
                  color: t.colorScheme.surfaceContainerHighest,
                  child: Image.network(
                    'https://plus.unsplash.com/premium_photo-1698084059484-021206e1c62a?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=776',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        // withOpacity() deprecato -> withValues(alpha:)
                        color: t.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
