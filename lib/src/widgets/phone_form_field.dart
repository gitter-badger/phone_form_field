import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:phone_form_field/src/models/phone_number_input.dart';
import 'package:phone_form_field/src/widgets/base_phone_form_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

typedef PhoneController = ValueNotifier<PhoneNumber?>;

class PhoneFormField extends StatefulWidget {
  final PhoneNumber? initialValue;
  final PhoneController? controller;
  final String errorText;
  final PhoneNumberType? phoneNumberType;
  final bool withHint;
  final bool enabled;
  final bool autofocus;
  final bool showFlagInInput;
  final String defaultCountry;
  final CountrySelectorNavigator selectorNavigator;
  final Function(PhoneNumber?)? onChanged;
  final Function(PhoneNumber?)? onSaved;
  final InputDecoration decoration;
  final AutovalidateMode autovalidateMode;
  final bool lightParser;

  PhoneFormField({
    Key? key,
    this.initialValue,
    this.controller,
    this.phoneNumberType,
    this.errorText = 'Invalid phone number',
    this.withHint = true,
    this.autofocus = false,
    this.enabled = true,
    this.showFlagInInput = true,
    this.selectorNavigator = const BottomSheetNavigator(),
    this.onChanged,
    this.onSaved,
    this.defaultCountry = 'US',
    this.decoration = const InputDecoration(border: UnderlineInputBorder()),
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.lightParser = false,
  }) : super(key: key);

  @override
  _PhoneFormFieldState createState() => _PhoneFormFieldState();
}

class _PhoneFormFieldState extends State<PhoneFormField> {
  late final BasePhoneParser parser;
  late final PhoneController controller;
  late final ValueNotifier<SimplePhoneNumber?> baseController;

  @override
  void initState() {
    super.initState();
    parser = widget.lightParser ? LightPhoneParser() : PhoneParser();
    controller = widget.controller ?? PhoneController(widget.initialValue);
    baseController = ValueNotifier(null);
    baseController
        .addListener(() => _onBaseControllerChange(baseController.value));
    controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    super.dispose();
    baseController.dispose();
    // dispose the controller only when it's initialised in this instance
    // otherwise this should be done where instance is created
    if (widget.controller == null) {
      controller.dispose();
    }
  }

  void _onControllerChange() {
    final simplePhone = baseController.value;
    final phone = controller.value;
    widget.onChanged?.call(controller.value);
    if (simplePhone?.national == phone?.nsn &&
        simplePhone?.isoCode == phone?.isoCode) {
      return;
    }
    baseController.value = _convertPhoneNumberToSimplePhoneNumber(phone);
  }

  void _onBaseControllerChange(SimplePhoneNumber? simplePhone) {
    if (simplePhone?.national == controller.value?.nsn &&
        simplePhone?.isoCode == controller.value?.isoCode) {
      return;
    }
    if (simplePhone == null) {
      return controller.value = null;
    }
    // we convert the simple phone number to a full blown PhoneNumber
    // to access validation, formatting etc.
    PhoneNumber phoneNumber;
    // when the base input change we check if its not a whole number
    // to allow for copy pasting and auto fill. If it is one then
    // we parse it accordingly
    if (simplePhone.national.startsWith(RegExp('[+＋]'))) {
      // if starts with + then we parse the whole number
      // to figure out the country code
      phoneNumber = parser.parseRaw(simplePhone.national);
    } else {
      phoneNumber = parser.parseWithIsoCode(
        simplePhone.isoCode,
        simplePhone.national,
      );
    }
    controller.value = phoneNumber;
    baseController.value = SimplePhoneNumber(
        isoCode: phoneNumber.isoCode, national: phoneNumber.nsn);
  }

  SimplePhoneNumber? _convertPhoneNumberToSimplePhoneNumber(
      PhoneNumber? phoneNumber) {
    if (phoneNumber == null) return null;
    return SimplePhoneNumber(
        isoCode: phoneNumber.isoCode, national: phoneNumber.nsn);
  }

  PhoneNumber? _convertInputToPhoneNumber(SimplePhoneNumber? phoneNumberInput) {
    if (phoneNumberInput == null) return null;
    return PhoneNumber(
        isoCode: phoneNumberInput.isoCode, nsn: phoneNumberInput.national);
  }

  String? _validate(SimplePhoneNumber? phoneNumberInput) {
    final phoneNumber = _convertInputToPhoneNumber(phoneNumberInput);
    if (phoneNumber == null) return null;
    if (phoneNumber.nsn.isEmpty) return null;
    final isValid = parser.validate(phoneNumber, widget.phoneNumberType);
    if (!isValid) return widget.errorText;
  }

  @override
  Widget build(BuildContext context) {
    return BasePhoneFormField(
      controller: baseController,
      validator: _validate,
      initialValue: _convertPhoneNumberToSimplePhoneNumber(widget.initialValue),
      onChanged: _onBaseControllerChange,
      onSaved: (inp) => widget.onSaved?.call(_convertInputToPhoneNumber(inp)),
      autoFillHints: widget.withHint ? [AutofillHints.telephoneNumber] : null,
      onEditingComplete:
          widget.withHint ? () => TextInput.finishAutofillContext() : null,
      enabled: widget.enabled,
      showFlagInInput: widget.showFlagInInput,
      autovalidateMode: widget.autovalidateMode,
      decoration: widget.decoration,
      autofocus: widget.autofocus,
      defaultCountry: widget.defaultCountry,
      selectorNavigator: widget.selectorNavigator,
    );
  }
}
