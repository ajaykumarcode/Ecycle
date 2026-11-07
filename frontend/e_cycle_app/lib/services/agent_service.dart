import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/agent_pickup_model.dart';

class AgentService {
  Future<List<AgentPickupModel>> getAssignedPickups(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/agent/pickups'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not load assigned pickups.');
    }

    final rows = data['pickups'];
    if (rows is! List) {
      throw Exception('The server returned an invalid pickup list.');
    }

    return rows
        .map(
          (row) =>
              AgentPickupModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> updatePickupStatus({
    required String token,
    required String pickupId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/agent/pickups/$pickupId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    final data = _decode(response);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not update pickup status.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
      return {'message': 'Unexpected response from the server.'};
    } on FormatException {
      return {'message': 'The server returned an invalid response.'};
    }
  }
}
