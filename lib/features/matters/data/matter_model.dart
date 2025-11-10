// lib/features/matters/data/matter_model.dart
// Modello Matter aderente allo schema reale (public.matters)

class Matter {
  // Colonne principali secondo lo schema reale
  final String matterId; // PK
  final String firmId;
  final String clientId;
  final String code; // unique per firm
  final String title; // subject
  final String? status; // enum/user-defined
  final String? area; // opzionale (può non esistere nello schema)
  final String? court; // testo (non esiste court_id)
  final String? judge; // testo
  final String? description; // testo descrittivo
  // Campi aggiuntivi richiesti lato UI (presi dalla tabella):
  final String? counterpartyName; // controparte
  final String? rgNumber; // numero RG
  final String? opposingAttorneyName; // avvocato controparte
  final String? registryCode; // codice di registro (es. NRG/NRGCR)
  final String? courtSection; // sezione del tribunale
  final DateTime? openedAt; // date
  final DateTime? closedAt; // date
  final DateTime? createdAt; // timestamptz

  // Campo derivato da join con clients (non presente nel DB)
  final String? clientDisplayName;

  const Matter({
    required this.matterId,
    required this.firmId,
    required this.clientId,
    required this.code,
    required this.title,
    this.status,
    this.area,
    this.court,
    this.judge,
    this.description,
    this.counterpartyName,
    this.rgNumber,
    this.opposingAttorneyName,
    this.registryCode,
    this.courtSection,
    this.openedAt,
    this.closedAt,
    this.createdAt,
    this.clientDisplayName,
  });

  // Nomi colonna: aderenti allo schema Supabase/Postgres
  static const colId = 'matter_id';
  static const colFirmId = 'firm_id';
  static const colClientId = 'client_id';
  static const colCode = 'code';
  static const colTitle = 'title';
  static const colStatus = 'status';
  static const colArea = 'area';
  static const colCourt = 'court';
  static const colJudge = 'judge';
  static const colDescription = 'description';
  static const colCounterpartyName = 'counterparty_name';
  static const colRgNumber = 'rg_number';
  static const colOpposingAttorneyName = 'opposing_attorney_name';
  static const colRegistryCode = 'registry_code';
  static const colCourtSection = 'court_section';
  static const colOpenedAt = 'opened_at';
  static const colClosedAt = 'closed_at';
  static const colCreatedAt = 'created_at';

  factory Matter.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    // Estrae il nome cliente da join se presente
    String? buildClientName(dynamic clientJson) {
      if (clientJson is! Map) return null;
      final map = Map<String, dynamic>.from(clientJson);
      final kind = (map['kind'] ?? '').toString();
      if (kind == 'person') {
        final surname = (map['surname'] ?? '').toString();
        final name = (map['name'] ?? '').toString();
        final s = [surname, name].where((e) => e.trim().isNotEmpty).join(' ');
        return s.isEmpty ? null : s;
      } else if (kind == 'company') {
        // Nello schema, il nome azienda è nel campo 'name'; esiste anche 'company_type'
        final companyName = (map['name'] ?? '').toString();
        final companyType = (map['company_type'] ?? '').toString();
        final s = [companyName, companyType]
            .where((e) => e.trim().isNotEmpty)
            .join(' ');
        return s.isEmpty ? null : s;
      }
      return null;
    }

    return Matter(
      matterId: (json[colId] ?? '').toString(),
      firmId: (json[colFirmId] ?? '').toString(),
      clientId: (json[colClientId] ?? '').toString(),
      code: (json[colCode] ?? '').toString(),
      title: (json[colTitle] ?? '').toString(),
      status: json[colStatus]?.toString(),
      area: json[colArea]?.toString(),
      court: json[colCourt]?.toString(),
      judge: json[colJudge]?.toString(),
      description: json[colDescription]?.toString(),
      counterpartyName: json[colCounterpartyName]?.toString(),
      rgNumber: json[colRgNumber]?.toString(),
      opposingAttorneyName: json[colOpposingAttorneyName]?.toString(),
      registryCode: json[colRegistryCode]?.toString(),
      courtSection: json[colCourtSection]?.toString(),
      openedAt: parseDate(json[colOpenedAt]),
      closedAt: parseDate(json[colClosedAt]),
      createdAt: parseDate(json[colCreatedAt]),
      clientDisplayName: buildClientName(json['client']),
    );
  }

  Map<String, dynamic> toJson() {
    String? dateOnly(DateTime? d) =>
        d?.toIso8601String().substring(0, 10); // YYYY-MM-DD
    return {
      colId: matterId,
      colFirmId: firmId,
      colClientId: clientId,
      colCode: code,
      colTitle: title,
      if (status != null) colStatus: status,
      if (area != null) colArea: area,
      if (court != null) colCourt: court,
      if (judge != null) colJudge: judge,
      if (description != null) colDescription: description,
      if (counterpartyName != null) colCounterpartyName: counterpartyName,
      if (rgNumber != null) colRgNumber: rgNumber,
      if (opposingAttorneyName != null)
        colOpposingAttorneyName: opposingAttorneyName,
      if (registryCode != null) colRegistryCode: registryCode,
      if (courtSection != null) colCourtSection: courtSection,
      if (openedAt != null) colOpenedAt: dateOnly(openedAt),
      if (closedAt != null) colClosedAt: dateOnly(closedAt),
      if (createdAt != null) colCreatedAt: createdAt!.toIso8601String(),
    };
  }
}
