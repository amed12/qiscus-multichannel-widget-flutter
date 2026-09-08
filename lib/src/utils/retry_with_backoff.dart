/// Menjalankan [action] dengan retry + exponential backoff kalau gagal
/// (termasuk timeout, kalau [timeout] di-set).
///
/// - Retry maksimal [maxRetries] kali (percobaan pertama tidak dihitung
///   sebagai retry, jadi total percobaan = 1 + [maxRetries]).
/// - Delay antar retry: [baseDelay] * (percobaan-ke berapa), jadi delay-nya
///   naik linear terhadap jumlah percobaan (mis. baseDelay 500ms -> 500ms,
///   1000ms, 1500ms, ...).
/// - Kalau [timeout] di-set, setiap percobaan dibatasi durasi tersebut lewat
///   `Future.timeout`, dan `TimeoutException` diperlakukan sama seperti
///   error lain (ikut retry).
/// - Setelah retry habis dan tetap gagal, melempar [RetryExhaustedException]
///   yang membungkus error asli dari percobaan terakhir.
///
/// Contoh:
/// ```dart
/// var room = await retryWithBackoff(
///   () => qiscus.getChatRoomWithMessages(roomId: roomId),
///   timeout: const Duration(seconds: 2),
///   label: 'getChatRoomWithMessages(roomId: $roomId)',
/// );
/// ```
Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxRetries = 3,
  Duration baseDelay = const Duration(milliseconds: 500),
  Duration? timeout,
  String? label,
}) async {
  Object? lastError;

  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      var future = action();
      if (timeout != null) future = future.timeout(timeout);
      return await future;
    } catch (e) {
      lastError = e;
      if (attempt == maxRetries) break;
      await Future.delayed(baseDelay * (attempt + 1));
    }
  }

  throw RetryExhaustedException(
    label: label,
    attempts: maxRetries + 1,
    lastError: lastError,
  );
}

/// Dilempar oleh [retryWithBackoff] kalau semua percobaan (percobaan awal +
/// seluruh retry) tetap gagal.
class RetryExhaustedException implements Exception {
  RetryExhaustedException({
    required this.attempts,
    required this.lastError,
    this.label,
  });

  /// Nama opsional untuk operasi yang di-retry, memudahkan identifikasi di
  /// log/stack trace (mis. 'getChatRoomWithMessages(roomId: 123)').
  final String? label;

  /// Total percobaan yang dilakukan (percobaan awal + seluruh retry).
  final int attempts;

  /// Error dari percobaan terakhir.
  final Object? lastError;

  @override
  String toString() {
    var name = label != null ? ' for $label' : '';
    return 'RetryExhaustedException: failed after $attempts attempt(s)$name. '
        'Last error: $lastError';
  }
}
