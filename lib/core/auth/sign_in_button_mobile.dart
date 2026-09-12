import 'package:flutter/material.dart';

Widget googleButton(VoidCallback onTap) => OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.account_circle, size: 20),
      label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
