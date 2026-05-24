class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String wsUrl = 'ws://10.0.2.2:8000';
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
  static const int syncIntervalSeconds = 30;
  static const int maxRetryCount = 5;
  static const int dbVersion = 1;
  static const String dbName = 'stoqo.db';
}
