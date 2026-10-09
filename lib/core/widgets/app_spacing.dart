import 'package:flutter/material.dart';

/// Shared screen gutters. Inner cards and form fields keep their own spacing.
abstract final class AppSpacing {
  static const double small = 8;
  static const double item = 12;
  static const double section = 24;

  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? 16 : 24;

  static EdgeInsets page(BuildContext context) => EdgeInsets.fromLTRB(
        gutter(context),
        16,
        gutter(context),
        24,
      );

  static EdgeInsets list(BuildContext context) => EdgeInsets.fromLTRB(
        gutter(context),
        8,
        gutter(context),
        24,
      );
}
