import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sms_to_sheet/pages/widgets/messages.dart';
import 'package:sms_to_sheet/pages/widgets/overview.dart';

class MainPage extends ConsumerWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HipoGora SMS tool'),
        elevation: 10.0,
        centerTitle: false,
        // leading: const Icon(Icons.menu),
        // actions: [
        //   IconButton(
        //     onPressed: () {
        //       // Navigator.pushNamed(context, '/settings');
        //     },
        //     icon: const Icon(Icons.settings),
        //   ),
        // ],
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
