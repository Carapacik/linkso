import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/helpers/regex.dart';
import 'package:linkso/widgets/custom_text_field.dart';

import '../../../controller_instances.dart';

class PasswordTextField extends StatelessWidget {
  const PasswordTextField({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredPassword;
        }
        if (value.length < 6) {
          return AppLocalizations.of(context)!.passwordMustBeMore6;
        }
        if (value.length > 30) {
          return AppLocalizations.of(context)!.passwordMustBeLess30;
        }
        if (!passwordRegex.hasMatch(value)) {
          return AppLocalizations.of(context)!.incorrectPassword;
        }
        return null;
      },
      onSaved: (value) {
        signInPageController.password = value;
      },
      hintText: AppLocalizations.of(context)!.yourPassword,
    );
  }
}
