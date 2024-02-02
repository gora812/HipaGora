import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:sms_to_sheet/providers/google_auth.dart';
import 'package:sms_to_sheet/providers/sms_provider.dart';
import 'package:sms_to_sheet/providers/spreadsheet.dart';

const allThreads = false;
final FToast fToast = FToast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ? await SmsService().getAllThreads
        : await SmsService().hipotekarnaAll;
    setState(() {});
  }

  _smsPermissionWidget() {
    var granted = false;
    permission.Permission.sms
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
        actions: [
          IconButton(
            onPressed: () async {
              SpreadsheetProvider().clean();
              return await GoogleAuthProvider.logout();
            },
            icon: const Icon(Icons.login),
          ),
        ],
      ),
      body: messages != null
          ? ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages!.length,
              itemBuilder: (ctx, i) => _messageWidget(messages![i]))
          : const Text("Loading..."),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => parse_sms(),
        // onPressed: () async => await GoogleAuthProvider.sheetsApi,
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

parse_sms() async {
  var provider = SpreadsheetProvider();

  var start = DateTime.now();
  var counter = 0;
  print('Started $start ...');

  var ss = await provider.getSpreadsheet();
  var lastId = SpreadsheetProvider.lastId(ss) ?? 0;

  var messages = await SmsService().hipotekarnaAll;

  var models = messages
      .where((m) => (m.id ?? 0) > lastId)
      .map((m) => SmsModel(m))
      .where((m) => m.forPublish)
      .toList(growable: false)
      .reversed;

  const pageSize = 300;
  while (models.isNotEmpty) {
    var rows = models.take(pageSize);
    await provider.addRows(rows);
    sleep(const Duration(seconds: 1));
    models = models.skip(pageSize);
    print('Added ${counter += rows.length} rows');
  }
  print('Finished ${DateTime.now().difference(start)}');
  print('Finished ${DateTime.now()}');
  print(ss.spreadsheetUrl);
}
