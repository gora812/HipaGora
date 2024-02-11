import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_to_sheet/pages/main.dart';
import 'package:sms_to_sheet/providers/google_auth.dart';

const allThreads = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleAuthProvider.init();
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
      // debugShowCheckedModeBanner: false,
    );
  }
}
