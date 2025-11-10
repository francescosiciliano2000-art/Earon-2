// lib/features/expenses/data/models/expense_model.dart

/// Modello per la tabella expenses
class Expense {
  final String expenseId;
  final String firmId;
  final String? matterId;
  final String userId;
  final String type; // enum expense_type: court_fee, postage, expert, travel, other
  final String description;
  final double amount;
  final String currency;
  final String? receiptPath;
  final bool billable;
  final bool billed;
  final String? invoiceId;
  final DateTime incurredAt;
  final String status; // enum record_status: active, deleted
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Expense({
    required this.expenseId,
    required this.firmId,
    this.matterId,
    required this.userId,
    required this.type,
    required this.description,
    required this.amount,
    this.currency = 'EUR',
    this.receiptPath,
    this.billable = true,
    this.billed = false,
    this.invoiceId,
    required this.incurredAt,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  // Nomi colonna: aderenti allo schema Supabase
  static const colId = 'expense_id';
  static const colFirmId = 'firm_id';
  static const colMatterId = 'matter_id';
  static const colUserId = 'user_id';
  static const colType = 'type';
  static const colDescription = 'description';
  static const colAmount = 'amount';
  static const colCurrency = 'currency';
  static const colReceiptPath = 'receipt_path';
  static const colBillable = 'billable';
  static const colBilled = 'billed';
  static const colInvoiceId = 'invoice_id';
  static const colIncurredAt = 'incurred_at';
  static const colStatus = 'status';
  static const colCreatedAt = 'created_at';
  static const colUpdatedAt = 'updated_at';

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        expenseId: json[colId] as String,
        firmId: json[colFirmId] as String,
        matterId: json[colMatterId] as String?,
        userId: json[colUserId] as String,
        type: json[colType] as String,
        description: json[colDescription] as String,
        amount: double.parse(json[colAmount].toString()),
        currency: json[colCurrency] as String? ?? 'EUR',
        receiptPath: json[colReceiptPath] as String?,
        billable: json[colBillable] as bool? ?? true,
        billed: json[colBilled] as bool? ?? false,
        invoiceId: json[colInvoiceId] as String?,
        incurredAt: DateTime.parse(json[colIncurredAt] as String),
        status: json[colStatus] as String? ?? 'active',
        createdAt: json[colCreatedAt] != null
            ? DateTime.parse(json[colCreatedAt] as String)
            : null,
        updatedAt: json[colUpdatedAt] != null
            ? DateTime.parse(json[colUpdatedAt] as String)
            : null,
      );

  /// Per insert: non includo expense_id/created_at/updated_at (gestiti dal DB)
  Map<String, dynamic> toInsertJson() => {
        colFirmId: firmId,
        if (matterId != null) colMatterId: matterId,
        colUserId: userId,
        colType: type,
        colDescription: description,
        colAmount: amount,
        colCurrency: currency,
        if (receiptPath != null) colReceiptPath: receiptPath,
        colBillable: billable,
        colBilled: billed,
        if (invoiceId != null) colInvoiceId: invoiceId,
        colIncurredAt: incurredAt.toIso8601String().split('T')[0], // solo data
        colStatus: status,
      };

  /// Per update: includo solo i campi modificabili
  Map<String, dynamic> toUpdateJson() => {
        if (matterId != null) colMatterId: matterId,
        colType: type,
        colDescription: description,
        colAmount: amount,
        colCurrency: currency,
        if (receiptPath != null) colReceiptPath: receiptPath,
        colBillable: billable,
        colBilled: billed,
        if (invoiceId != null) colInvoiceId: invoiceId,
        colIncurredAt: incurredAt.toIso8601String().split('T')[0],
        colStatus: status,
      };

  Expense copyWith({
    String? expenseId,
    String? firmId,
    String? matterId,
    String? userId,
    String? type,
    String? description,
    double? amount,
    String? currency,
    String? receiptPath,
    bool? billable,
    bool? billed,
    String? invoiceId,
    DateTime? incurredAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Expense(
        expenseId: expenseId ?? this.expenseId,
        firmId: firmId ?? this.firmId,
        matterId: matterId ?? this.matterId,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        receiptPath: receiptPath ?? this.receiptPath,
        billable: billable ?? this.billable,
        billed: billed ?? this.billed,
        invoiceId: invoiceId ?? this.invoiceId,
        incurredAt: incurredAt ?? this.incurredAt,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  // Getters utili
  bool get isBillable => billable && !billed;
  bool get isActive => status == 'active';
  bool get hasReceipt => receiptPath != null && receiptPath!.isNotEmpty;
  String get displayType {
    switch (type) {
      case 'court_fee': return 'Spese processuali';
      case 'postage': return 'Spese postali';
      case 'expert': return 'Consulenze';
      case 'travel': return 'Trasferte';
      case 'other': return 'Altre spese';
      default: return type;
    }
  }
  
  @override
  String toString() => 'Expense(id: $expenseId, type: $type, amount: $amount $currency, billable: $billable)';
}