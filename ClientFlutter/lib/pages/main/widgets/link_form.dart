import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:linkso/helpers/regex.dart';
import 'package:linkso/helpers/responsiveness.dart';
import 'package:linkso/widgets/custom_text_field.dart';
import 'package:linkso/widgets/default_button.dart';

import '../../../controller_instances.dart';
import 'password_check_box.dart';

class LinkForm extends StatefulWidget {
  const LinkForm({Key? key}) : super(key: key);

  @override
  State<LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends State<LinkForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController? _linkController;
  late TextEditingController? _passwordController;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ResponsiveWidget.isSmallScreen(context)
          ? Column(
              children: [
                _LinkInputField(controller: _linkController),
                const SizedBox(height: 20),
                _ShortenButton(formKey: _formKey),
                const PasswordCheckBox(),
                Obx(() {
                  if (mainPageController.checkBool.value) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _PasswordInputField(controller: _passwordController),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
              ],
            )
          : Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _LinkInputField(controller: _linkController)),
                    const SizedBox(width: 20),
                    _ShortenButton(formKey: _formKey),
                  ],
                ),
                const PasswordCheckBox(),
                Obx(() {
                  if (mainPageController.checkBool.value) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _PasswordInputField(controller: _passwordController),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _linkController?.dispose();
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
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredPassword;
        }
        return null;
      },
      onSaved: (value) {
        mainPageController.passwordLink = value;
      },
      hintText: AppLocalizations.of(context)!.yourPassword,
    );
  }
}

class _LinkInputField extends StatelessWidget {
  const _LinkInputField({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      validator: (value) {
        if (value!.isEmpty) {
          return AppLocalizations.of(context)!.requiredLink;
        }
        if (!linkRegex.hasMatch(value)) {
          return AppLocalizations.of(context)!.incorrectLink;
        }
        // TODO: проверка ссылка с нашего сайта
        return null;
      },
      onSaved: (value) {
        mainPageController.targetLink = value!;
      },
      hintText: AppLocalizations.of(context)!.yourLink,
    );
  }
}

class _ShortenButton extends StatelessWidget {
  const _ShortenButton({
    Key? key,
    required GlobalKey<FormState> formKey,
  })  : _formKey = formKey,
        super(key: key);

  final GlobalKey<FormState> _formKey;

  @override
  Widget build(BuildContext context) {
    return DefaultButton(
      onPressed: () => mainPageController.getResultKey(_formKey.currentState!),
      text: AppLocalizations.of(context)!.shorten,
    );
  }
}
