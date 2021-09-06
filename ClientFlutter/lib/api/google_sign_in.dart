import 'package:google_sign_in/google_sign_in.dart';

//TODO: переделать нормально
class GoogleSignInApi {
  static final _googleSignIn = GoogleSignIn();

  // static const _clientIdWeb = "1088248296524-e36gfrne8m7ur1qieab4327bh0le2q0s.apps.googleusercontent.com";

  static Future<GoogleSignInAccount?> login() => _googleSignIn.signIn();

  static Future logout() => _googleSignIn.disconnect();
}
