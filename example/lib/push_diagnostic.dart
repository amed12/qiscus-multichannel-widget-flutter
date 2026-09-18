import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Nilai bawaan milik project contoh Qiscus. Kalau sample dijalankan dengan
/// nilai-nilai ini, device akan terdaftar ke App ID dan project Firebase
/// Qiscus — bukan milik Anda — sehingga hasil tesnya tidak bisa dipakai.
const qiscusDemoAppId = 'wefds-c6f0p2h1cxwz3oq';
const qiscusDemoFirebaseProjectId = 'flutter-multichannel-sam-4c9c1';

/// Nilai isian yang harus diganti sebelum sample dipakai.
const placeholderAppId = 'your_app_id';
const placeholderChannelId = 'your_channel_id';

enum StepStatus { ok, warn, fail }

class DiagnosticStep {
  DiagnosticStep(this.title, this.status, this.detail, {this.hint});

  final String title;
  final StepStatus status;
  final String detail;

  /// Apa yang harus dilakukan kalau langkah ini tidak lolos.
  final String? hint;

  String get marker => switch (status) {
        StepStatus.ok => '[OK]',
        StepStatus.warn => '[!]',
        StepStatus.fail => '[GAGAL]',
      };
}

class DiagnosticReport {
  DiagnosticReport(this.steps, {this.fcmToken, this.apnsToken});

  final List<DiagnosticStep> steps;
  final String? fcmToken;
  final String? apnsToken;

  bool get hasFailure => steps.any((s) => s.status == StepStatus.fail);

  /// Teks siap tempel untuk dikirim balik ke tim support.
  String asPlainText() {
    var buffer = StringBuffer()
      ..writeln('=== Qiscus push notification diagnostic ===')
      ..writeln('platform: ${Platform.operatingSystem}')
      ..writeln('mode: ${kDebugMode ? 'debug' : 'release'}')
      ..writeln('');

    for (var step in steps) {
      buffer.writeln('${step.marker} ${step.title}');
      buffer.writeln('     ${step.detail}');
      if (step.status != StepStatus.ok && step.hint != null) {
        buffer.writeln('     -> ${step.hint}');
      }
    }

    return buffer.toString();
  }
}

/// Menjalankan urutan yang benar untuk mendaftarkan device token push, sambil
/// mencatat hasil tiap langkah.
///
/// Urutannya penting, terutama di iOS:
///
/// 1. `requestPermission()` lebih dulu — sebelum pengguna menyetujui izin
///    notifikasi, iOS belum menerbitkan APNs token.
/// 2. `getAPNSToken()` — tanpa ini, `getToken()` di iOS bisa mengembalikan
///    `null` walau izin sudah disetujui.
/// 3. `getToken()` baru dipanggil terakhir.
///
/// Memanggil `getToken()` lebih dulu (pola yang sempat dicontohkan di
/// `login_screen.dart`) membuat token `null` di iOS tanpa error yang terlihat,
/// sehingga `setDeviceId()` tidak pernah menerima token apa pun.
class PushDiagnostic {
  PushDiagnostic({
    required this.appId,
    required this.channelId,
    this.apnsRetries = 5,
    this.apnsRetryDelay = const Duration(seconds: 1),
  });

  final String appId;

  /// Wajib diisi. `channel_id` bersifat opsional di request `initiate_chat`,
  /// jadi kalau kosong ia hilang tanpa error dan room yang terbentuk tidak
  /// menempel ke channel mana pun — gejalanya mirip "push tidak sampai".
  final String channelId;
  final int apnsRetries;
  final Duration apnsRetryDelay;

  Future<DiagnosticReport> run() async {
    var steps = <DiagnosticStep>[];
    String? apnsToken;
    String? fcmToken;

    steps.add(_checkFirebaseApp());

    var config = _checkConfigIsYours();
    steps.add(config);
    if (config.status == StepStatus.fail) {
      return DiagnosticReport(steps);
    }

    var permission = await _requestPermission();
    steps.add(permission.step);
    if (permission.blocked) {
      return DiagnosticReport(steps);
    }

    if (Platform.isIOS || Platform.isMacOS) {
      var apns = await _fetchApnsToken();
      apnsToken = apns.token;
      steps.add(apns.step);
      if (apns.token == null) {
        return DiagnosticReport(steps, apnsToken: null);
      }
    }

    var fcm = await _fetchFcmToken();
    fcmToken = fcm.token;
    steps.add(fcm.step);

    return DiagnosticReport(steps, fcmToken: fcmToken, apnsToken: apnsToken);
  }

  DiagnosticStep _checkFirebaseApp() {
    if (Firebase.apps.isEmpty) {
      return DiagnosticStep(
        'Firebase ter-inisialisasi',
        StepStatus.fail,
        'Firebase.apps kosong',
        hint: 'Pastikan `await Firebase.initializeApp(...)` dipanggil dan '
            'DITUNGGU di main() sebelum runApp().',
      );
    }

    var options = Firebase.app().options;
    return DiagnosticStep(
      'Firebase ter-inisialisasi',
      StepStatus.ok,
      'projectId: ${options.projectId} · '
          'messagingSenderId: ${options.messagingSenderId}',
    );
  }

  DiagnosticStep _checkConfigIsYours() {
    var projectId =
        Firebase.apps.isEmpty ? null : Firebase.app().options.projectId;

    var problems = <String>[
      if (appId.isEmpty || appId == placeholderAppId)
        'App ID belum diisi (masih "$placeholderAppId")',
      if (appId == qiscusDemoAppId)
        'App ID masih milik contoh Qiscus ($appId)',
      if (channelId.isEmpty || channelId == placeholderChannelId)
        'Channel ID belum diisi (masih "$placeholderChannelId")',
      if (projectId == qiscusDemoFirebaseProjectId)
        'project Firebase masih milik contoh Qiscus ($projectId)',
    ];

    if (problems.isNotEmpty) {
      return DiagnosticStep(
        'Konfigurasi menunjuk ke lingkungan Anda sendiri',
        StepStatus.fail,
        problems.join('; '),
        hint: 'Isi sesuai PUSH_NOTIFICATION.md. Selama masih memakai nilai '
            'isian atau nilai contoh Qiscus, device terdaftar ke lingkungan '
            'yang salah dan hasil tes ini tidak bisa dipakai menilai apa pun.',
      );
    }

    return DiagnosticStep(
      'Konfigurasi menunjuk ke lingkungan Anda sendiri',
      StepStatus.ok,
      'appId: $appId · channelId: $channelId · projectId: $projectId',
    );
  }

  Future<({DiagnosticStep step, bool blocked})> _requestPermission() async {
    var settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    var status = settings.authorizationStatus;
    var granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    if (granted) {
      return (
        step: DiagnosticStep(
          'Izin notifikasi disetujui',
          StepStatus.ok,
          'authorizationStatus: $status',
        ),
        blocked: false,
      );
    }

    return (
      step: DiagnosticStep(
        'Izin notifikasi disetujui',
        StepStatus.fail,
        'authorizationStatus: $status',
        hint: status == AuthorizationStatus.denied
            ? 'Izin ditolak. Buka Settings perangkat, aktifkan notifikasi '
                'untuk aplikasi ini, lalu jalankan ulang tes. Selama ditolak, '
                'iOS tidak akan menerbitkan APNs token.'
            : 'Izin belum ditentukan. Setujui dialog izin yang muncul.',
      ),
      blocked: true,
    );
  }

  Future<({DiagnosticStep step, String? token})> _fetchApnsToken() async {
    String? token;

    for (var attempt = 1; attempt <= apnsRetries; attempt++) {
      token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null) {
        return (
          step: DiagnosticStep(
            'APNs token tersedia (iOS)',
            StepStatus.ok,
            'didapat pada percobaan ke-$attempt: ${_mask(token)}',
          ),
          token: token,
        );
      }
      await Future<void>.delayed(apnsRetryDelay);
    }

    return (
      step: DiagnosticStep(
        'APNs token tersedia (iOS)',
        StepStatus.fail,
        'null setelah $apnsRetries percobaan',
        hint: 'Tanpa APNs token, getToken() akan mengembalikan null. '
            'Cek: capability Push Notifications aktif di Xcode, APNs Auth Key '
            'sudah diunggah ke Firebase Console, dan aplikasi dijalankan di '
            'perangkat fisik (Simulator tidak menerbitkan APNs token).',
      ),
      token: null,
    );
  }

  Future<({DiagnosticStep step, String? token})> _fetchFcmToken() async {
    try {
      var token = await FirebaseMessaging.instance.getToken();

      if (token == null) {
        return (
          step: DiagnosticStep(
            'FCM token didapat',
            StepStatus.fail,
            'null',
            hint: 'Firebase tidak menerbitkan token. Pastikan '
                'google-services.json / GoogleService-Info.plist yang dipakai '
                'memang milik project Firebase Anda, dan bundle id aplikasi '
                'terdaftar di project tersebut.',
          ),
          token: null,
        );
      }

      return (
        step: DiagnosticStep(
          'FCM token didapat',
          StepStatus.ok,
          _mask(token),
        ),
        token: token,
      );
    } catch (e) {
      return (
        step: DiagnosticStep(
          'FCM token didapat',
          StepStatus.fail,
          'error: $e',
          hint: 'Ini error yang pada pola lama tertelan di catchError dan '
              'hanya di-print, sehingga setDeviceId() tidak pernah terpanggil.',
        ),
        token: null,
      );
    }
  }

  static String _mask(String token) {
    if (token.length <= 24) return token;
    return '${token.substring(0, 12)}…${token.substring(token.length - 8)} '
        '(${token.length} karakter)';
  }
}
