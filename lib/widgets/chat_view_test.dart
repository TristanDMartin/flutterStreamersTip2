import 'package:flutter/material.dart';

class ChatViewTest extends StatelessWidget {
  const ChatViewTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.yellow,
        padding: const EdgeInsets.all(50),
        child: const Center(
          child: Text(
            "TEST VIEW - CAN YOU SEE THIS?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
