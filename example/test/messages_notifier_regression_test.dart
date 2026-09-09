import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';

/// Regression test untuk crash di rilis 1.3.5 (fix draft-lost commit 04ddea0):
/// MessagesNotifier.build() membaca `state` miliknya sendiri di dalam build()
/// pertama → `Bad state: Tried to read the state of an uninitialized provider`
/// setiap kali chat room pertama dibuka setelah initiateChat() sukses.
/// (dilaporkan Fathullah, Slack C01HU4JV571 ts 1788934055.356039)
void main() {
  test(
      'messagesNotifier builds after room loaded without crashing '
      '(regression: uninitialized provider)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Simulasi flow: initiateChat() selesai → roomStateProvider terisi —
    // sebelum MessagesNotifier pertama kali dibangun (persis skenario crash).
    final room = QChatRoom(id: 1, uniqueId: 'room-1');
    container.read(roomStateProvider.notifier).state =
        QChatRoomWithMessages(room, const []);

    // 1.3.5: baris ini melempar Bad state: Tried to read the state of an
    // uninitialized provider.
    expect(() => container.read(messagesNotifierProvider), returnsNormally);
    expect(container.read(messagesNotifierProvider), isEmpty);

    // initiateChat() dipanggil ulang (room sama di-set lagi) — harus tetap
    // normal, tanpa crash dan tanpa kehilangan state.
    container.read(roomStateProvider.notifier).state =
        QChatRoomWithMessages(QChatRoom(id: 1, uniqueId: 'room-1'), const []);
    expect(container.read(messagesNotifierProvider), isEmpty);

    // Pindah ke room/channel lain → state diganti total dengan snapshot baru.
    container.read(roomStateProvider.notifier).state =
        QChatRoomWithMessages(QChatRoom(id: 2, uniqueId: 'room-2'), const []);
    expect(container.read(messagesNotifierProvider), isEmpty);
  });
}
