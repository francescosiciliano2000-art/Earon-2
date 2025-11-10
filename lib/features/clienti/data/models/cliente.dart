class Cliente {
  final String clientId;
  final String firmId;
  final String name;
  final String? taxCode;
  final String? vatNumber;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? postalCode; // allineato al DB: postal_code
  final String? country;
  final String? notes; // allineato al DB: notes
  final String? status; // enum record_status
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Cliente({
    required this.clientId,
    required this.firmId,
    required this.name,
    this.taxCode,
    this.vatNumber,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  // Nomi colonna: aderenti allo schema Supabase
  static const colId = 'client_id';
  static const colFirmId = 'firm_id';
  static const colName = 'name';
  static const colTax = 'tax_code';
  static const colVat = 'vat_number';
  static const colEmail = 'email';
  static const colPhone = 'phone';
  static const colAddress = 'address';
  static const colCity = 'city';
  static const colPostalCode = 'postal_code';
  static const colCountry = 'country';
  static const colNotes = 'notes';
  static const colStatus = 'status';
  static const colCreated = 'created_at';
  static const colUpdated = 'updated_at';

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        clientId: (json[colId] ?? '').toString(),
        firmId: (json[colFirmId] ?? '').toString(),
        name: (json[colName] ?? '').toString(),
        taxCode: json[colTax]?.toString(),
        vatNumber: json[colVat]?.toString(),
        email: json[colEmail]?.toString(),
        phone: json[colPhone]?.toString(),
        address: json[colAddress]?.toString(),
        city: json[colCity]?.toString(),
        postalCode: json[colPostalCode]?.toString(),
        country: json[colCountry]?.toString(),
        notes: json[colNotes]?.toString(),
        status: json[colStatus]?.toString(),
        createdAt: json[colCreated] != null
            ? DateTime.tryParse(json[colCreated].toString())
            : null,
        updatedAt: json[colUpdated] != null
            ? DateTime.tryParse(json[colUpdated].toString())
            : null,
      );

  /// Per insert: non includo client_id/created_at (gestiti dal DB)
  Map<String, dynamic> toInsertJson() => {
        colFirmId: firmId,
        colName: name,
        if (taxCode != null) colTax: taxCode,
        if (vatNumber != null) colVat: vatNumber,
        if (email != null) colEmail: email,
        if (phone != null) colPhone: phone,
        if (address != null) colAddress: address,
        if (city != null) colCity: city,
        if (postalCode != null) colPostalCode: postalCode,
        if (country != null) colCountry: country,
        if (notes != null) colNotes: notes,
      };
}
