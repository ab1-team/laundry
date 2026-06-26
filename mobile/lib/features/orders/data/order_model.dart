import '../../../core/widgets/order_summary_card.dart' show OrderItemLike;

/// Customer summary embedded in OrderResource.
class CustomerMini {
  CustomerMini({required this.id, required this.name, this.phone});
  final int id;
  final String name;
  final String? phone;

  factory CustomerMini.fromJson(Map<String, dynamic> j) => CustomerMini(
        id: j['id'] as int,
        name: j['name'] as String,
        phone: j['phone'] as String?,
      );
}

class OrderItemModel implements OrderItemLike {
  OrderItemModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.unit,
    required this.price,
    required this.qty,
    required this.subtotal,
    this.categoryIcon,
  });

  final int id;
  final int serviceId;
  @override
  final String serviceName;
  @override
  final String unit;
  final double price;
  @override
  final double qty;
  final double subtotal;
  @override
  final String? categoryIcon;

  factory OrderItemModel.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    // Backend Eloquent `decimal:2` casts ship these fields as strings
    // ("7000.00"); accept num OR string so old payloads still parse.
    double asDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    return OrderItemModel(
      id: j['id'] as int,
      serviceId: j['service_id'] as int,
      serviceName: j['service_name'] as String,
      unit: j['unit'] as String,
      price: asDouble(j['price']),
      qty: asDouble(j['qty']),
      subtotal: asDouble(j['subtotal']),
      categoryIcon: cat is Map ? cat['icon'] as String? : null,
    );
  }
}

class OrderStatusLogModel {
  OrderStatusLogModel({
    required this.id,
    required this.status,
    required this.changedBy,
    this.changedByName,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String status;
  final int? changedBy;
  final String? changedByName;
  final DateTime createdAt;
  final String? note;

  factory OrderStatusLogModel.fromJson(Map<String, dynamic> j) => OrderStatusLogModel(
        id: j['id'] as int,
        status: j['status'] as String,
        changedBy: j['changed_by'] as int?,
        changedByName: j['changed_by_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        note: j['note'] as String?,
      );
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.createdAt,
    this.notes,
    this.items = const [],
    this.statusLogs = const [],
    this.estimatedFinishAt,
    this.finishedAt,
    this.pickedUpAt,
    this.cancelledAt,
    this.cancelReason,
    this.totalPaid = 0,
    this.remaining = 0,
  });

  final int id;
  final String ticketNumber;
  final int customerId;
  final String? customerName;
  final String? customerPhone;
  final String status;
  final double subtotal;
  final double discount;
  final double total;
  final DateTime createdAt;
  final String? notes;
  final List<OrderItemModel> items;
  final List<OrderStatusLogModel> statusLogs;
  final DateTime? estimatedFinishAt;
  final DateTime? finishedAt;
  final DateTime? pickedUpAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final double totalPaid;
  final double remaining;

  factory OrderModel.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cust = j['customer'];
    final logs = (j['status_logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // `decimal:2` columns on Order/OrderItem ship as strings from
    // Eloquent. Accept num OR string here so cast never throws.
    double asDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    return OrderModel(
      id: j['id'] as int,
      ticketNumber: j['ticket_number'] as String,
      customerId: j['customer_id'] as int,
      customerName: cust is Map ? cust['name'] as String? : null,
      customerPhone: cust is Map ? cust['phone'] as String? : null,
      status: j['status'] as String,
      subtotal: asDouble(j['subtotal']),
      discount: asDouble(j['discount']),
      total: asDouble(j['total']),
      createdAt: DateTime.parse(j['created_at'] as String),
      notes: j['notes'] as String?,
      items: items.map(OrderItemModel.fromJson).toList(),
      statusLogs: logs.map(OrderStatusLogModel.fromJson).toList(),
      estimatedFinishAt: j['estimated_finish_at'] != null
          ? DateTime.tryParse(j['estimated_finish_at'] as String)
          : null,
      finishedAt: j['finished_at'] != null ? DateTime.tryParse(j['finished_at'] as String) : null,
      pickedUpAt: j['picked_up_at'] != null ? DateTime.tryParse(j['picked_up_at'] as String) : null,
      cancelledAt: j['cancelled_at'] != null ? DateTime.tryParse(j['cancelled_at'] as String) : null,
      cancelReason: j['cancel_reason'] as String?,
      totalPaid: asDouble(j['total_paid']),
      remaining: asDouble(j['remaining']),
    );
  }
}
