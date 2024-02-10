import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_to_sheet/pages/main.dart';

const allThreads = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HipoGora SMS tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}
//
// class HomePage extends StatefulWidget {
//   const HomePage({super.key, required this.title});
//
//   final String title;
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   List<SmsMessage>? messages;
//
//   _HomePageState() {
//     _init();
//   }
//
//   Future<void> _init() async {
//     _smsPermissionWidget();
//
//     messages = allThreads
//         ? await SmsService().getAllThreads
//         : await SmsService().hipotekarnaAll;
//     setState(() {});
//   }
//
//   _smsPermissionWidget() {
//     var granted = false;
//     permission.Permission.sms
//         .request()
//         .then((status) => granted = status.isGranted)
//         .whenComplete(() {
//       if (!granted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               duration: Duration(minutes: 15),
//               content: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: <Widget>[
//                 Padding(
//                     padding: EdgeInsets.all(8),
//                     child: Icon(
//                       Icons.sms_failed,
//                       color: Colors.red,
//                     )),
//                 Text('SMS permission denied!'),
//               ])),
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//         actions: [
//           IconButton(
//             onPressed: () async {
//               SpreadsheetProvider().clean();
//               return await GoogleAuthProvider.logout();
//             },
//             icon: const Icon(Icons.login),
//           ),
//         ],
//       ),
//        body: //messages != null
//       //     ? ListView.builder(
//       //         padding: const EdgeInsets.all(8),
//       //         itemCount: messages!.length,
//       //         itemBuilder: (ctx, i) => _messageWidget(messages![i]))
//       //     :
//           const Text("Loading..."),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async => parse_sms(),
//         // onPressed: () async => await GoogleAuthProvider.sheetsApi,
//         tooltip: 'Increment',
//         child: (messages?.length ?? -1) > 0
//             ? Text('${messages!.length}')
//             : const Icon(Icons.add),
//       ),
//     );
//   }
//
//
// }
//
// parse_sms() async {
//   var provider = SpreadsheetProvider();
//
//   var start = DateTime.now();
//   var counter = 0;
//   print('Started $start ...');
//
//   var ss = await provider.getSpreadsheet();
//   var lastId = SpreadsheetProvider.lastId(ss);
//
//   var messages = await SmsService().hipotekarnaAll;
//
//   var models = messages
//       .where((m) => (m.id??0) > lastId)
//       .map((m) => SmsModel(m))
//       .where((m) => m.forPublish)
//       .toList(growable: false)
//       .reversed;
//
//   const pageSize = 500;
//   while (models.isNotEmpty) {
//     var rows = models.take(pageSize);
//     await provider.addRows(rows);
//     sleep(const Duration(seconds: 1));
//     models = models.skip(pageSize);
//     print('Added ${counter += rows.length} rows');
//   }
//   print('Finished ${DateTime.now().difference(start)}');
//   print('Finished ${DateTime.now()}');
//   print(ss.spreadsheetUrl);
// }
