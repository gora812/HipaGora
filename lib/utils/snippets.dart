import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart';


import 'firebase/auth_gate.dart';


const _scopes = [
  SheetsApi.spreadsheetsScope,
  DriveApi.driveReadonlyScope
];

Future<(DriveApi, SheetsApi)> signInWithGoogle() async {
  final GoogleSignIn googleSignIn = GoogleSignIn.standard(scopes: _scopes);
  final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

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

listSpreadsheets() async {
  var (drive, sheets) = await signInWithGoogle();
  print('00 ${sheets}');

  drive.files
      .list(
    corpora: 'user',
    q: "'me' in owners and mimeType='application/vnd.google-apps.spreadsheet'",
    spaces: 'drive',
    orderBy: 'modifiedTime desc',
    $fields: 'files(id, name)',
    pageSize: 100,
  )
      .then((list) {
    print('1 ${list.toJson()}');
    list.files?.forEach((file) {
      // file.
      print('${file.toJson()}');
    });
  });
}

// saveToFile(List<SmsMessage> messages) async {
//   final params = SaveFileDialogParams(
//     fileName: "${Hipotekarna}_${DateTime.now().millisecondsSinceEpoch}.json",
//     localOnly: true,
//     data: Uint8List.fromList(
//         utf8.encode(jsonEncode(messages.map((m) => m.toMap).toList()))),
//   );
//   final filePath = await FlutterFileDialog.saveFile(params: params);
//   print(filePath);
//   fToast.showToast(
//     child: Text("$filePath"),
//     toastDuration: const Duration(seconds: 5),
//   );
// }