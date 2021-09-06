import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/widgets/custom_text_field.dart';
import 'package:linkso/widgets/default_button.dart';

import '../../../controller_instances.dart';

class PasswordForm extends StatefulWidget {
  const PasswordForm({Key? key}) : super(key: key);

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController? _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SizedBox(
        width: 500,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _PasswordInputField(controller: _passwordController)),
            const SizedBox(width: 20),
            _SubmitButton(formKey: _formKey),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController?.dispose();
    super.dispose();
  }
}

class _PasswordInputField extends StatelessWidget {
  const _PasswordInputField({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      keyboardType: TextInputType.visiblePassword,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredPassword;
        }
        return null;
      },
      onSaved: (value) {
        passwordLinkPageController.password.value = value!;
      },
      hintText: AppLocalizations.of(context)!.yourPassword,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    Key? key,
    required GlobalKey<FormState> formKey,
  })  : _formKey = formKey,
        super(key: key);

  final GlobalKey<FormState> _formKey;

  @override
  Widget build(BuildContext context) {
    return DefaultButton(
      onPressed: () => passwordLinkPageController.requestAccess(_formKey.currentState!),
      text: AppLocalizations.of(context)!.submit,
    );
  }
}
