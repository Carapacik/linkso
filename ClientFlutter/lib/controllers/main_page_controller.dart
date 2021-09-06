import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:linkso/api/remote_data_source.dart';
import 'package:linkso/model/link_create_request.dart';

class MainPageController extends GetxController {
  static MainPageController instance = Get.find();

  final RxBool checkBool = false.obs;
  RxString receivedLinkKey = "".obs;
  RxString errorMessage = "".obs;
  String targetLink = "";
  String? passwordLink;

  final baseUri = "http://localhost:8080";

  Future<void> getResultKey(FormState form) async {
    if (form.validate()) {
      form.save();
      final _apiResponse = await GetIt.instance.get<RemoteDataSource>().createLink(
            LinkCreateRequest(
              target: targetLink,
              password: passwordLink,
              linkType: checkBool.value ? 1 : 0,
            ),
          );
      if (_apiResponse.successResponse) {
        receivedLinkKey.value = _apiResponse.data!.key;
      } else {
        errorMessage.value = _apiResponse.error!.message;
      }
    }
  }

  void changeCheckBoolValue() {
    checkBool.value = !checkBool.value;
  }
}
