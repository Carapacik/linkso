import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/helpers/regex.dart';
import 'package:linkso/widgets/custom_text_field.dart';

import '../../../controller_instances.dart';

class EmailTextField extends StatelessWidget {
  const EmailTextField({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredEmail;
        }
        if (!emailRegex.hasMatch(value)) {
          return AppLocalizations.of(context)!.incorrectEmail;
        }
        return null;
      },
      onSaved: (value) {
        signInPageController.email = value;
      },
      hintText: AppLocalizations.of(context)!.yourEmail,
    );
  }
}
