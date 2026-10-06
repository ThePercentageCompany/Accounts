import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_validation.dart';
export 'app_validation.dart';

/// Type-specific input restrictions complement, rather than replace, domain
/// checks such as outstanding balances, date ordering and immutable IDs.
class ValidatedTextField extends StatelessWidget {
  const ValidatedTextField(
      {super.key,
      this.controller,
      this.initialValue,
      this.kind = AppInputKind.text,
      this.required = false,
      this.validator,
      this.keyboardType,
      this.decoration = const InputDecoration(),
      this.maxLength,
      this.maxLines = 1,
      this.minLines,
      this.enabled,
      this.readOnly = false,
      this.autofocus = false,
      this.obscureText = false,
      this.focusNode,
      this.textInputAction,
      this.onChanged,
      this.onFieldSubmitted,
      this.onSaved,
      this.onTap,
      this.inputFormatters,
      this.style,
      this.autovalidateMode,
      this.textCapitalization = TextCapitalization.none,
      this.enableInteractiveSelection = true,
      this.autocorrect = true,
      this.enableSuggestions = true});
  final TextEditingController? controller;
  final String? initialValue;
  final AppInputKind kind;
  final bool required, readOnly, autofocus, obscureText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final InputDecoration decoration;
  final int? maxLength, maxLines, minLines;
  final bool? enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final AutovalidateMode? autovalidateMode;
  final TextCapitalization textCapitalization;
  final bool enableInteractiveSelection;
  final bool autocorrect, enableSuggestions;
  AppInputKind get effectiveKind => kind != AppInputKind.text
      ? kind
      : keyboardType == TextInputType.emailAddress
          ? AppInputKind.email
          : keyboardType == TextInputType.phone
              ? AppInputKind.phone
              : keyboardType?.index == TextInputType.number.index
                  ? keyboardType?.decimal == true
                      ? AppInputKind.decimal
                      : AppInputKind.integer
                  : kind;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: initialValue,
        focusNode: focusNode,
        enabled: enabled,
        readOnly: readOnly,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        style: style,
        textCapitalization: textCapitalization,
        decoration: decoration.copyWith(
            errorMaxLines: decoration.errorMaxLines ?? 3,
            suffixText: decoration.suffixText ?? (required ? '*' : null)),
        keyboardType: keyboardType ??
            switch (effectiveKind) {
              AppInputKind.email => TextInputType.emailAddress,
              AppInputKind.phone => TextInputType.phone,
              AppInputKind.integer => TextInputType.number,
              AppInputKind.money ||
              AppInputKind.decimal ||
              AppInputKind.percentage =>
                const TextInputType.numberWithOptions(decimal: true),
              _ => maxLines != 1 ? TextInputType.multiline : TextInputType.text,
            },
        inputFormatters: [
          ...AppInputFormatters.forKind(effectiveKind),
          ...?inputFormatters
        ],
        textInputAction: textInputAction ??
            (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
        autovalidateMode:
            autovalidateMode ?? AutovalidateMode.onUserInteraction,
        validator: (value) =>
            AppValidators.validate(effectiveKind, value,
                required: required, maxLength: maxLength) ??
            validator?.call(value),
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        onSaved: onSaved,
        onTap: onTap,
        enableInteractiveSelection: enableInteractiveSelection,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
      );
}
