import 'package:flutter/material.dart';

// DS components
import '../../../design system/components/button.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/components/input.dart';
import '../../../design system/theme/themes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/validators.dart';
// Manteniamo AppToast legacy finché non montiamo AppToaster globalmente
import '../../../design system/components/sonner.dart';
import '../../../app_router.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailCtl = TextEditingController();
  String? info, err, emailErr;
  bool sending = false;

  @override
  void dispose() {
    emailCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      info = null;
      err = null;
      emailErr = Validators.email(emailCtl.text);
    });
    if (emailErr != null) return;

    setState(() => sending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        emailCtl.text.trim(),
        // redirectTo: 'https://tua-app/reset',
      );
      info = 'Email inviata. Controlla la casella di posta.';
      if (mounted) {
        AppToaster.of(context).success('Email di reset inviata');
      }
    } catch (_) {
      err = 'Impossibile inviare email di reset.';
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = theme.extension<DefaultTokens>();
    final spacing = dt?.spacingUnit ?? 8.0;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return SingleChildScrollView(
              padding: EdgeInsets.all(spacing * 2),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: h - spacing * 4,
                    maxWidth: 420,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Password dimenticata',
                          style: theme.textTheme.headlineMedium),
                      SizedBox(height: spacing * 1.5),
                      AppInput(
                        controller: emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        hintText: 'Email',
                        onChanged: (_) => setState(() => emailErr = null),
                        onSubmitted: (_) => sending ? null : _send(),
                      ),
                      if (emailErr != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing * 0.5),
                          child: Text(
                            emailErr!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                    color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      SizedBox(height: spacing * 1.5),
                      AppButton(
                        variant: AppButtonVariant.default_,
                        onPressed: sending ? null : _send,
                        child: sending
                            ? const SizedBox(
                                height: 16, width: 16, child: Spinner(size: 18))
                            : const Text('Invia reset'),
                      ),
                      SizedBox(height: spacing * 1),
                      AppButton(
                        variant: AppButtonVariant.outline,
                        onPressed: () => appRouter.go('/auth/login'),
                        child: const Text('Torna al login'),
                      ),
                      if (info != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing * 1),
                          child: Text(info!),
                        ),
                      if (err != null)
                        Padding(
                          padding: EdgeInsets.only(top: spacing * 1),
                          child: Text(
                            err!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                    color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
