import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linkso/api/google_sign_in.dart';
import 'package:linkso/helpers/routes.dart';
import 'package:linkso/pages/signin/widgets/register_form.dart';
import 'package:linkso/widgets/custom_card_container.dart';

import '../../../controller_instances.dart';
import 'login_form.dart';

class SignInPageLarge extends StatelessWidget {
  const SignInPageLarge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 40),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomCardContainer(
              borderRadius: 40,
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
              margin: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                children: [
                  Obx(() {
                    final registered = signInPageController.registered.value;
                    if (registered) {
                      return const LoginForm();
                    } else {
                      return const RegisterForm();
                    }
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              final errorData = signInPageController.errorMessage.value;
              if (errorData.isNotEmpty) {
                return Text(errorData);
              } else {
                return const SizedBox.shrink();
              }
            }),
            SizedBox(
              width: 150,
              child: ElevatedButton(
                onPressed: signIn,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Google"),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future signIn() async {
    final user = await GoogleSignInApi.login();
    print(user?.email);
    Get.offAllNamed(statRoute);
  }
}
