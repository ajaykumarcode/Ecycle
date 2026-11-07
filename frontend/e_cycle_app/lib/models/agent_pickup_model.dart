class AgentPickupModel {
  final String id;
  final String category;
  final String description;
  final int quantity;
  final double estimatedWeightKg;
  final String pickupAddress;
  final DateTime scheduledDate;
  final String status;
  final String requesterName;
  final String requesterPhone;
  final String requesterEmail;
  final double? latitude;
  final double? longitude;
  final DateTime? assignedAt;
  final DateTime? collectedAt;
  final DateTime? recycledAt;

  const AgentPickupModel({
    required this.id,
    required this.category,
    required this.description,
    required this.quantity,
    required this.estimatedWeightKg,
    required this.pickupAddress,
    required this.scheduledDate,
    required this.status,
    required this.requesterName,
    required this.requesterPhone,
    required this.requesterEmail,
    this.latitude,
    this.longitude,
    this.assignedAt,
    this.collectedAt,
    this.recycledAt,
  });

  factory AgentPickupModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final coords = json['coordinates'] is Map
        ? json['coordinates'] as Map
        : null;

    return AgentPickupModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      category: (json['category'] ?? 'Other Electronics').toString(),
      description: (json['description'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      estimatedWeightKg: (json['estimatedWeightKg'] as num?)?.toDouble() ?? 0,
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      scheduledDate:
          DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ??
          DateTime.now(),
      status: (json['status'] ?? 'assigned').toString(),
      requesterName: (user['name'] ?? 'E-Cycle user').toString(),
      requesterPhone: (user['phone'] ?? '').toString(),
      requesterEmail: (user['email'] ?? '').toString(),
      latitude: (coords?['lat'] as num?)?.toDouble(),
      longitude: (coords?['lng'] as num?)?.toDouble(),
      assignedAt: DateTime.tryParse(json['assignedAt']?.toString() ?? ''),
      collectedAt: DateTime.tryParse(json['collectedAt']?.toString() ?? ''),
      recycledAt: DateTime.tryParse(json['recycledAt']?.toString() ?? ''),
    );
  }
}
