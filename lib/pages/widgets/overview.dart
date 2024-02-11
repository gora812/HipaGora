import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final sheetUrl = ref.watch(
        SpreadsheetProvider.spreadsheet.select((ss) => ss?.spreadsheetUrl));
    final isSheetUpdating = ref.watch(SpreadsheetProvider.updating);

    var uploadable = messages.where((msg) => msg.forPublish);
    var countToUpdate = lastId != null
        ? messages
            .where((msg) => msg.forPublish)
            .where((msg) => msg.id > lastId)
            .length
        : null;

    return ListView(
      children: [
        //// Card : Hipotekarna amount
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
        //// Card : Hipotekarna SMS panel
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
                                ? Text(countToUpdate.toString())
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
                        onPressed: () async => await launchUrl(
                            Uri.parse("sms:${SmsModel.hipotekarnaNumber}"),
                            mode: LaunchMode.externalApplication),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 2),
                        child: const Text('Open SMS'),
                      ),
                      // if (countToUpdate != null && countToUpdate > 0)
                      ElevatedButton(
                        onPressed: isSheetUpdating ||
                                countToUpdate == null ||
                                countToUpdate <= 0
                            ? null
                            : () async => parseSms(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 2),
                        child: Stack(
                            alignment: AlignmentDirectional.center,
                            children: [
                              Text('Upload ${countToUpdate ?? 0} sms'),
                              if (isSheetUpdating)
                                const CircularProgressIndicator()
                            ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        //// Card : Sheet panel

        Padding(
          padding: _cardPadding,
          child: Card(
            child: ListTile(
              title: const Text('Google Sheet'),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: isSheetUpdating
                        ? null
                        : () async => await launchUrl(Uri.parse(sheetUrl!),
                            mode: LaunchMode.externalApplication),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2),
                    child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          const Text('Open'),
                          if (isSheetUpdating) const CircularProgressIndicator()
                        ]),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: isSheetUpdating
                        ? null
                        : () async => await ref
                            .read(SpreadsheetProvider.spreadsheet.notifier)
                            .getSpreadsheet(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 2),
                    child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          const Text('Refresh'),
                          if (isSheetUpdating) const CircularProgressIndicator()
                        ]),
                  ),
                ],
              ),
              // leading: const Icon(CupertinoIcons.money_euro),
              // trailing: const Icon(CupertinoIcons.money_euro),
            ),
          ),
        ),
        ...accountsTiles(messages),
      ],
    );
  }

  parseSms() async {
    var provider = SpreadsheetProvider();

    var start = DateTime.now();
    print('Started $start ...');

    await provider.uploadSms(await SmsReaderService().hipotekarnaAll);

    print('Finished ${DateTime.now().difference(start)}');
    print('Finished ${DateTime.now()}');
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
