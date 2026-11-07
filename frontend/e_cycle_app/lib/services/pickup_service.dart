import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/pickup_model.dart';

class PickupService {
  Future<List<PickupModel>> getMyPickups(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pickups/my'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Could not load pickups.');
    }

    if (data['success'] != true || data['pickups'] is! List) {
      throw Exception(data['message'] ?? 'Invalid pickup response.');
    }

    return (data['pickups'] as List)
        .map(
          (item) =>
              PickupModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> createPickup({
    required String token,
    required String category,
    required String description,
    required int quantity,
    required double estimatedWeightKg,
    required String pickupAddress,
    required String scheduledDate,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pickups'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'category': category,
        'description': description,
        'quantity': quantity,
        'estimatedWeightKg': estimatedWeightKg,
        'pickupAddress': pickupAddress,
        'scheduledDate': scheduledDate,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not schedule pickup.');
    }
  }

  Future<void> cancelPickup({
    required String token,
    required String pickupId,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/pickups/$pickupId/cancel'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw Exception(data['message'] ?? 'Could not cancel pickup.');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'message': 'Unexpected response from server.'};
    } on FormatException {
      return {'message': 'Server returned an invalid response.'};
    }
  }
}
