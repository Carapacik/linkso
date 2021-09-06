import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linkso/api/entity/account.dart';
import 'package:linkso/api/remote_data_source.dart';
import 'package:linkso/helpers/routes.dart';

class AccountController extends GetxController {
  static AccountController instance = Get.find();
  final RxBool isAuth = false.obs;
  final _key = 'auth-token';
  late GetStorage _box;

  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();
    _validateTokenOnLoad();
  }

  String? _getTokenFromBox() => _box.read(_key);

  void _saveTokenToBox(String token) => _box.write(_key, token);

  void _deleteTokenFromBox() => _box.write(_key, null);

  Future<void> _validateTokenOnLoad() async {
    final _tokenFromBox = _getTokenFromBox();
    if (_tokenFromBox != null) {
      final _apiResponse = await GetIt.instance.get<RemoteDataSource>().validateToken(_tokenFromBox);
      if (_apiResponse.successResponse) {
        GetIt.instance.get<UserAccount>().token = _tokenFromBox;
        isAuth.value = true;
        return;
      } else {
        _deleteTokenFromBox();
      }
    }
    GetIt.instance.get<UserAccount>().token = null;
    isAuth.value = false;
  }

  Future<void> saveToken(String token) async {
    GetIt.instance.get<UserAccount>().token = token;
    _saveTokenToBox(token);
    isAuth.value = true;
    Get.offAllNamed(statRoute);
  }

  Future<void> logout() async {
    GetIt.instance.get<UserAccount>().token = null;
    _deleteTokenFromBox();
    isAuth.value = false;
    Get.offAllNamed(mainRoute);
  }
}
