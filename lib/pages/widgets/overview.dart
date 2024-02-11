import 'dart:io';

import 'package:collection/collection.dart';
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

    var uploadable = messages.where((msg) => msg.forPublish);
    var countToUpdate = lastId != null
        ? messages
            .where((msg) => msg.forPublish)
            .where((msg) => msg.id > lastId)
            .length
            .toString()
        : null;

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
              subtitle: Row(
                children: [
                  Table(
                    // border: TableBorder.all(),
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FixedColumnWidth(45),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(children: [
                        const Text('Total:'),
                        Container(
                            alignment: Alignment.centerRight,
                            child: Text(messages.length.toString())),
                      ]),
                      TableRow(children: [
                        const Text('Uploadable:'),
                        Container(
                            alignment: Alignment.centerRight,
                            child: Text(uploadable.length.toString())),
                      ]),
                      TableRow(children: [
                        const Text('For upload:'),
                        Container(
                            alignment: Alignment.centerRight,
                            child: countToUpdate != null
                                ? Text(countToUpdate)
                                : Text('⟳',
                                    style: const TextStyle(fontSize: 20))),
                      ]),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () async => parseSms(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 2),
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ...accountsTiles(messages),
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

  List<Widget> accountsTiles(List<SmsModel> messages) {
    return messages
        .where((msg) => msg.balance != null)
        .where((msg) => msg.dateTime != null)
        .groupListsBy((msg) => msg.account)
        .values
        .map(
      (messages) {
        SmsModel last = maxBy(messages, (msg) => msg.dateTime!)!;
        return Padding(
            padding: _cardPadding,
            child: Card(
              child: ListTile(
                title: Text(messages.first.account!),
                subtitle: Text(last.balance!.toString()),
                leading: const Icon(CupertinoIcons.money_euro),
                trailing: const Icon(CupertinoIcons.right_chevron),
              ),
            ));
      },
    ).toList(growable: false);
  }
}
