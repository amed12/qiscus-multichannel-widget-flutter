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

  // Satu container induk dipakai BERSAMA oleh kedua channel widget.
  // ProviderScope di sini dibutuhkan karena QMultichannelProvider dengan
  // parentProviderContainer membaca provider-nya di initState.
  final parentContainer = ProviderContainer();

  runApp(
    ProviderScope(
      parent: parentContainer,
      child: TwoChannelsDemo(parentContainer: parentContainer),
    ),
  );
}

class TwoChannelsDemo extends StatelessWidget {
  const TwoChannelsDemo({super.key, required this.parentContainer});

  final ProviderContainer parentContainer;

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
                parentContainer: parentContainer,
              ),
              _ChannelWidget(
                label: 'Channel B',
                appId: _appId,
                channelId: _channelBId,
                username: 'guest-channel-b',
                displayName: 'Guest Channel B',
                parentContainer: parentContainer,
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
    required this.parentContainer,
  });

  final String label;
  final String appId;
  final String channelId;
  final String username;
  final String displayName;
  final ProviderContainer parentContainer;

  @override
  Widget build(BuildContext context) {
    // Setiap channel dibungkus QMultichannelProvider sendiri, dengan
    // parentProviderContainer yang SAMA. Widget ini yang memastikan
    // qiscusSDKProvider di-override fresh per channel (fix 1.3.5).
    return QMultichannelProvider(
      appId: appId,
      channelId: channelId,
      parentProviderContainer: parentContainer,
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

class _ChannelView extends ConsumerWidget {
  const _ChannelView({
    required this.label,
    required this.username,
    required this.displayName,
  });

  final String label;
  final String username;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final multichannel = ref.read(QMultichannel.provider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: account.when(
          data: (acc) => _buildLoggedIn(context, multichannel, acc),
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => _buildError(context, multichannel, error),
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
          onPressed: () => multichannel.clearUser(),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _buildError(
    BuildContext context,
    IQMultichannel multichannel,
    Object error,
  ) {
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => _login(multichannel),
          child: const Text('Login & Start Chat'),
        ),
      ],
    );
  }

  Future<void> _login(IQMultichannel multichannel) async {
    multichannel.setUser(
      userId: username,
      displayName: displayName,
    );
    await multichannel.initiateChat();
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
