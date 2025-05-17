import 'package:flutter/material.dart';

class ChatCardItem {
  final IconData icon;
  final String chatName;
  final String lastMessage;
  final String clock;


  ChatCardItem({
    required this.icon,
    required this.chatName,
    required this.lastMessage,
    required this.clock,
  });
}