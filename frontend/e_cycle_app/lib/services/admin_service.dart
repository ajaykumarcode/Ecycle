import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/admin_models.dart';
import '../models/pickup_model.dart';

class AdminPickupsResult {
  final List<PickupModel> pickups;
  final int total;
  final int page;
  final int totalPages;

  const AdminPickupsResult({
    required this.pickups,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class AdminService {
  Future<AdminStatsModel> getStats(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.adminStats),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not load admin stats.');
    }

    final stats = data['stats'];
    if (stats is! Map<String, dynamic>) {
      throw Exception('Invalid stats payload.');
    }

    return AdminStatsModel.fromJson(stats);
  }

  Future<AdminPickupsResult> getAllPickups(
    String token, {
    String? status,
    String? category,
    String? search,
    int page = 1,
    int limit = 100,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['endDate'] = endDate;
    }

    final uri = Uri.parse(ApiConfig.adminPickups)
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not retrieve pickup requests.');
    }

    final rawList = data['pickups'] as List? ?? [];
    final pickups = rawList
        .map((e) => PickupModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return AdminPickupsResult(
      pickups: pickups,
      total: (data['total'] as num?)?.toInt() ?? pickups.length,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> assignPickup({
    required String token,
    required String pickupId,
    required String agentId,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.adminPickups}/$pickupId/assign'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'agentId': agentId}),
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not assign pickup.');
    }
  }

  Future<List<AdminAgentModel>> getAgents(
    String token, {
    bool activeOnly = false,
  }) async {
    final uri = Uri.parse(ApiConfig.adminAgents)
        .replace(queryParameters: {'activeOnly': activeOnly.toString()});

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(
        data['message'] ?? 'Could not retrieve collection agents.',
      );
    }

    final rawList = data['agents'] as List? ?? [];
    return rawList
        .map(
          (e) => AdminAgentModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> createAgent({
    required String token,
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminAgents),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'phone': phone.trim(),
      }),
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not create collection agent.');
    }
  }

  Future<List<AdminUserModel>> getUsers(String token, {String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse(ApiConfig.adminUsers)
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not retrieve users.');
    }

    final rawList = data['users'] as List? ?? [];
    return rawList
        .map(
          (e) => AdminUserModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> toggleUserStatus({
    required String token,
    required String userId,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.adminUsers}/$userId/toggle-status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not toggle user status.');
    }
  }

  Future<AdminAnalyticsModel> getAnalytics(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.adminAnalytics),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not load analytics.');
    }

    final analytics = data['analytics'];
    if (analytics is! Map<String, dynamic>) {
      throw Exception('Invalid analytics data.');
    }

    return AdminAnalyticsModel.fromJson(analytics);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
      return {'message': 'Unexpected response from server.'};
    } on FormatException {
      return {'message': 'Server returned an invalid response.'};
    }
  }
}
