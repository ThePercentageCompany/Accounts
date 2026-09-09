import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeVariant {
  success, // Pastel Mint
  warning, // Pastel Orange / Amber
  danger,  // Pastel Rose
  info,    // Pastel Blue / Purple
  neutral, // Pastel Slate
}

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool isSmall;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
    this.isSmall = false,
  });

  factory AppBadge.status(String status, {bool isSmall = false}) {
    final s = status.toLowerCase().trim();
    if (s == 'paid' || s == 'approved' || s == 'present' || s == 'active') {
      return AppBadge(
        label: status.toUpperCase(),
        variant: BadgeVariant.success,
        icon: CupertinoIcons.checkmark_alt_circle_fill,
        isSmall: isSmall,
      );
    } else if (s == 'unpaid' || s == 'draft' || s == 'halfday' || s == 'half day' || s == 'pending') {
      return AppBadge(
        label: (s == 'halfday' ? 'Half Day' : status).toUpperCase(),
        variant: BadgeVariant.warning,
        icon: CupertinoIcons.clock_fill,
        isSmall: isSmall,
      );
    } else if (s == 'overdue' || s == 'void' || s == 'absent' || s == 'unpaidleave' || s == 'unpaid leave') {
      return AppBadge(
        label: (s == 'unpaidleave' ? 'Unpaid Leave' : status).toUpperCase(),
        variant: BadgeVariant.danger,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        isSmall: isSmall,
      );
    } else if (s == 'paidleave' || s == 'paid leave' || s == 'sickleave' || s == 'sick leave') {
      return AppBadge(
        label: (s == 'paidleave' ? 'Paid Leave' : s == 'sickleave' ? 'Sick Leave' : status).toUpperCase(),
        variant: BadgeVariant.info,
        icon: CupertinoIcons.bandage_fill,
        isSmall: isSmall,
      );
    }
    return AppBadge(
      label: status.toUpperCase(),
      variant: BadgeVariant.neutral,
      isSmall: isSmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bg;
    Color fg;

    switch (variant) {
      case BadgeVariant.success:
        bg = isDark ? AppTheme.pastelMintBgDark : AppTheme.pastelMintBg;
        fg = AppTheme.pastelMint;
        break;
      case BadgeVariant.warning:
        bg = isDark ? AppTheme.pastelOrangeBgDark : AppTheme.pastelOrangeBg;
        fg = AppTheme.pastelOrange;
        break;
      case BadgeVariant.danger:
        bg = isDark ? AppTheme.pastelRoseBgDark : AppTheme.pastelRoseBg;
        fg = AppTheme.pastelRose;
        break;
      case BadgeVariant.info:
        bg = isDark ? AppTheme.pastelPurpleBgDark : AppTheme.pastelPurpleBg;
        fg = AppTheme.pastelPurple;
        break;
      case BadgeVariant.neutral:
        bg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
        fg = isDark ? const Color(0xFFAAAAAF) : const Color(0xFF636366);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: isSmall ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
