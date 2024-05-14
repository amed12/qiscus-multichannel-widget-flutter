import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:multichannel_flutter_sample/constants.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';

class ExampleWithFabScreen extends ConsumerStatefulWidget {
  const ExampleWithFabScreen({super.key});

  @override
  ConsumerState<ExampleWithFabScreen> createState() =>
      _ExampleWithFabScreenState();
}

class _ExampleWithFabScreenState extends ConsumerState<ExampleWithFabScreen> {
  late Stream<QChatRoom> chatRoomStream;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    chatRoomStream = initiateChat().asStream();
    Future.delayed(Duration.zero, () async {
      enableDebugMode(true);
      setChannelId(channelId);
      setUser(userId: 'fathullah@qiscus.co', displayName: 'Achmad');
      var deviceId = await FirebaseMessaging.instance.getToken();
      setDeviceId(deviceId!);
    });

  }

  @override
  Widget build(BuildContext context) {
    ///use this provider to listen received message
    ///and filter who is sender
    ref.listen<List<QMessage>>(
      messagesProvider,
      (previousMessages, newMessages) async {
        if (newMessages.last.sender.id != loggedInAccountId()) {
          setState(() {
            unreadCount++;
          });
        }
      },
    );

    return Scaffold(
        appBar: AppBar(
          title: Text('appbarTitle'),
        ),
        body: StreamBuilder<QChatRoom>(
          stream: chatRoomStream,
          builder: (context, snapshot) {
            return Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? CircularProgressIndicator()
                  : snapshot.hasData
                      ? Text(snapshot.data?.name ?? '')
                      : snapshot.hasError
                          ? Text('Error: ${snapshot.error}')
                          : Text('No chat room found'),
            );
          },
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.all(16),
          child: Stack(
            children: [
              FloatingActionButton(
                onPressed: () {
                  ///reset unread badge when enter
                  ///indicating that user logged in enter chat room and read all chat
                  setState(() {
                    unreadCount = 0;
                  });
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => QChatRoomScreen(onBack: (ctx) {
                        print('on do back!');
                        Navigator.of(context)
                            .maybePop()
                            .then((r) => debugPrint('maybePop: $r'));
                      }),
                    ),
                  );
                },
                tooltip: 'Enter room chat',
                child: Icon(Icons.chat_bubble), //Change Icon
              ),
              Positioned(
                top: 4,
                right: 8,
                child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(30))
                    ),
                    padding: EdgeInsets.all(4),
                    child: Text(unreadCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall),
                  ),
              )
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat);
  }
  
  String? loggedInAccountId() => ref.watch(accountProvider.select((v) => v.asData?.value.id));

  void setUser({
    required String userId,
    required String displayName,
    String? avatarUrl,
    Map<String, dynamic>? userProperties,
  }) {
    ref.read(userIdProvider.notifier).state = userId;
    ref.read(displayNameProvider.notifier).state = displayName;
    ref.read(userAvatarUrl.notifier).state = avatarUrl;
    ref.read(userPropertiesProvider.notifier).state = userProperties;
  }

  void setChannelId(String channelId) {
    ref.read(channelIdConfigProvider.notifier).state = channelId;
  }

  Future<void> clearUser() async {
    ref.read(userIdProvider.notifier).state = null;
    ref.read(displayNameProvider.notifier).state = null;
    ref.read(userPropertiesProvider.notifier).state = null;
    ref.read(sdkUserExtrasProvider.notifier).state = null;
    ref.read(messagesProvider.notifier).clear();
    ref.read(qiscusProvider.future).then((q) => q.clearUser());
  }

  void setDeviceId(String deviceId, {bool isDevelopment = false}) {
    ref.read(deviceIdConfigProvider.notifier).state = deviceId;
    ref.read(deviceIdDevelopmentModeProvider.notifier).state = isDevelopment;
  }

  Future<QChatRoom> initiateChat() async {
    var room = await ref.read(initiateChatProvider.future).then((f) => f());

    return room;
  }

  void enableDebugMode(bool enable) async {
    var qiscus = await ref.read(qiscusProvider.future);
    qiscus.enableDebugMode(enable: enable, level: QLogLevel.verbose);
  }
}
