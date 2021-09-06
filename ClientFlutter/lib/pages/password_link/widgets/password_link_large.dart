import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../../controller_instances.dart';
import 'password_form.dart';

class PasswordLinkPageLarge extends StatefulWidget {
  const PasswordLinkPageLarge({Key? key}) : super(key: key);

  @override
  _PasswordLinkPageLargeState createState() => _PasswordLinkPageLargeState();
}

class _PasswordLinkPageLargeState extends State<PasswordLinkPageLarge> {
  @override
  void initState() {
    super.initState();
    final uriBase = Uri.base;
    if (uriBase.pathSegments.length > 1) {
      passwordLinkPageController.key.value = uriBase.pathSegments[1];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PasswordForm(),
          Obx(() {
            final _errorData = passwordLinkPageController.errorMessage.value;
            if (_errorData.isNotEmpty) {
              return Text(_errorData);
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }
}
