class PickupModel {
  final String id;
  final String category;
  final String description;
  final int quantity;
  final double estimatedWeightKg;
  final String pickupAddress;
  final DateTime scheduledDate;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? assignedAgentName;
  final String? assignedAgentPhone;
  final DateTime? assignedAt;
  final DateTime? collectedAt;
  final DateTime? recycledAt;

  const PickupModel({
    required this.id,
    required this.category,
    required this.description,
    required this.quantity,
    required this.estimatedWeightKg,
    required this.pickupAddress,
    required this.scheduledDate,
    required this.status,
    this.latitude,
    this.longitude,
    this.assignedAgentName,
    this.assignedAgentPhone,
    this.assignedAt,
    this.collectedAt,
    this.recycledAt,
  });

  factory PickupModel.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] is Map
        ? json['coordinates'] as Map
        : null;
    final agent = json['assignedAgent'] is Map
        ? json['assignedAgent'] as Map
        : null;

    return PickupModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      category: (json['category'] ?? 'Other Electronics').toString(),
      description: (json['description'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      estimatedWeightKg: (json['estimatedWeightKg'] as num?)?.toDouble() ?? 0,
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      scheduledDate:
          DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ??
          DateTime.now(),
      status: (json['status'] ?? 'pending').toString(),
      latitude: (coords?['lat'] as num?)?.toDouble(),
      longitude: (coords?['lng'] as num?)?.toDouble(),
      assignedAgentName: agent?['name']?.toString(),
      assignedAgentPhone: agent?['phone']?.toString(),
      assignedAt: DateTime.tryParse(json['assignedAt']?.toString() ?? ''),
      collectedAt: DateTime.tryParse(json['collectedAt']?.toString() ?? ''),
      recycledAt: DateTime.tryParse(json['recycledAt']?.toString() ?? ''),
    );
  }
}
