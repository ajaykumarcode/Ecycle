class AdminStatsModel {
  final int totalUsers;
  final int totalAgents;
  final int totalPickups;
  final int pendingPickups;
  final int assignedPickups;
  final int collectedPickups;
  final int recycledPickups;
  final int cancelledPickups;
  final double totalEstimatedWeightKg;
  final double totalRecycledWeightKg;

  const AdminStatsModel({
    required this.totalUsers,
    required this.totalAgents,
    required this.totalPickups,
    required this.pendingPickups,
    required this.assignedPickups,
    required this.collectedPickups,
    required this.recycledPickups,
    required this.cancelledPickups,
    required this.totalEstimatedWeightKg,
    required this.totalRecycledWeightKg,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      totalAgents: (json['totalAgents'] as num?)?.toInt() ?? 0,
      totalPickups: (json['totalPickups'] as num?)?.toInt() ?? 0,
      pendingPickups: (json['pendingPickups'] as num?)?.toInt() ?? 0,
      assignedPickups: (json['assignedPickups'] as num?)?.toInt() ?? 0,
      collectedPickups: (json['collectedPickups'] as num?)?.toInt() ?? 0,
      recycledPickups: (json['recycledPickups'] as num?)?.toInt() ?? 0,
      cancelledPickups: (json['cancelledPickups'] as num?)?.toInt() ?? 0,
      totalEstimatedWeightKg:
          (json['totalEstimatedWeightKg'] as num?)?.toDouble() ?? 0.0,
      totalRecycledWeightKg:
          (json['totalRecycledWeightKg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminAgentModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isActive;
  final int assignedCount;
  final int collectedCount;
  final int recycledCount;

  const AdminAgentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.assignedCount,
    required this.collectedCount,
    required this.recycledCount,
  });

  factory AdminAgentModel.fromJson(Map<String, dynamic> json) {
    final workload = json['workload'] is Map ? json['workload'] as Map : {};

    return AdminAgentModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      isActive: json['isActive'] == true,
      assignedCount: (workload['assigned'] as num?)?.toInt() ?? 0,
      collectedCount: (workload['collected'] as num?)?.toInt() ?? 0,
      recycledCount: (workload['recycled'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminUserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int rewardPoints;
  final bool isActive;
  final int pickupCount;
  final DateTime createdAt;

  const AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.rewardPoints,
    required this.isActive,
    required this.pickupCount,
    required this.createdAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
      pickupCount: (json['pickupCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class CategoryMetric {
  final String category;
  final int count;
  final double weight;

  const CategoryMetric({
    required this.category,
    required this.count,
    required this.weight,
  });
}

class MonthlyTrend {
  final int year;
  final int month;
  final int count;
  final double weight;
  final int recycledCount;

  const MonthlyTrend({
    required this.year,
    required this.month,
    required this.count,
    required this.weight,
    required this.recycledCount,
  });
}

class AgentRank {
  final String id;
  final String name;
  final String email;
  final int assignedCount;
  final int collectedCount;
  final int recycledCount;

  const AgentRank({
    required this.id,
    required this.name,
    required this.email,
    required this.assignedCount,
    required this.collectedCount,
    required this.recycledCount,
  });
}

class AdminAnalyticsModel {
  final List<CategoryMetric> categories;
  final List<MonthlyTrend> monthlyTrends;
  final List<AgentRank> agentPerformance;
  final Map<String, int> statusBreakdown;

  const AdminAnalyticsModel({
    required this.categories,
    required this.monthlyTrends,
    required this.agentPerformance,
    required this.statusBreakdown,
  });

  factory AdminAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categoryDistribution'] as List? ?? [];
    final categories = rawCats.map((item) {
      final m = item as Map;
      return CategoryMetric(
        category: (m['_id'] ?? 'Other').toString(),
        count: (m['count'] as num?)?.toInt() ?? 0,
        weight: (m['weight'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final rawTrends = json['monthlyTrends'] as List? ?? [];
    final trends = rawTrends.map((item) {
      final m = item as Map;
      final idObj = m['_id'] as Map? ?? {};
      return MonthlyTrend(
        year: (idObj['year'] as num?)?.toInt() ?? 2026,
        month: (idObj['month'] as num?)?.toInt() ?? 1,
        count: (m['count'] as num?)?.toInt() ?? 0,
        weight: (m['weight'] as num?)?.toDouble() ?? 0.0,
        recycledCount: (m['recycledCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final rawAgents = json['agentPerformance'] as List? ?? [];
    final agents = rawAgents.map((item) {
      final m = item as Map;
      return AgentRank(
        id: (m['_id'] ?? '').toString(),
        name: (m['name'] ?? 'Agent').toString(),
        email: (m['email'] ?? '').toString(),
        assignedCount: (m['assignedCount'] as num?)?.toInt() ?? 0,
        collectedCount: (m['collectedCount'] as num?)?.toInt() ?? 0,
        recycledCount: (m['recycledCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final rawStatus = json['statusBreakdown'] as List? ?? [];
    final statusMap = <String, int>{};
    for (final item in rawStatus) {
      final m = item as Map;
      statusMap[(m['_id'] ?? '').toString()] =
          (m['count'] as num?)?.toInt() ?? 0;
    }

    return AdminAnalyticsModel(
      categories: categories,
      monthlyTrends: trends,
      agentPerformance: agents,
      statusBreakdown: statusMap,
    );
  }
}
