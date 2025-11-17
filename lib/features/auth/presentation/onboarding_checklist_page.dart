import 'package:flutter/material.dart';
import '../../../design system/components/top_bar.dart';
import '../../../core/supa_helpers.dart';
import '../../../design system/components/button.dart';
import '../../../design system/components/checkbox.dart';
import '../../../design system/components/spinner.dart';
import '../../../design system/theme/themes.dart';

class OnboardingChecklistPage extends StatefulWidget {
  const OnboardingChecklistPage({super.key});
  @override
  State<OnboardingChecklistPage> createState() =>
      _OnboardingChecklistPageState();
}

class _OnboardingChecklistPageState extends State<OnboardingChecklistPage> {
  bool loading = true;
  bool hasFirmData = false,
      hasTaxProfile = false,
      hasLogo = false,
      hasTeam = false;

  Future<void> _load() async {
    try {
      final fid = await getCurrentFirmId();
      if (fid != null) {
        final firm = await sb
            .from('firms')
            .select('id,name,vat,pec,logo_url')
            .eq('id', fid)
            .maybeSingle();

        hasFirmData = (firm?['vat'] != null && firm?['pec'] != null);
        hasLogo = ((firm?['logo_url'] ?? '') as String).isNotEmpty;

        final tax = await sb
            .from('firm_tax_profiles')
            .select('id')
            .eq('firm_id', fid)
            .lte('valid_from', todayISODate())
            .gte('valid_to', todayISODate())
            .maybeSingle();
        hasTaxProfile = tax != null;

        final users =
            await sb.from('profiles').select('id').eq('firm_id', fid).limit(2);
        hasTeam = (users as List).length > 1;
      }
    } catch (_) {
      // lascia i flag a false
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: Center(child: Spinner(size: 24)));
    }
    final checks = [
      ('Dati fiscali studio', hasFirmData),
      ('Profilo fiscale valido oggi', hasTaxProfile),
      ('Logo per intestazioni', hasLogo),
      ('Almeno 1 collega invitato', hasTeam),
    ];
    // Spacing tramite DefaultTokens.spacingUnit
    final dt = Theme.of(context).extension<DefaultTokens>();
    final space = dt?.spacingUnit ?? 8.0;

    return Scaffold(
      appBar: const TopBar(leading: Text('Onboarding')),
      body: ListView(
        padding: EdgeInsets.all(space * 2),
        children: [
          for (final c in checks)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppCheckbox(value: c.$2, onChanged: null, enabled: false),
                SizedBox(width: space),
                Flexible(child: Text(c.$1)),
              ],
            ),
          SizedBox(height: space),
          AppButton(
            variant: AppButtonVariant.default_,
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/clienti'),
            child: const Text('Vai ai Clienti'),
          ),
        ],
      ),
    );
  }
}
