import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Appearance is saved locally and applies to every screen and dialog.
class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: themeController,
        builder: (context, _) => PopupMenuButton<ThemeMode>(
          tooltip: 'Appearance',
          initialValue: themeController.themeMode,
          onSelected: themeController.setThemeMode,
          icon: Icon(Theme.of(context).brightness == Brightness.dark
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined),
          itemBuilder: (_) => [
            for (final item in const [
              (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
              (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
              (ThemeMode.system, Icons.brightness_auto_outlined, 'System'),
            ])
              PopupMenuItem(
                  value: item.$1,
                  child: Row(children: [
                    Icon(item.$2, size: 20),
                    const SizedBox(width: 12),
                    Text(item.$3),
                    const SizedBox(width: 20),
                    if (themeController.themeMode == item.$1)
                      const Icon(Icons.check, size: 18),
                  ])),
          ],
        ),
      );
}
