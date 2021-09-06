import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/resources/theme.dart';
import 'package:linkso/widgets/default_button.dart';

import '../../../controller_instances.dart';
import 'email_text_field.dart';
import 'login_text_field.dart';
import 'password_text_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({Key? key}) : super(key: key);

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController? _emailController;
  late TextEditingController? _loginController;
  late TextEditingController? _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _loginController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.register,
            style: Theme.of(context).textTheme.b24,
          ),
          const SizedBox(height: 20),
          EmailTextField(controller: _emailController),
          const SizedBox(height: 30),
          LoginTextField(controller: _loginController),
          const SizedBox(height: 30),
          PasswordTextField(controller: _passwordController),
          const SizedBox(height: 30),
          DefaultButton(
            onPressed: () => signInPageController.register(_formKey.currentState!),
            text: AppLocalizations.of(context)!.register,
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: signInPageController.swapRegistered,
              child: Text(
                AppLocalizations.of(context)!.alreadyRegistered,
                style: Theme.of(context).textTheme.m18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController?.dispose();
    _loginController?.dispose();
    _passwordController?.dispose();
    super.dispose();
  }
}
