import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import "package:collection/collection.dart";
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

import 'auth_gate.dart';

const allThreads = false;
const Hipotekarna = 'Hipotekarna';
final FToast fToast = FToast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseTools.init();
  runApp(const MyApp());
}

class SmsTools {
  static SmsTools? instance;

  final SmsQuery query = SmsQuery();

  factory SmsTools() {
    instance ??= SmsTools._private();
    return instance!;
  }

  SmsTools._private() {
    var granted = false;
    Permission.sms
        .request()
        .then((status) => granted = status.isGranted)
        .whenComplete(() {
      if (granted) {
        dev.log('Permission was granted', name: 'Permission.sms');
      } else {
        dev.log('Permission was not granted',
            name: 'Permission.sms',
            level: 1000,
            error: 'Permission was not granted');
      }
    });
  }

  Future<List<SmsMessage>> get getAllThreads {
    return query.querySms(kinds: [
      SmsQueryKind.inbox,
    ]).then((messages) => messages
        .groupListsBy((m) => m.threadId ?? -1)
        .values
        .map((messages) => maxBy(messages, (m) => m.time)!)
        .toList(growable: false));
  }

  Future<List<SmsMessage>> get hipotekarnaAll {
    return query.querySms(address: Hipotekarna);
  }

  static const waste_of_funds =
      r"^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$";
  static const waste_of_funds_with_commission =
      r"^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nNaknada: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$";
  static const one_time_password =
      r"^(\d{6}) je jednokratna lozinka za transakciju u iznosu (\w{3}) ([\d.]+), izvrsenu kod (.+)$";
  static const hb_commission =
      r"^Odliv Naplata naknada sa Vaseg racuna broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$";
  static const account_credit =
      r"^Odliv sa Vaseg racuna broj (\d+) na racun (.+) broj (\d*|\s*) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$";
  static const account_debit =
      r"^Priliv sa racuna (.+) broj (\d+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$";
  static const account_debit_extra =
      r"^Priliv od (.+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$";
}

extension on SmsMessage {
  int get time => (dateSent?.millisecondsSinceEpoch ?? 0) > 1E11 // 2001
      ? dateSent!.millisecondsSinceEpoch
      : date?.millisecondsSinceEpoch ?? 0;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // @override
  // void initState() {
  //   super.initState();
  //   fToast = FToast();
  //   // if you want to use context from globally instead of content we need to pass navigatorKey.currentContext!
  //   fToast.init(context);
  // }

  @override
  Widget build(BuildContext context) {
    fToast.init(context);
    return MaterialApp(
      title: 'Hipotekarna SMS tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'SMS Addresses'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SmsMessage>? messages;

  _HomePageState() {
    _init();
  }

  Future<void> _init() async {
    _smsPermissionWidget();

    messages = allThreads
        ? await SmsTools().getAllThreads
        : await SmsTools().hipotekarnaAll;
    setState(() {});
  }

  _smsPermissionWidget() {
    var granted = false;
    Permission.sms
        .request()
        .then((status) => granted = status.isGranted)
        .whenComplete(() {
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.sms_failed,
                      color: Colors.red,
                    )),
                Text('SMS permission denied!'),
              ])),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: messages != null
          ? ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages!.length,
              itemBuilder: (ctx, i) => _messageWidget(messages![i]))
          : const Text("Loading..."),
      floatingActionButton: FloatingActionButton(
        // onPressed: () => saveToFile(messages ?? []),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
        ),
        tooltip: 'Increment',
        child: (messages?.length ?? -1) > 0
            ? Text('${messages!.length}')
            : const Icon(Icons.add),
      ),
    );
  }

  ListTile _messageWidget(SmsMessage msg) {
    return ListTile(
      title: Text('[${msg.id}] ${msg.address}'),
      subtitle: Text('''
${msg.body}
dateSent:${msg.dateSent}
date:${msg.date}
read:${msg.read}
kind:${msg.kind}
id:${msg.id}
'''),
    );
  }
}

saveToFile(List<SmsMessage> messages) async {
  final params = SaveFileDialogParams(
    fileName: "${Hipotekarna}_${DateTime.now().millisecondsSinceEpoch}.json",
    localOnly: true,
    data: Uint8List.fromList(
        utf8.encode(jsonEncode(messages.map((m) => m.toMap).toList()))),
  );
  final filePath = await FlutterFileDialog.saveFile(params: params);
  print(filePath);
  fToast.showToast(
    child: Text("$filePath"),
    toastDuration: const Duration(seconds: 5),
  );
  //
  // // await _checkPermission();
  // String _localPath = (await ExtStorage.getExternalStoragePublicDirectory(
  //     ExtStorage.DIRECTORY_DOWNLOADS))!;
  // String filePath =
  // _localPath + "/" + fileName.trim() + "_" + Uuid().v4() + extension;
  //
  // File fileDef = File(filePath);
  // await fileDef.create(recursive: true);
  // Uint8List bytes = await file.readAsBytes();
  // await fileDef.writeAsBytes(bytes);
}
