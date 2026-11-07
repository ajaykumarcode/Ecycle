class ApiConfig {
  // Flutter Web running in Chrome on the same computer.
  static const String baseUrl = 'http://localhost:5051/api';

  // Auth endpoints
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String profile = '$baseUrl/auth/me';
  static const String updateProfile = '$baseUrl/auth/profile';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String userRewards = '$baseUrl/auth/rewards';

  // Pickup endpoints
  static const String pickups = '$baseUrl/pickups';
  static const String myPickups = '$baseUrl/pickups/my';

  // Agent endpoints
  static const String agentPickups = '$baseUrl/agent/pickups';

  // Admin endpoints
  static const String adminStats = '$baseUrl/admin/stats';
  static const String adminPickups = '$baseUrl/admin/pickups';
  static const String adminAgents = '$baseUrl/admin/agents';
  static const String adminUsers = '$baseUrl/admin/users';
  static const String adminAnalytics = '$baseUrl/admin/analytics';
}
