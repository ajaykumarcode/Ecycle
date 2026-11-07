import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthResult {
  final String token;
  final UserModel user;

  const AuthResult({required this.token, required this.user});
}

class RewardItem {
  final String id;
  final int points;
  final String description;
  final DateTime createdAt;
  final String category;
  final int quantity;
  final double weight;

  const RewardItem({
    required this.id,
    required this.points,
    required this.description,
    required this.createdAt,
    required this.category,
    required this.quantity,
    required this.weight,
  });
}

class UserRewardsData {
  final int totalPoints;
  final List<RewardItem> history;

  const UserRewardsData({required this.totalPoints, required this.history});
}

class AuthService {
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    return _sendAuthRequest(ApiConfig.register, {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
    });
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return _sendAuthRequest(ApiConfig.login, {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<UserModel> updateProfile({
    required String token,
    required String name,
    required String phone,
  }) async {
    final response = await http.put(
      Uri.parse(ApiConfig.updateProfile),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name.trim(), 'phone': phone.trim()}),
    );

    final dynamic decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] == true) {
      return UserModel.fromJson(decoded['user'] as Map<String, dynamic>);
    }

    throw Exception(decoded['message'] ?? 'Could not update profile.');
  }

  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.changePassword),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] == true) {
      return;
    }

    throw Exception(decoded['message'] ?? 'Could not change password.');
  }

  Future<UserRewardsData> getRewards(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.userRewards),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final dynamic decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] == true) {
      final totalPoints = (decoded['totalPoints'] as num?)?.toInt() ?? 0;
      final rawList = decoded['history'] as List? ?? [];
      final list = rawList.map((item) {
        final m = item as Map<String, dynamic>;
        final pickup = m['pickup'] is Map ? m['pickup'] as Map : {};
        return RewardItem(
          id: (m['_id'] ?? '').toString(),
          points: (m['points'] as num?)?.toInt() ?? 0,
          description: (m['description'] ?? '').toString(),
          createdAt:
              DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          category: (pickup['category'] ?? 'E-Waste').toString(),
          quantity: (pickup['quantity'] as num?)?.toInt() ?? 1,
          weight: (pickup['estimatedWeightKg'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      return UserRewardsData(totalPoints: totalPoints, history: list);
    }

    throw Exception(decoded['message'] ?? 'Could not retrieve reward history.');
  }

  Future<AuthResult> _sendAuthRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response from the server.');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        final userJson = decoded['user'];

        if (decoded['token'] is! String || userJson is! Map<String, dynamic>) {
          throw Exception('The server returned an incomplete login response.');
        }

        return AuthResult(
          token: decoded['token'] as String,
          user: UserModel.fromJson(userJson),
        );
      }

      throw Exception(
        decoded['message']?.toString() ??
            'Request failed (${response.statusCode}).',
      );
    } on http.ClientException {
      throw Exception(
        'Could not connect to E-Cycle. Check your backend and network.',
      );
    } on FormatException {
      throw Exception('The server returned an invalid response.');
    } on Exception catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw Exception('The server took too long to respond. Try again.');
      }
      rethrow;
    }
  }
}
