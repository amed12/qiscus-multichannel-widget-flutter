import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:multichannel_flutter_sample/constant.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'login_screen.dart';

/// Dijalankan di isolate terpisah oleh sistem saat pesan FCM masuk sewaktu
/// app background/killed. Harus top-level (atau static) dan diberi anotasi
/// `vm:entry-point` supaya tidak dibuang tree-shaking di build release.
///
/// Handler ini TIDAK bisa mengubah UI (isolate terpisah) — fungsinya cuma
/// membuktikan pesan sungguh sampai ke app dan menunjukkan bentuk payload-nya
/// (ada blok `notification` atau data-only) lewat `flutter logs`/console Xcode.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '[push][background] messageId=${message.messageId} '
    'notification=${message.notification == null ? 'NULL (data-only)' : 'ADA (title: ${message.notification?.title})'} '
    'data=${message.data}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Harus ditunggu: FirebaseMessaging dipakai segera setelah aplikasi jalan,
  // dan memanggilnya sebelum inisialisasi selesai membuat token gagal terbit.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Wajib didaftarkan sebelum runApp() supaya pesan yang masuk saat app
  // background/killed tetap tercatat, bukan cuma saat app di foreground.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return QMultichannelProvider(
      appId: appId,
      title: 'Some custom title',
      // avatar: QAvatarConfig.editable('https://via.placeholder.com/200'),
      // rightAvatar: QAvatarConfig.enabled(),
      avatar: const QAvatarConfig.disabled(),
      rightAvatar: const QAvatarConfig.disabled(),
      hideEventUI: true,
      onURLTapped: (url) {
        var uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      },
      builder: (context) {
        return const MaterialApp(
          home: LoginScreen(),
        );
      },
    );
  }
}
