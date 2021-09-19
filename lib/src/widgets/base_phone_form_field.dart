import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:phone_form_field/src/localization/phone_field_localization.dart';
import 'package:phone_form_field/src/models/phone_number_input.dart';

import '../models/country.dart';
import 'country_picker/country_selector_navigator.dart';
import 'flag_dial_code_chip.dart';

/// That is the base for the PhoneFormField
///
/// This deals with mostly UI and has no dependency on any phone parser library
class BasePhoneFormField extends FormField<SimplePhoneNumber> {
  final ValueNotifier<SimplePhoneNumber?>? controller;
  final String defaultCountry;
  final bool autofocus;
  final bool showFlagInInput;
  final String errorText;

  /// input decoration applied to the input
  final InputDecoration decoration;
  final TextStyle inputTextStyle;
  final Color? cursorColor;
  final ValueChanged<SimplePhoneNumber?>? onChanged;
  final Iterable<String>? autoFillHints;
  final Function()? onEditingComplete;

  /// configures the way the country picker selector is shown
  final CountrySelectorNavigator selectorNavigator;

  BasePhoneFormField({
    // form field params
    Key? key,
    SimplePhoneNumber? initialValue,
    bool enabled = true,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    void Function(SimplePhoneNumber?)? onSaved,
    String? Function(SimplePhoneNumber?)? validator,
    // our params
    this.controller,
    this.onChanged,
    this.defaultCountry = 'US',
    this.autofocus = true,
    this.showFlagInInput = true,
    this.autoFillHints,
    this.onEditingComplete,
    this.errorText = 'Invalid phone number',
    this.decoration = const InputDecoration(border: UnderlineInputBorder()),
    this.inputTextStyle = const TextStyle(),
    this.cursorColor,
    this.selectorNavigator = const BottomSheetNavigator(),
  }) : super(
          key: key,
          initialValue: initialValue,
          onSaved: onSaved,
          enabled: enabled,
          autovalidateMode: autovalidateMode,
          validator: validator,
          builder: (field) {
            final state = field as _BasePhoneFormFieldState;
            return state.builder();
          },
        );

  @override
  _BasePhoneFormFieldState createState() => _BasePhoneFormFieldState();
}

class _BasePhoneFormFieldState extends FormFieldState<SimplePhoneNumber> {
  final FocusNode _focusNode = FocusNode();

  /// this is the controller for the national phone number
  late final TextEditingController _nationalNumberController;
  late final ValueNotifier<SimplePhoneNumber> _phoneController;

  @override
  BasePhoneFormField get widget => super.widget as BasePhoneFormField;

  bool get _isOutlineBorder => widget.decoration.border is OutlineInputBorder;
  String get _isoCode => value?.isoCode ?? 'US';

  _BasePhoneFormFieldState();

  @override
  void initState() {
    super.initState();
    _nationalNumberController =
        TextEditingController(text: widget.initialValue?.national);
    _focusNode.addListener(() => setState(() {}));
  }

  /// to update the current value of the input
  void updateValue({String? national, String? isoCode}) {
    // if the national number has changed we need to update the controller value
    if (national != null && national != _nationalNumberController.text) {
      _nationalNumberController.value = TextEditingValue(
        text: national,
        selection: TextSelection.fromPosition(
          TextPosition(offset: national.length),
        ),
      );
    }
    final nextValue = SimplePhoneNumber(
      isoCode: isoCode ?? _isoCode,
      national: national ?? '',
    );
    // update form
    didChange(nextValue);
    widget.onChanged?.call(nextValue);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _nationalNumberController.dispose();
    super.dispose();
  }

  selectCountry() async {
    final selected = await widget.selectorNavigator.navigate(context);
    if (selected != null) {
      updateValue(isoCode: selected.isoCode);
    }
    _focusNode.requestFocus();
  }

  Widget builder() {
    // the idea here is to have a TextField with a prefix where the prefix
    // is the flag + dial code which is the same height as text so it's well
    // aligned with the typed text. It also does not push labels etc
    // around and keep the same form factor as TextFormField.
    //
    // Then we stack an InkWell on top of that to add the clickable part
    return Stack(
      children: [
        _textField(),
        if (_focusNode.hasFocus) _inkWellOverlay(),
      ],
    );
  }

  Widget _textField() {
    return TextFormField(
      focusNode: _focusNode,
      controller: _nationalNumberController,
      onChanged: (national) => updateValue(national: national),
      style: widget.inputTextStyle,
      autofocus: widget.autofocus,
      autofillHints: widget.autoFillHints,
      onEditingComplete: widget.onEditingComplete,
      enabled: widget.enabled,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.phone,
      cursorColor: widget.cursorColor,
      decoration: _getEffectiveDecoration(),
    );
  }

  Widget _inkWellOverlay() {
    return InkWell(
      onTap: () {},
      onTapDown: (_) => selectCountry(),
      // we make the country dial code
      // invisible but we still have to put it here
      // to have the correct width
      child: Opacity(
        opacity: 0,
        child: Padding(
          // outline border has padding on the left
          // so we need to make it a 12 bigger
          // and we add 16 horizontally to make it the whole height
          padding: _isOutlineBorder
              ? const EdgeInsets.fromLTRB(12, 16, 0, 16)
              : const EdgeInsets.fromLTRB(0, 16, 0, 16),
          child: _getDialCodeChip(),
        ),
      ),
    );
  }

  InputDecoration _getEffectiveDecoration() {
    return widget.decoration.copyWith(
      errorText: getErrorText(),
      prefix: _getDialCodeChip(),
    );
  }

  Widget _getDialCodeChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: FlagDialCodeChip(
        country: Country(_isoCode),
        showFlag: widget.showFlagInInput,
        textStyle: TextStyle(fontSize: 16),
        flagSize: 20,
      ),
    );
  }

  // // which error text to show
  String? getErrorText() {
    if (!hasError) return null;
    return PhoneFieldLocalization.of(context)?.translate(widget.errorText) ??
        errorText;
  }
}
