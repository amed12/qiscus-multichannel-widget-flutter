import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';

// -----------------------------------------------------------------------------
// Demo: dua channel live chat dalam SATU aplikasi Flutter.
//
// Run:
//   flutter run -t lib/two_channels_screen.dart
//
// Yang dicontohkan:
//   1. Satu shared ProviderContainer (parent) dipakai oleh dua
//      QMultichannelProvider dengan channelId berbeda.
//   2. Setiap channel punya QiscusSDK instance sendiri (tidak berbagi
//      MQTT/realtime), dan secure session disimpan per
//      appId + channelId + userId — pindah-pindah channel tidak menimpa
//      session/room channel lain.
//   3. setUser() + initiateChat() dipanggil dari event handler tombol,
//      BUKAN di dalam builder — pola initiateChat di builder (yang dulu
//      dicontohkan di README) menyebabkan draft text hilang & pesan baru
//      hilang saat rebuild.
// -----------------------------------------------------------------------------

// Ganti dengan appId & channelId milikmu (lihat constant.dart untuk nilai
// yang sudah dipakai di example ini).
const _appId = 'wefds-c6f0p2h1cxwz3oq';
const _channelAId = '126962';
const _channelBId = '126963'; // isi dengan channel kedua yang valid

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // CATATAN: tiap channel dibungkus QMultichannelProvider TANPA
  // parentProviderContainer — setiap provider membuat ProviderScope mandiri
  // yang meng-override SEMUA config (appId, channelId, theme, dll) + SDK
  // instance sendiri. Ini pola yang benar untuk 2 channel dalam satu app.
  //
  // JANGAN share parentProviderContainer antar channel DULU: widget baru
  // meng-isolate qiscusSDKProvider pada jalur parent (fix 1.3.5), provider
  // config/state (channelId, account, room, session) masih resolve ke parent
  // yang sama → antar channel saling timpa data.
  runApp(const TwoChannelsDemo());
}

class TwoChannelsDemo extends StatelessWidget {
  const TwoChannelsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Two Channels Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Two Channels in One App'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Channel A'),
                Tab(text: 'Channel B'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ChannelWidget(
                label: 'Channel A',
                appId: _appId,
                channelId: _channelAId,
                username: 'guest-channel-a',
                displayName: 'Guest Channel A',
              ),
              _ChannelWidget(
                label: 'Channel B',
                appId: _appId,
                channelId: _channelBId,
                username: 'guest-channel-b',
                displayName: 'Guest Channel B',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelWidget extends StatelessWidget {
  const _ChannelWidget({
    required this.label,
    required this.appId,
    required this.channelId,
    required this.username,
    required this.displayName,
  });

  final String label;
  final String appId;
  final String channelId;
  final String username;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    // Setiap channel dibungkus QMultichannelProvider sendiri (TANPA parent
    // container): ProviderScope mandiri meng-override semua config + SDK
    // instance sendiri → state antar channel benar-benar terpisah.
    return QMultichannelProvider(
      appId: appId,
      channelId: channelId,
      builder: (context) {
        return _ChannelView(
          label: label,
          username: username,
          displayName: displayName,
        );
      },
    );
  }
}

class _ChannelView extends ConsumerStatefulWidget {
  const _ChannelView({
    required this.label,
    required this.username,
    required this.displayName,
  });

  final String label;
  final String username;
  final String displayName;

  @override
  ConsumerState<_ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends ConsumerState<_ChannelView> {
  bool _loggingIn = false;
  String? _loginError;

  String get label => widget.label;
  String get username => widget.username;
  String get displayName => widget.displayName;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final multichannel = ref.read(QMultichannel.provider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: account.maybeWhen(
          // Sudah initiateChat & punya account → tampilkan room info.
          data: (acc) => _buildLoggedIn(context, multichannel, acc),
          // Belum initiateChat (loading/error dari provider awal) → tombol
          // login. Tidak menunggu account resolve: initiateChat-lah yang
          // membuat account terisi, jadi selama belum ada sesi tampilkan
          // aksi login.
          orElse: () => _buildLogin(context, multichannel),
        ),
      ),
    );
  }

  Widget _buildLoggedIn(
    BuildContext context,
    IQMultichannel multichannel,
    QAccount account,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label — logged in',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'User: ${account.name}\n'
          'Room ID: ${multichannel.roomId}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => _openChat(context, multichannel),
          child: const Text('Open Chat'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            await multichannel.clearUser();
            if (mounted) {
              setState(() {
                _loginError = null;
              });
            }
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _buildLogin(BuildContext context, IQMultichannel multichannel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label — not logged in yet',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'setUser + initiateChat dipanggil dari tombol di bawah '
          '(bukan dari builder), lalu session disimpan per channel.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_loginError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _loginError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loggingIn ? null : () => _login(multichannel),
          child: _loggingIn
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login & Start Chat'),
        ),
      ],
    );
  }

  Future<void> _login(IQMultichannel multichannel) async {
    setState(() {
      _loggingIn = true;
      _loginError = null;
    });

    try {
      multichannel.setUser(
        userId: username,
        displayName: displayName,
      );
      await multichannel.initiateChat();
      // Account terisi → widget rebuild ke state logged-in.
    } catch (e) {
      // Tampilkan pesan error di UI (mis. channel tidak ditemukan / network)
      // supaya host app bisa lihat kenapa login gagal, bukan crash diam-diam.
      if (mounted) {
        setState(() {
          _loginError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loggingIn = false;
        });
      }
    }
  }

  void _openChat(BuildContext context, IQMultichannel multichannel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QChatRoomScreen(
          onBack: (ctx) {
            multichannel.clearUser();
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}
