import 'package:flutter/material.dart';

class CustomFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const CustomFloatingButton({
    Key? key,
    required this.onPressed,
    this.icon = Icons.add,
    this.backgroundColor = const Color(0xFF1380FE),
    this.iconColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      shape: const CircleBorder(),
      child: Icon(icon, color: iconColor),
    );
  }
}
