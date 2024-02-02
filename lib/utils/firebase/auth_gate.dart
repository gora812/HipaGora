// import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_ui_auth/firebase_ui_auth.dart';
// import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart';

class FirebaseTools {
  //https://firebase.google.com/codelabs/firebase-auth-in-flutter-apps
  static init() async {
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
  }

  static const _scopes = [
    SheetsApi.spreadsheetsScope,
    DriveApi.driveReadonlyScope
  ];

  static Future<GoogleSignInAccount?> login() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(scopes: _scopes);
    return await googleSignIn.signIn();
  }

  // static get ServiceAccountCredentials2 {
  //   var cp = DefaultFirebaseOptions.currentPlatform;
  //   AuthClient  a;
  //   return ServiceAccountCredentials(
  //     // ,
  //     //
  //     //     "type": "service_account",
  //     //     "project_id": "hipagora",
  //     //     "private_key_id": "d974aac9448ee9968359ce",
  //   );
  // }

  static Future<(DriveApi, SheetsApi)> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.standard(scopes: _scopes);
    final GoogleSignInAccount? googleSignInAccount =
        await googleSignIn.signIn();

    if (googleSignInAccount != null) {
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;
      // final AuthCredential credential = GoogleAuthProvider.credential(
      //   accessToken: googleSignInAuthentication.accessToken,
      //   idToken: googleSignInAuthentication.idToken,
      // );

      // Sign in to Firebase with the Google credentials
      // await FirebaseAuth.instance.signInWithCredential(credential);

      // Get the access token
      String accessToken = googleSignInAuthentication.accessToken!;

      // Use the access token with Google APIs
      var client = authenticatedClient(
        Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken,
              DateTime.now().add(Duration(hours: 1)).toUtc()),
          null,
          [SheetsApi.spreadsheetsScope],
        ),
      );

      return (DriveApi(client), SheetsApi(client));
    }
    throw Exception('signInWithGoogle() failed');
  }
}
//
// const clientId =
//     '218894820427-ufhqm517985c3aa4rm51iuaf5c1qiqvi.apps.googleusercontent.com';
//
// onPressed: () => Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => const AuthGate()),
// ),
// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return SignInScreen(
//             providers: [
//               // EmailAuthProvider(),
//               GoogleProvider(clientId: clientId),
//             ],
//             // headerBuilder: (context, constraints, shrinkOffset) {
//             //   return Padding(
//             //     padding: const EdgeInsets.all(20),
//             //     child: AspectRatio(
//             //       aspectRatio: 1,
//             //       child: Image.asset('assets/flutterfire_300x.png'),
//             //     ),
//             //   );
//             // },
//             subtitleBuilder: (context, action) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: action == AuthAction.signIn
//                     ? const Text('Welcome to HipoGora, please sign in!')
//                     : const Text('Welcome to HipoGora, please sign up!'),
//               );
//             },
//             footerBuilder: (context, action) {
//               return const Padding(
//                 padding: EdgeInsets.only(top: 16),
//                 child: Text(
//                   'By signing in, you agree to our terms and conditions.',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               );
//             },
//           );
//         }
//
//         return ProfileScreen(
//           appBar: AppBar(
//             title: const Text('User Profile'),
//           ),
//           actions: [
//             SignedOutAction((context) {
//               Navigator.of(context).pop();
//             })
//           ],
//           // children: [
//           //   const Divider(),
//           // ]
//         );
//       },
//     );
//   }
// }
