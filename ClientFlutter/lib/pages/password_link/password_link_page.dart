import 'package:flutter/material.dart';
import 'package:linkso/widgets/custom_scaffold.dart';

import 'widgets/password_link_large.dart';

class PasswordLinkPage extends StatelessWidget {
  const PasswordLinkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      largeScreen: const PasswordLinkPageLarge(),
    );
  }
}
