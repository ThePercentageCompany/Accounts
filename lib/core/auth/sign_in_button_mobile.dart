import 'package:flutter/material.dart';

Widget googleButton(VoidCallback onTap) => OutlinedButton(
  onPressed: onTap,
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.account_circle, size: 20),
      SizedBox(width: 8),
      Flexible(
        child: Text(
          'Sign in with Google',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ],
  ),
);
