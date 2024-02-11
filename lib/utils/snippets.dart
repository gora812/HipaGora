// import 'package:googleapis/drive/v3.dart';
// import 'package:googleapis/sheets/v4.dart';
// Future<(DriveApi, SheetsApi)> signInWithGoogle() async {
//   throw Exception('not implemented');
// }
// listSpreadsheets() async {
//   var (DriveApi drive, SheetsApi sheets) = await signInWithGoogle();
//   print('00 ${sheets}');
//
//   drive.files
//       .list(
//     corpora: 'user',
//     q: "'me' in owners and mimeType='application/vnd.google-apps.spreadsheet'",
//     spaces: 'drive',
//     orderBy: 'modifiedTime desc',
//     $fields: 'files(id, name)',
//     pageSize: 100,
//   )
//       .then((list) {
//     print('1 ${list.toJson()}');
//     list.files?.forEach((file) {
//       // file.
//       print('${file.toJson()}');
//     });
//   });
// }

//
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
