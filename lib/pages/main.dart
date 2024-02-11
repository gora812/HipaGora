import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sms_to_sheet/pages/widgets/messages.dart';
import 'package:sms_to_sheet/pages/widgets/overview.dart';
import 'package:sms_to_sheet/providers/google_auth.dart';

class MainPage extends ConsumerWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoogleSignInAccount? user =
        ref.watch(GoogleAuthProvider.authentication);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HipoGora SMS tool'),
        elevation: 10.0,
        centerTitle: false,
        leading: IconButton(
          icon: user != null
              ? GoogleUserCircleAvatar(identity: user)
              : const Icon(
                  Icons.account_circle_outlined,
                  color: Colors.deepOrange,
                  size: 40.0,
                ),
          onPressed: () => user != null
              ? showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: ProfileScreen(
                      appBar: AppBar(
                        title: const Text('User Profile'),
                      ),
                      providers: [GoogleAuthProvider().googleProvider],
                      actions: [
                        SignedOutAction((context) {
                          Navigator.of(context).pop();
                        }),
                      ],
                    ),
                  ),
                )
              // GoogleAuthProvider().logout()
              : GoogleAuthProvider().login(),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Scaffold(
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'Summary'),
                Tab(icon: Icon(Icons.sms), text: 'Messages'),
              ],
              indicatorPadding: const EdgeInsets.only(bottom: 5.0),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.zero,
                border: Border(
                  top: BorderSide(
                      color: Theme.of(context).primaryColor,
                      //accentColor,
                      width: 3.0),
                ),
              ),
            ),
          ),
          body: const TabBarView(
            children: [OverviewWidget(), MessagesWidget()],
          ),
        ),
      ),
    );
  }
}
