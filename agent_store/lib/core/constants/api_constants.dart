class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiV1      = '$baseUrl/api/v1';
  static const String agents     = '$apiV1/agents';
  static const String authNonce   = '$apiV1/auth/nonce';
  static const String authVerify  = '$apiV1/auth/verify';
  // Frontend → backend "I dropped the signing request" hint so the stored
  // nonce can be invalidated even when no verify call ever happens (user
  // closed the popup, MetaMask threw, signature timed out, etc.).
  static const String authAbandon = '$apiV1/auth/abandon';
  static const String userLibrary = '$apiV1/user/library';
  static const String userCredits = '$apiV1/user/credits';
  static const String userProfile = '$apiV1/user/profile';
  static const String userMissions = '$apiV1/user/missions';
  static const String userMissionsSync = '$apiV1/user/missions/sync';
  static const String userLegendWorkflows = '$apiV1/user/legend/workflows';
  static const String userLegendWorkflowsSync = '$apiV1/user/legend/workflows/sync';
  static const String userLegendExecutions = '$apiV1/user/legend/executions';
  static const String guilds            = '$apiV1/guilds';
  static const String userCreditHistory = '$apiV1/user/credits/history';
  static const String leaderboard       = '$apiV1/leaderboard';
  static const String guildMaster       = '$apiV1/guild-master';
  static const String agentCategories  = '$agents/categories';
  static const String agentsForYou     = '$agents/for-you';
  static const String users            = '$apiV1/users';
}
