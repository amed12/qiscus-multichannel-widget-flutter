import 'package:flutter/material.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'pages/login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppStateBuilder();
}

class _AppStateBuilder extends State<App> {
  var appId = 'wefds-c6f0p2h1cxwz3oq';

  @override
  Widget build(BuildContext context) {
    return QMultichannelProvider(
      appId: appId,
      channelId: channelId,
      onURLTapped: (url) {
        var uri = Uri.tryParse(url);
        print('url tapped: $url $uri');
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      },
      builder: (context) {
        return MaterialApp(
          navigatorObservers: [
            QNavObserver(),
          ],
          home: LoginScreen(
            onChangeAppId: (appId) {
              setState(() {
                this.appId = appId;
              });
            },
          ),
        );
      },
    );
  }
}
