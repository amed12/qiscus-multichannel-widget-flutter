import 'package:flutter/material.dart';
import 'package:qiscus_multichannel_widget/qiscus_multichannel_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final usernameController = TextEditingController(text: 'guest-1001');
  late final displayNameController = TextEditingController(text: 'guest-1001');
  late final phoneNumberController = TextEditingController();
  late final schoolNameController = TextEditingController();
  late final roleController = TextEditingController();
  late final messageController = TextEditingController();

  late final channelIdController =
      TextEditingController(text: '126962'); // Non-secure Channel

  // State for loading
  bool isLoading = false;

  // This state tracks whether the button should be disabled
  bool isButtonDisabled = true;

  @override
  void initState() {
    super.initState();
    _addListenersToTextFields();
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

  void _addListenersToTextFields() {
    // Add listeners to all TextEditingControllers to watch for changes
    appIdController.addListener(_updateButtonState);
    usernameController.addListener(_updateButtonState);
    displayNameController.addListener(_updateButtonState);
    phoneNumberController.addListener(_updateButtonState);
    schoolNameController.addListener(_updateButtonState);
    roleController.addListener(_updateButtonState);
    messageController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      isButtonDisabled = appIdController.text.isEmpty ||
          usernameController.text.isEmpty ||
          displayNameController.text.isEmpty ||
          phoneNumberController.text.isEmpty ||
          schoolNameController.text.isEmpty ||
          roleController.text.isEmpty ||
          messageController.text.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Username'),
                  controller: usernameController,
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Display name'),
                  controller: displayNameController,
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Phone Number'),
                  controller: phoneNumberController,
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'School Name'),
                  controller: schoolNameController,
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Role'),
                  controller: roleController,
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Message'),
                  controller: messageController,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isButtonDisabled || isLoading
                        ? null
                        : () => _handleLoginButtonPress(context),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text('Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLoginButtonPress(BuildContext context) async {
    setState(() {
      isLoading = true; // Show loading
    });

    try {
      await openLiveChat(
        context,
        name: displayNameController.text, // Get from input
        phoneNumber: phoneNumberController.text, // Get from input
        schoolName: schoolNameController.text, // Get from input
        role: roleController.text, // Get from input
        message: messageController.text, // Get from input
        ref: ref.read(QMultichannel.provider),
      );
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        isLoading = false; // Hide loading
      });
    }
  }

  Future<void> openLiveChat(
    BuildContext context, {
    required IQMultichannel ref,
    required String name,
    required String phoneNumber,
    required String schoolName,
    required String role,
    required String message,
    bool guest = false,
  }) async {
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
      return;
    }

    try {
      await ref.initiateChat();
      // Wait until the chat is fully initiated
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QChatRoomScreen(
            onBack: (ctx) {
              ref.clearUser();
              Navigator.of(context).maybePop();
            },
          ),
        ),
      );
    } catch (e) {
      ref.clearUser();
      print('Error initiating chat: $e');
    }
  }
}
