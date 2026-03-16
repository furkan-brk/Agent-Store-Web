class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiV1      = '$baseUrl/api/v1';
  static const String agents     = '$apiV1/agents';
  static const String authNonce  = '$apiV1/auth/nonce';
  static const String authVerify = '$apiV1/auth/verify';
  static const String userLibrary = '$apiV1/user/library';
  static const String userCredits = '$apiV1/user/credits';
  static const String userProfile = '$apiV1/user/profile';
  static const String userMissions = '$apiV1/user/missions';
  static const String userLegendWorkflows = '$apiV1/user/legend/workflows';
  static const String guilds            = '$apiV1/guilds';
  static const String userCreditHistory = '$apiV1/user/credits/history';
  static const String leaderboard       = '$apiV1/leaderboard';
  static const String guildMaster       = '$apiV1/guild-master';
}
