import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart';

class GoogleAuthProvider {
  static const _scopes = [SheetsApi.driveFileScope];
  static const _clientId =
      '218894820427-ufhqm517985c3aa4rm51iuaf5c1qiqvi.apps.googleusercontent.com';
  static late SheetsApi? api;

  static DateTime? expiry;

  static Future<SheetsApi> get sheetsApi async {
    if (expiry?.isAfter(DateTime.now()) ?? false) {
      return api!;
    }

    final GoogleSignIn gsi = GoogleSignIn(scopes: _scopes, serverClientId: _clientId);
    final GoogleSignInAccount? account = await gsi.signIn();

    if (account == null) {
      throw Exception('signInWithGoogle() failed');
    }

    final authentication = await account.authentication;

    // Get the access token
    String accessToken = authentication.accessToken!;

    // Use the access token with Google APIs
    expiry = DateTime.now().add(Duration(hours: 1));
    var client = authenticatedClient(
        Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, expiry!.toUtc()),
          null,
          [SheetsApi.spreadsheetsScope],
        ),
        closeUnderlyingClient: true);

    api = SheetsApi(client);
    return api!;
  }

  static logout() async {
    expiry = null;
    api = null;
    await GoogleSignIn.standard(scopes: _scopes).signOut();
  }
}
