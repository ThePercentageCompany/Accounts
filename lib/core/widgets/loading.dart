import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Native activity indicator that also respects reduced-motion preferences.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({super.key, this.radius = 10, this.color});
  final double radius;
  final Color? color;
  @override
  Widget build(BuildContext context) => CupertinoActivityIndicator(
        radius: radius,
        color: color ?? IconTheme.of(context).color,
        animating: !MediaQuery.disableAnimationsOf(context) &&
            (ModalRoute.of(context)?.isCurrent ?? true),
      );
}

/// Centers within the constraints supplied by the page, panel or dialog.
class CenteredLoading extends StatelessWidget {
  const CenteredLoading({super.key, this.label = 'Loading'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const ExcludeSemantics(child: AppActivityIndicator()),
        ),
      );
}

enum _ButtonKind { filled, outlined, text, icon }

/// First-load indicator; refreshes keep existing records visible.
class RecordSkeleton extends StatelessWidget {
  const RecordSkeleton({super.key});
  @override
  Widget build(BuildContext context) =>
      const CenteredLoading(label: 'Loading records');
}

/// Tracks the returned future independently for each button. Existing handlers
/// retain validation and error handling; unexpected errors get recoverable feedback.
class LoadingButton extends StatefulWidget {
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.busy = false,
  })  : _icon = null,
        _label = null,
        tooltip = null,
        _kind = _ButtonKind.filled;
  const LoadingButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.busy = false,
  })  : child = null,
        _icon = icon,
        _label = label,
        tooltip = null,
        _kind = _ButtonKind.filled;
  const LoadingButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.busy = false,
  })  : _icon = null,
        _label = null,
        tooltip = null,
        _kind = _ButtonKind.outlined;
  const LoadingButton.outlinedIcon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.busy = false,
  })  : child = null,
        _icon = icon,
        _label = label,
        tooltip = null,
        _kind = _ButtonKind.outlined;
  const LoadingButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.busy = false,
  })  : _icon = null,
        _label = null,
        tooltip = null,
        _kind = _ButtonKind.text;
  const LoadingButton.textIcon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.style,
    this.busy = false,
  })  : child = null,
        _icon = icon,
        _label = label,
        tooltip = null,
        _kind = _ButtonKind.text;
  const LoadingButton.iconOnly({
    super.key,
    required this.onPressed,
    required Widget icon,
    this.tooltip,
    this.style,
    this.busy = false,
  })  : child = icon,
        _icon = null,
        _label = null,
        _kind = _ButtonKind.icon;
  final String? tooltip;
  final FutureOr<void> Function()? onPressed;
  final Widget? child;
  final Widget? _icon;
  final Widget? _label;
  final ButtonStyle? style;
  final bool busy;
  final _ButtonKind _kind;
  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _pending = false;
  LoadingButton? _activeButton;
  Future<void> _run() async {
    if (_pending || widget.busy || widget.onPressed == null) return;
    setState(() {
      _pending = true;
      _activeButton = widget;
    });
    try {
      await widget.onPressed!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'The action could not be completed. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _pending || widget.busy;
    final config = _pending ? _activeButton! : widget;
    final callback = busy || widget.onPressed == null ? null : _run;
    // Resolve the enabled palette while busy so contrast and styling are stable.
    final _EnabledPalette prototype = switch (config._kind) {
      _ButtonKind.filled => _PaletteFilledButton(
          onPressed: () {},
          child: const SizedBox(),
        ),
      _ButtonKind.outlined => _PaletteOutlinedButton(
          onPressed: () {},
          child: const SizedBox(),
        ),
      _ButtonKind.text || _ButtonKind.icon => _PaletteTextButton(
          onPressed: () {},
          child: const SizedBox(),
        ),
    };
    final palette = (config._kind == _ButtonKind.icon
            ? ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ).merge(IconButtonTheme.of(context).style)
            : prototype.enabledPalette(context))
        .merge(config.style);
    final style = busy
        ? (config.style ?? const ButtonStyle()).copyWith(
            foregroundColor: WidgetStatePropertyAll(
              palette.foregroundColor?.resolve({}),
            ),
            backgroundColor: WidgetStatePropertyAll(
              palette.backgroundColor?.resolve({}),
            ),
            side: WidgetStatePropertyAll(palette.side?.resolve({})),
          )
        : config.style;
    Widget retained(Widget child) => Opacity(
          opacity: busy ? 0 : 1,
          alwaysIncludeSemantics: true,
          child: child,
        );
    final child = retained(config.child ?? config._label!);
    final icon = config._icon == null ? null : retained(config._icon);
    final button = switch (config._kind) {
      _ButtonKind.icon => IconButton(
          onPressed: callback,
          tooltip: config.tooltip,
          style: style,
          icon: child,
        ),
      _ButtonKind.filled => icon == null
          ? FilledButton(onPressed: callback, style: style, child: child)
          : FilledButton.icon(
              onPressed: callback,
              style: style,
              icon: icon,
              label: child,
            ),
      _ButtonKind.outlined => icon == null
          ? OutlinedButton(onPressed: callback, style: style, child: child)
          : OutlinedButton.icon(
              onPressed: callback,
              style: style,
              icon: icon,
              label: child,
            ),
      _ButtonKind.text => icon == null
          ? TextButton(onPressed: callback, style: style, child: child)
          : TextButton.icon(
              onPressed: callback,
              style: style,
              icon: icon,
              label: child,
            ),
    };
    return MergeSemantics(
      child: Semantics(
        value: busy ? 'Busy' : null,
        liveRegion: busy,
        child: Stack(
          alignment: Alignment.center,
          children: [
            button,
            if (busy)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: ExcludeSemantics(
                      child: AppActivityIndicator(
                        radius: 8,
                        color: palette.foregroundColor?.resolve({}),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

abstract interface class _EnabledPalette {
  ButtonStyle enabledPalette(BuildContext context);
}

class _PaletteFilledButton extends FilledButton implements _EnabledPalette {
  const _PaletteFilledButton({required super.onPressed, required super.child});
  @override
  ButtonStyle enabledPalette(BuildContext context) =>
      defaultStyleOf(context).merge(themeStyleOf(context));
}

class _PaletteOutlinedButton extends OutlinedButton implements _EnabledPalette {
  const _PaletteOutlinedButton({
    required super.onPressed,
    required super.child,
  });
  @override
  ButtonStyle enabledPalette(BuildContext context) =>
      defaultStyleOf(context).merge(themeStyleOf(context));
}

class _PaletteTextButton extends TextButton implements _EnabledPalette {
  const _PaletteTextButton({required super.onPressed, required super.child});
  @override
  ButtonStyle enabledPalette(BuildContext context) =>
      defaultStyleOf(context).merge(themeStyleOf(context));
}
