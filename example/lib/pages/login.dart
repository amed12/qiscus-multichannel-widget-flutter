import 'package:flutter/material.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../constants.dart';

class LoginPage extends Page {
  const LoginPage({
    required this.onChangeAppId,
  }) : super(key: const ValueKey('LoginPageKey'));

  final void Function(String appId) onChangeAppId;

  @override
  String? get name => 'LoginPage';

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (context) => LoginScreen(
        onChangeAppId: onChangeAppId,
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onChangeAppId,
  });

  final void Function(String appId)? onChangeAppId;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final appIdController = TextEditingController(text: 'your-app-id');
  late final usernameController = TextEditingController();
  late final displayNameController = TextEditingController();
  late final phoneNumberController =
      TextEditingController(text: '081234567890');
  late final schoolNameController = TextEditingController(text: 'Demo School');
  late final roleController = TextEditingController(text: 'student');
  late final messageController =
      TextEditingController(text: 'Hello, I need help');

  late final channelIdController =
      TextEditingController(text: '126962'); // Non-secure Channel

  // State for loading
  bool isLoading = false;

  // This state tracks whether login is successful
  bool isLoginSuccess = false;

  // Reference to IQMultichannel
  late IQMultichannel multichannel;

  @override
  void initState() {
    super.initState();
    multichannel = ref.read(QMultichannel.provider);
    multichannel.enableDebugMode(true);
    _generateRandomUser();
    _autoLogin();
  }

  void _generateRandomUser() {
    final now = DateTime.now();
    final formattedDate = intl.DateFormat('yyyyMMdd-HHmmss').format(now);
    final username = 'buddy-$formattedDate';

    usernameController.text = username;
    displayNameController.text = username;
  }

  @override
  void dispose() {
    appIdController.dispose();
    usernameController.dispose();
    displayNameController.dispose();
    phoneNumberController.dispose();
    schoolNameController.dispose();
    roleController.dispose();
    messageController.dispose();
    channelIdController.dispose();
    super.dispose();
  }

  Future<void> _autoLogin() async {
    setState(() {
      isLoading = true;
    });

    try {
      await openLiveChat(
        context,
        name: displayNameController.text,
        phoneNumber: phoneNumberController.text,
        schoolName: schoolNameController.text,
        role: roleController.text,
        message: messageController.text,
        ref: multichannel,
      );

      setState(() {
        isLoginSuccess = true;
        isLoading = false;
      });
    } catch (e) {
      print('Error during auto login: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 25.0, right: 25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Auto Login',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Username: ${usernameController.text}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Status: ${isLoading ? "Logging in..." : isLoginSuccess ? "Login Success" : "Login Failed"}',
                style: TextStyle(
                  fontSize: 16,
                  color: isLoginSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                const CircularProgressIndicator()
              else if (!isLoginSuccess)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _autoLogin,
                    child: const Text('Retry Login'),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: isLoginSuccess
          ? FloatingActionButton(
              onPressed: () => _initiateChatAndNavigate(context, multichannel),
              tooltip: 'Start Chat',
              child: const Icon(Icons.chat),
            )
          : null,
    );
  }

  void _navigateToChatRoom(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QChatRoomScreen(
          onBack: (ctx) {
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }

  Future<void> openLiveChat(
    BuildContext context, {
    required String name,
    required String phoneNumber,
    required String schoolName,
    required String role,
    required String message,
    required IQMultichannel ref,
    bool guest = false,
  }) async {
    await _setupUser(ref, name, phoneNumber, schoolName, role);
  }

  Future<void> _setupUser(
    IQMultichannel ref,
    String name,
    String phoneNumber,
    String schoolName,
    String role,
  ) async {
    final roles = {
      'parent': 'Orang Tua',
      'student': 'Siswa',
      'teacher': 'Guru',
      'school': 'Sekolah',
    };

    try {
      ref.setChannelId(channelId); // Example channelId
      ref.setUser(
        userId: phoneNumber,
        displayName: name,
        avatarUrl:
            'https://smansaskym.sch.id/wp-content/uploads/2022/12/4687668ad0c2a964a603c0f3c766e336.jpg',
        userProperties: {'Sekolah': schoolName, 'Role': roles[role]},
      );
    } catch (e) {
      print('Error setting user: $e');
      rethrow;
    }
  }

  Future<void> _initiateChatAndNavigate(
    BuildContext context,
    IQMultichannel ref,
  ) async {
    try {
      await ref.initiateChat();
      // Wait until the chat is fully initiated
      if (!context.mounted) {
        return;
      }
      _navigateToChatRoom(context);
    } catch (e) {
      ref.clearUser();
      print('Error initiating chat: $e');
    }
  }
}
