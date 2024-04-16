import 'package:flutter/widgets.dart';
import 'package:qiscus_chat_sdk/qiscus_chat_sdk.dart';
import 'package:qiscus_multichannel_widget/src/widgets/chat_reply.dart';

import '../models.dart';
import '../widgets/chat_buttons.dart';
import '../widgets/chat_file.dart';
import '../widgets/chat_image.dart';
import '../widgets/chat_system.dart';
import '../widgets/chat_text.dart';
import '../widgets/chat_video.dart';
import '../widgets/chat_carousel.dart';

final fileRe = RegExp(r'(https?:\/\/.*\.(?:png|jpg|jpeg|gif))');

Widget buildMessageArea(QMessage message) {
  switch (message.runtimeType) {
    case QMessageSystem:
      return QChatSystem(message: message);
    case QMessageImage:
      return QChatImage(
        message: message,
        url: (message as QMessageImage).url,
      );
    case QMessageFile:
      return QChatFile(message: message as QMessageFile);
    case QMessageVideo:
      return QChatVideo(message: message as QMessageVideo);
    case QMessageButton:
      return QChatButton(message: message as QMessageButton);
    case QMessageCarousel:
      return QChatCarousel(message: message as QMessageCarousel);
    case QMessageReply:
      return QChatReply(message: message as QMessageReply);
    default:
      return QChatText(message: message);
  }
}
