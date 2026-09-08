part of 'provider.dart';

@riverpod
FlutterSecureStorage encSharedPreference(EncSharedPreferenceRef _) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      dataStore: true,
    ),
  );
}

class StorageKey {
  // static const secureSession = 'SECURE_SESSION_DATA';
  static String getSecureSessionKey({
    required String appId,
    String? channelId = 'unknown_channel_id',
    String? userId = 'unknown_user_id',
  }) =>
      'Qiscus_Key:$appId:$channelId:$userId';
}
