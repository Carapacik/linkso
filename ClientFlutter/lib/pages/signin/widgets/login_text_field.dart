import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/helpers/regex.dart';
import 'package:linkso/widgets/custom_text_field.dart';

import '../../../controller_instances.dart';

class LoginTextField extends StatelessWidget {
  const LoginTextField({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      keyboardType: TextInputType.name,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredLogin;
        }
        if (value.length < 3) {
          return AppLocalizations.of(context)!.loginMustBeMore3;
        }
        if (value.length > 20) {
          return AppLocalizations.of(context)!.loginMustBeLess20;
        }
        if (!loginRegex.hasMatch(value)) {
          return AppLocalizations.of(context)!.incorrectLogin;
        }
        return null;
      },
      onSaved: (value) {
        signInPageController.login = value;
      },
      hintText: AppLocalizations.of(context)!.yourLogin,
    );
  }
}
