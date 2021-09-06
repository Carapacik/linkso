import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:linkso/resources/theme.dart';
import 'package:linkso/widgets/default_button.dart';

import '../../../controller_instances.dart';
import 'login_text_field.dart';
import 'password_text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController? _loginController;
  late TextEditingController? _passwordController;

  @override
  void initState() {
    super.initState();
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
            AppLocalizations.of(context)!.signin,
            style: Theme.of(context).textTheme.b24,
          ),
          const SizedBox(height: 20),
          LoginTextField(controller: _loginController),
          const SizedBox(height: 30),
          PasswordTextField(controller: _passwordController),
          const SizedBox(height: 30),
          DefaultButton(
            onPressed: () => signInPageController.logIn(_formKey.currentState!),
            text: AppLocalizations.of(context)!.login,
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: signInPageController.swapRegistered,
              child: Text(
                AppLocalizations.of(context)!.notYetRegistered,
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
    _loginController?.dispose();
    _passwordController?.dispose();
    super.dispose();
  }
}
