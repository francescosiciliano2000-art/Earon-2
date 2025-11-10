import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ChangeNotifier che ascolta i cambi di stato di autenticazione
/// e consente a GoRouter di fare refresh/redirect automatici.
class AuthStateNotifier extends ChangeNotifier {
  late final StreamSubscription _sub;

  AuthStateNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      final uid = session?.user.id;
      final email = session?.user.email;
      debugPrint(
          '[Auth] onAuthStateChange: event=$event uid=${uid ?? 'null'} email=${email ?? 'null'}');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Istanza globale usata da GoRouter
final AuthStateNotifier authStateNotifier = AuthStateNotifier();
