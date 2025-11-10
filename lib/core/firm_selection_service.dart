import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class Firm {
  final String id;
  final String? name;
  const Firm({required this.id, this.name});
}

class FirmSelectionService {
  static const _keyId = 'currentFirmId';
  static const _keyName = 'currentFirmName';

  Future<void> saveCurrentFirm(Firm firm) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyId, firm.id);
    if ((firm.name ?? '').isNotEmpty) {
      await sp.setString(_keyName, firm.name!);
    }
    debugPrint('[Firm] saved: id=${firm.id} name=${firm.name ?? 'null'}');
  }

  Future<Firm?> loadCurrentFirm() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_keyId);
    final name = sp.getString(_keyName);
    if (id == null || id.isEmpty) return null;
    return Firm(id: id, name: name);
  }
}
