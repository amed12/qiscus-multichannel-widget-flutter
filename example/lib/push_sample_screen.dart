import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multichannel_flutter_sample/push_diagnostic.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';

/// Contoh pendaftaran device token push yang benar, lengkap dengan diagnostic
/// per langkah.
///
/// Dipisahkan dari [LoginScreen] supaya bisa dijalankan sendiri tanpa
/// mengubah alur login yang sudah ada.
class PushSampleScreen extends ConsumerStatefulWidget {
  const PushSampleScreen({super.key});

  @override
  ConsumerState<PushSampleScreen> createState() => _PushSampleScreenState();
}

class _PushSampleScreenState extends ConsumerState<PushSampleScreen> {
  late final _appIdController = TextEditingController(text: placeholderAppId);
  late final _channelIdController =
      TextEditingController(text: placeholderChannelId);
  late final _userIdController = TextEditingController(text: 'push-test-001');

  var _steps = <DiagnosticStep>[];
  String? _fcmToken;
  bool _running = false;

  /// Log pesan yang benar-benar diterima app (bukan cuma "server bilang
  /// sukses kirim"). Ini yang membuktikan apakah payload dari server berisi
  /// blok `notification` (alert, auto tampil sebagai banner oleh iOS) atau
  /// data-only (perlu app aktif untuk menampilkannya — data-only TIDAK akan
  /// muncul sebagai banner otomatis kalau app di-background/killed).
  final _receivedLog = <String>[];
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;

  @override
  void initState() {
    super.initState();

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      setState(() => _receivedLog.add(_describeMessage('foreground', message)));
    });
    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      setState(
        () => _receivedLog.add(_describeMessage('dibuka dari background', message)),
      );
    });
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        setState(
          () => _receivedLog.add(_describeMessage('dibuka dari killed', message)),
        );
      }
    });
  }

  String _describeMessage(String context, RemoteMessage message) {
    var time = DateTime.now().toIso8601String().substring(11, 19);
    var notif = message.notification;
    var payloadType = notif == null
        ? 'DATA-ONLY (tidak ada blok notification!)'
        : 'notification (title: "${notif.title}", body: "${notif.body}")';
    return '[$time] ($context) messageId=${message.messageId} · payload=$payloadType · data=${message.data}';
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _channelIdController.dispose();
    _userIdController.dispose();
    _onMessageSub?.cancel();
    _onOpenedAppSub?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _steps = [];
      _fcmToken = null;
    });

    var report = await PushDiagnostic(
      appId: _appIdController.text.trim(),
      channelId: _channelIdController.text.trim(),
    ).run();

    setState(() {
      _steps = [...report.steps];
      _fcmToken = report.fcmToken;
    });

    // Kalau token sudah didapat, lanjut ke bagian yang benar-benar
    // mengirimkannya ke server Qiscus.
    if (report.fcmToken != null) {
      await _registerToQiscus(report.fcmToken!);
    }

    setState(() => _running = false);
  }

  /// `setDeviceId()` hanya MENYIMPAN token di memori widget. Yang benar-benar
  /// mengirimnya ke `set_user_device_token` adalah `initiateChat()`.
  ///
  /// Jadi kalau `initiateChat()` tidak pernah sukses, device tidak akan pernah
  /// terdaftar di server — walau `setDeviceId()` sudah dipanggil dengan token
  /// yang valid.
  Future<void> _registerToQiscus(String token) async {
    var mc = ref.read(QMultichannel.provider);
    var channelId = _channelIdController.text.trim();

    // Dijaga di sini juga: channel_id bersifat opsional di request, jadi kalau
    // kosong ia hilang tanpa error sama sekali.
    if (channelId.isEmpty || channelId == placeholderChannelId) {
      setState(() {
        _steps = [
          ..._steps,
          DiagnosticStep(
            'Channel ID terisi',
            StepStatus.fail,
            'channelId: "$channelId"',
            hint: 'initiateChat() tidak dijalankan. channel_id wajib diisi — '
                'di request ia opsional, jadi kalau kosong ia hilang diam-diam '
                'dan room tidak menempel ke channel mana pun.',
          ),
        ];
      });
      return;
    }

    mc.setChannelId(channelId);
    mc.setUser(
      userId: _userIdController.text.trim(),
      displayName: _userIdController.text.trim(),
    );
    mc.setDeviceId(token, isDevelopment: kDebugMode);

    setState(() {
      _steps = [
        ..._steps,
        DiagnosticStep(
          'setDeviceId() dipanggil',
          StepStatus.ok,
          'isDevelopment: $kDebugMode — nilai ini harus mengikuti tipe build',
        ),
      ];
    });

    try {
      var room = await mc.initiateChat();

      setState(() {
        _steps = [
          ..._steps,
          DiagnosticStep(
            'initiateChat() sukses — token dikirim ke server',
            StepStatus.ok,
            'roomId: ${room.id} · channelId: $channelId',
          ),
        ];
      });
    } catch (e) {
      setState(() {
        _steps = [
          ..._steps,
          DiagnosticStep(
            'initiateChat() sukses — token dikirim ke server',
            StepStatus.fail,
            'error: $e',
            hint: 'Selama initiateChat() gagal, token TIDAK pernah dikirim ke '
                'server walau setDeviceId() sudah dipanggil. Cek App ID, '
                'Channel ID ($channelId), dan koneksi ke server.',
          ),
        ];
      });
    }
  }

  void _copyReport() {
    var report = DiagnosticReport(_steps, fcmToken: _fcmToken);
    var buffer = StringBuffer(report.asPlainText());

    buffer.writeln();
    buffer.writeln('=== Log pesan yang benar-benar diterima app ===');
    if (_receivedLog.isEmpty) {
      buffer.writeln(
        '(kosong — belum ada pesan yang tercatat sampai ke app selama ini '
        'terbuka di foreground. Kalau CS sudah membalas dan ini tetap kosong, '
        'berarti pesan tidak sampai ke listener onMessage sama sekali.)',
      );
    } else {
      for (var line in _receivedLog) {
        buffer.writeln(line);
      }
    }
    buffer.writeln(
      '(catatan: pesan yang diterima app SAAT BACKGROUND tidak tercatat di '
      'sini — cek console Xcode/`flutter logs` untuk baris "[push][background]" '
      'saat pengujian, dan salin baris itu juga.)',
    );

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hasil disalin — tempelkan ke tiket')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push notification — diagnostic')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Menjalankan urutan pendaftaran device token yang benar, lalu '
              'melaporkan langkah mana yang gagal.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appIdController,
              decoration: const InputDecoration(labelText: 'App ID'),
            ),
            TextField(
              controller: _channelIdController,
              decoration: const InputDecoration(
                labelText: 'Channel ID (wajib)',
              ),
            ),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Menjalankan…' : 'Jalankan diagnostic'),
            ),
            const SizedBox(height: 20),
            for (var step in _steps) _StepTile(step: step),
            if (_steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyReport,
                icon: const Icon(Icons.copy),
                label: const Text('Salin hasil'),
              ),
            ],
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Log pesan yang benar-benar diterima app (foreground). '
              'Kirim CS balasan sekarang lalu lihat baris muncul di sini — '
              'kalau payload "DATA-ONLY", itu alasan notifikasi tidak tampil '
              'otomatis saat app di background/killed.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (_receivedLog.isEmpty)
              const Text(
                '(belum ada pesan tercatat)',
                style: TextStyle(color: Colors.grey),
              )
            else
              for (var line in _receivedLog)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SelectableText(
                    line,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final DiagnosticStep step;

  @override
  Widget build(BuildContext context) {
    var color = switch (step.status) {
      StepStatus.ok => Colors.green.shade700,
      StepStatus.warn => Colors.orange.shade800,
      StepStatus.fail => Colors.red.shade700,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.marker,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: SelectableText(
              step.detail,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
          if (step.status != StepStatus.ok && step.hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Text(
                step.hint!,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
        ],
      ),
    );
  }
}
