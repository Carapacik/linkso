import 'package:flutter/material.dart';
import 'package:linkso/widgets/custom_scaffold.dart';

import 'widgets/signin_large.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      largeScreen: const SignInPageLarge(),
    );
  }
}
