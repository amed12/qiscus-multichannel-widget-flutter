import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late IQMultichannel multichannelProvider;

  @override
  void initState() {
    super.initState();
    multichannelProvider = ref.read(QMultichannel.provider);
    chatRoomStream = multichannelProvider.initiateChat().asStream();
    Future.delayed(Duration.zero, () async {
      multichannelProvider.enableDebugMode(true);
      multichannelProvider.setChannelId(channelId);
      multichannelProvider.setUser(userId: 'fathullah@qiscus.co', displayName: 'Achmad');
      var deviceId = await FirebaseMessaging.instance.getToken();
      multichannelProvider.setDeviceId(deviceId!);
    });

  }

  @override
  Widget build(BuildContext context) {
    ///use this provider to listen received message
    ///and filter who is sender
    //

    ref.listen<List<QMessage>>(
      messagesNotifierProvider,
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
                      ? Text('Ready to chat on room ${snapshot.data?.name}')
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
}
