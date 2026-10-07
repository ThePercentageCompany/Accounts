import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A gently bobbing cloud with a turning sync badge while work is uploading.
class WorkspaceSyncIcon extends StatefulWidget {
  const WorkspaceSyncIcon(
      {super.key,
      required this.syncing,
      required this.color,
      required this.icon});
  final bool syncing;
  final Color color;
  final IconData icon;

  @override
  State<WorkspaceSyncIcon> createState() => _WorkspaceSyncIconState();
}

class _WorkspaceSyncIconState extends State<WorkspaceSyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  void _updateMotion() {
    if (widget.syncing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant WorkspaceSyncIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => Transform.translate(
              offset: Offset(
                  0,
                  widget.syncing
                      ? math.sin(_motion.value * math.pi * 2) * 2
                      : 0),
              child: Stack(alignment: Alignment.center, children: [
                Icon(widget.syncing ? Icons.cloud_outlined : widget.icon,
                    color: widget.color, size: 24),
                if (widget.syncing)
                  Positioned(
                    right: 1,
                    bottom: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: _motion.value * math.pi * 2,
                        child: Icon(Icons.sync, color: widget.color, size: 15),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}
