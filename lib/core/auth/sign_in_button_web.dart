import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget googleButton(VoidCallback onTap) => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        shape: web.GSIButtonShape.rectangular,
        text: web.GSIButtonText.signinWith,
      ),
    );
