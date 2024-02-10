import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sms.dart';
import '../../providers/sms_provider.dart';
import '../../providers/spreadsheet.dart';

class OverviewWidget extends ConsumerWidget {
  const OverviewWidget({super.key});

  static const _cardPadding = EdgeInsets.only(left: 15, right: 15, top: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(SmsProviders.hipotekarna);
    final balance = ref.watch(SmsProviders.hipotekarnaBalance);
    final wasted = ref.watch(SmsProviders.hipotekarnaWasted);
    final lastId = ref.watch(SpreadsheetProvider.spreadsheetLastId);

    var countToUpdate = lastId != null
        ? messages
            .where((msg) => msg.forPublish)
            .where((msg) => msg.id > lastId)
            .length.toString()
        : '⟳';

    return ListView(
      children: [
        Padding(
          padding: _cardPadding,
          child: Card(
            child: ListTile(
              title: const Text('Hipotekarna'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('amount: ${balance}€'),
                  Text('wasted: ${wasted}€'),
                ],
              ),
              // leading: const Icon(CupertinoIcons.money_euro),
              // trailing: const Icon(CupertinoIcons.money_euro),
            ),
          ),
        ),
        Padding(
          padding: _cardPadding,
          child: Card(
            child: ListTile(
              title: const Text('Hipotekarna SMS'),
              subtitle: Column(children: [
                Row(
                  children: [
                    Text('total: ${messages.length}'),
                    const Spacer(flex: 1),
                    Text('to update: ${countToUpdate}'),
                  ],
                ),
                Row(
                  children: [
                    const Spacer(flex: 1),
                    ElevatedButton(
                      onPressed: () async => parseSms(),
                      child: const Text('Update'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.orangeAccent,
                          elevation: 2),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
        ListTile(
          title: const Text('NLB'),
          subtitle: const Text('total: 0'),
          leading: const Icon(CupertinoIcons.money_dollar),
          trailing: const Icon(CupertinoIcons.right_chevron),
        ),
        ListTile(
          title: const Text('Sparkasse'),
          subtitle: const Text('total: 0'),
          leading: const Icon(CupertinoIcons.money_dollar),
          trailing: const Icon(CupertinoIcons.right_chevron),
        ),
      ],
    );
  }

  parseSms() async {
    var provider = SpreadsheetProvider();

    var start = DateTime.now();
    var counter = 0;
    print('Started $start ...');

    var ss = await provider.getSpreadsheet();
    var lastId = SpreadsheetProvider.lastId(ss);

    var messages = await SmsService().hipotekarnaAll;

    var models = messages
        .where((m) => (m.id ?? 0) > lastId)
        .map((m) => SmsModel(m))
        .where((m) => m.forPublish)
        .toList(growable: false)
        .reversed;

    const pageSize = 500;
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
}
