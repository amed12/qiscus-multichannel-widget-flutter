part of 'provider.dart';

@riverpod
class MessagesNotifier extends _$MessagesNotifier {
  int? _roomId;

  @override
  List<QMessage> build() {
    ref.subscribe(messageReceivedProvider, (QMessage m) {
      _onMessageReceived(m);
    });

    // Snapshot room (re)loads — initiateChat() pertama maupun ulang — lewat
    // listener, BUKAN ref.watch: watch akan me-rebuild notifier ini dan
    // meng-clobber state lokal (pesan baru yang belum ada di snapshot
    // server) — itu bug draft-lost. Listen tidak membuat dependency, jadi
    // build() hanya jalan sekali per siklus hidup notifier.
    final sub = ref.listen<AsyncValue<QChatRoomWithMessages>>(
      roomProvider,
      (prev, next) {
        _syncFromRoom(next);
      },
    );
    ref.onDispose(sub.close);

    // Seed awal: kalau room sudah termuat saat notifier pertama dibangun
    // (flow normal: initiateChat() selesai sebelum QChatRoomScreen dibuka),
    // pakai snapshot server sebagai state awal. Tidak membaca `state`
    // sendiri di dalam build (Riverpod melarangnya).
    var room = ref.read(roomProvider);
    var messages = room.valueOrNull?.messages;
    if (messages != null) {
      _roomId = room.valueOrNull!.room.id;
      return [...messages];
    }

    return const [];
  }

  /// Sinkronkan snapshot server dari [roomProvider] ke state.
  ///
  /// - Room berbeda (channel pindah / login baru): ganti total dengan
  ///   snapshot.
  /// - Room sama (initiateChat() dipanggil ulang): merge — pesan lokal yang
  ///   belum ada di snapshot server tetap dipertahankan, yang sudah dikenal
  ///   di-update dari server.
  void _syncFromRoom(AsyncValue<QChatRoomWithMessages> room) {
    var data = room.valueOrNull;
    if (data == null) return;

    var roomId = data.room.id;
    if (_roomId != roomId) {
      _roomId = roomId;
      state = [...data.messages];
      return;
    }

    if (state.isEmpty) {
      state = [...data.messages];
      return;
    }

    var merged = [...state];
    for (var msg in data.messages) {
      var idx = merged.indexWhere((v) => v.uniqueId == msg.uniqueId);
      if (idx == -1) {
        merged.add(msg);
      } else {
        merged[idx] = msg;
      }
    }
    state = merged;
  }

  void _onMessageRead(QMessage message) {
    state = state.map((m) {
      if (m.timestamp.isBefore(message.timestamp)) {
        m.status = QMessageStatus.read;
      }

      return m;
    }).toList();
  }

  void _onMessageReceived(QMessage message) {
    message.status = QMessageStatus.read;
    var idx = state.indexWhere((v) => v.uniqueId == message.uniqueId);

    if (idx == -1) {
      state = [...state, message];
    } else {
      state = state.updateAt(
        index: idx,
        value: message,
      );
    }
  }

  Future<QMessage> sendMessage(QMessage message) async {
    var qiscus = await ref.read(qiscusProvider.future);
    message.status = QMessageStatus.sending;
    _onMessageReceived(message);

    Future.microtask(() async {
      var m = await qiscus.sendMessage(message: message);
      message.id = m.id;
      message.status = QMessageStatus.read;
      _onMessageReceived(message);
      _onMessageRead(message);
      qiscus.synchronize();
    });

    return message;
  }

  Future<QMessage> deleteMessage(String messageUniqueId) async {
    var qiscus = await ref.read(qiscusProvider.future);
    var messages = state.firstWhere((v) => v.uniqueId == messageUniqueId);

    await qiscus.deleteMessages(messageUniqueIds: [messageUniqueId]);
    state = state.where((v) => v.uniqueId != messageUniqueId).toList();

    return messages;
  }

  Future<List<QMessage>> loadMoreMessage([int lastMessageId = 0]) async {
    var qiscus = await ref.read(qiscusProvider.future);
    var roomId = await ref.read(roomIdProvider.future);

    var messages = await qiscus.getPreviousMessagesById(
      roomId: roomId,
      messageId: lastMessageId,
    );

    state = [
      ...messages,
      ...state,
    ];

    return messages;
  }

  void clear() {
    state = const [];
  }
}

class MessagesStateNotifier extends StateNotifier<List<QMessage>> {
  final AutoDisposeStateNotifierProviderRef ref;

  MessagesStateNotifier(
    this.ref, {
    List<QMessage> state = const [],
  }) : super(state) {
    ref.subscribe(messageReceivedProvider, (QMessage m) {
      _onMessageReceived(m);
    });
  }

  void _onMessageRead(QMessage message) {
    state = state.map((m) {
      if (m.timestamp.isBefore(message.timestamp)) {
        m.status = QMessageStatus.read;
      }

      return m;
    }).toList();
  }

  void _onMessageReceived(QMessage message) {
    message.status = QMessageStatus.read;
    var idx = state.indexWhere((v) => v.uniqueId == message.uniqueId);

    if (idx == -1) {
      state = [...state, message];
    } else {
      state = state.updateAt(
        index: idx,
        value: message,
      );
    }
  }

  Future<QMessage> sendMessage(QMessage message) async {
    var qiscus = await ref.read(qiscusProvider.future);
    message.status = QMessageStatus.sending;
    _onMessageReceived(message);

    Future.microtask(() async {
      var m = await qiscus.sendMessage(message: message);
      message.id = m.id;
      message.status = QMessageStatus.read;
      _onMessageReceived(message);
      _onMessageRead(message);
      qiscus.synchronize();
    });

    return message;
  }

  Future<QMessage> deleteMessage(String messageUniqueId) async {
    var qiscus = await ref.read(qiscusProvider.future);
    var messages = state.firstWhere((v) => v.uniqueId == messageUniqueId);

    await qiscus.deleteMessages(messageUniqueIds: [messageUniqueId]);
    state = state.where((v) => v.uniqueId != messageUniqueId).toList();

    return messages;
  }

  Future<List<QMessage>> loadMoreMessage([int lastMessageId = 0]) async {
    var qiscus = await ref.read(qiscusProvider.future);
    var roomId = await ref.read(roomIdProvider).future;
    // var lastMessage = ref.watch(lastMessageProvider);
    // lastMessageId ??= lastMessage.id;

    var messages = await qiscus.getPreviousMessagesById(
      roomId: roomId,
      messageId: lastMessageId,
    );

    state = [
      ...messages,
      ...state,
    ];

    return messages;
  }

  void clear() {
    state = const [];
  }
}

@riverpod
List<QMessage> sortedMessages(SortedMessagesRef ref) {
  var roomId = ref.watch(roomIdProvider).value;
  var messages = ref.watch(messagesNotifierProvider).where((m) {
    return m.chatRoomId == roomId;
  }).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return messages;
}

@riverpod
List<QMessage> mappedMessages(MappedMessagesRef ref) {
  var messages = ref.watch(sortedMessagesProvider);
  var showSystemMessage = ref.watch(systemEventVisibleConfigProvider);

  return messages.map((it) {
    QMessage? message;

    message ??= QMessageSystem.tryParse(it);
    message ??= QMessageImage.tryParse(it);
    message ??= QMessageVideo.tryParse(it);
    message ??= QMessageFile.tryParse(it);
    // Not yet mature
    message ??= QMessageButton.tryParse(it);
    message ??= QMessageCarousel.tryParse(it);
    message ??= QMessageReply.tryParse(it);
    message ??= it;

    return message;
  }).where((m) {
    if (m is QMessageSystem) return showSystemMessage;
    return true;
  }).toList();
}
