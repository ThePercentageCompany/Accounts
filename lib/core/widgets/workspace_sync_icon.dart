import 'package:flutter/material.dart';
import 'loading.dart';

class WorkspaceSyncIcon extends StatelessWidget {
  const WorkspaceSyncIcon(
      {super.key,
      required this.syncing,
      required this.color,
      required this.icon});
  final bool syncing;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: syncing
                  ? AppActivityIndicator(color: color)
                  : Icon(icon, color: color, size: 24))));
}
