import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart';
import 'package:sms_to_sheet/utils/firebase/firebase_options.dart';

class GoogleAuthProvider extends Notifier<GoogleSignInAccount?> {
  static const _scopes = [
    SheetsApi.driveFileScope,
    DriveApi.driveReadonlyScope
  ];
  static const _clientId =
      '218894820427-ufhqm517985c3aa4rm51iuaf5c1qiqvi.apps.googleusercontent.com';

  static final authentication =
      NotifierProvider<GoogleAuthProvider, GoogleSignInAccount?>(
          () => GoogleAuthProvider._instance);

  static final GoogleAuthProvider _instance = GoogleAuthProvider._internal();

  late final GoogleSignIn _googleSignIn;
  late final GoogleProvider googleProvider;
  late SheetsApi? _api;
  DateTime? _expiry;

  factory GoogleAuthProvider() => _instance;

  /// https://firebase.google.com/codelabs/firebase-auth-in-flutter-apps
  static init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  GoogleAuthProvider._internal() {
    googleProvider = GoogleProvider(
      clientId: _clientId,
      scopes: _scopes,
    );

    _googleSignIn = googleProvider.provider;

    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      state = account;
      if (account != null) {
        final authentication = await account.authentication;

        fb_auth.FirebaseAuth.instance
            .signInWithCredential(
            fb_auth.GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        ));
      }
    });

    _googleSignIn.signInSilently();
  }

  String get clientId => _clientId;

  login() async {
    await _googleSignIn.signIn();
  }

  Future<SheetsApi> get sheetsApi async {
    if ((_expiry?.isAfter(DateTime.now()) ?? false) && _api != null) {
      return _api!;
    }

    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('signInWithGoogle() failed');
    }

    final authentication = await account.authentication;

    // Get the access token
    String accessToken = authentication.accessToken!;

    // Use the access token with Google APIs
    _expiry = DateTime.now().add(const Duration(hours: 1));
    var client = authenticatedClient(
        Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, _expiry!.toUtc()),
          null,
          [SheetsApi.spreadsheetsScope],
        ),
        closeUnderlyingClient: true);

    _api = SheetsApi(client);
    return _api!;
  }

  logout() async {
    _expiry = null;
    _api = null;
    await _googleSignIn.signOut();
  }

  @override
  GoogleSignInAccount? build() => null;
}
