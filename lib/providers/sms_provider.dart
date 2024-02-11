import 'dart:developer' as dev;

import "package:collection/collection.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:sms_to_sheet/models/sms.dart';

const _hipotekarna = 'Hipotekarna';

abstract interface class SmsProviders {
  static final hipotekarna =
      NotifierProvider<SmsList, List<SmsModel>>(SmsList.new);

  static final hipotekarnaBalance = Provider<double?>((ref) => ref
      .watch(hipotekarna)
      .firstWhereOrNull((msg) => msg.balance != null)
      ?.balance);

  static final hipotekarnaWasted = Provider<double?>((ref) => ref
      .watch(hipotekarna)
      .reversed
      .takeWhile((msg) =>
          msg.type != SmsType.accountDebit ||
          msg.type != SmsType.accountDebitExtra)
      .where((msg) => msg.type.waste != null)
      .fold(
          0.0,
          (value, msg) =>
              value! +
              (msg.amount ?? 0) * (msg.type.waste! ? -1 : 1) -
              (msg.fee ?? 0)));
}

class SmsList extends Notifier<List<SmsModel>> {
  final SmsService _smsService = SmsService();

  SmsList() {
    _init();
  }

  Future<void> _init() async {
    await _smsPermissionWidget();
    state = await _smsService.hipotekarnaAll
        .asStream()
        .expand((messages) => messages)
        .map((message) => SmsModel(message))
        .toList();
  }

  _smsPermissionWidget() {
    permission.Permission.sms.request().then((status) => status.isGranted
        ? dev.log('Permission was granted', name: 'Permission.sms')
        : dev.log('Permission was not granted',
            name: 'Permission.sms',
            level: 1000,
            error: 'Permission was not granted'));
  }

  // _smsPermissionWidget() {
  //   var granted = false;
  //   permission.Permission.sms
  //       .request()
  //       .then((status) => granted = status.isGranted)
  //       .whenComplete(() {
  //     if (!granted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //             duration: Duration(minutes: 15),
  //             content: Row(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: <Widget>[
  //                   Padding(
  //                       padding: EdgeInsets.all(8),
  //                       child: Icon(
  //                         Icons.sms_failed,
  //                         color: Colors.red,
  //                       )),
  //                   Text('SMS permission denied!'),
  //                 ])),
  //       );
  //     }
  //   });
  // }

  @override
  List<SmsModel> build() => [];
}

class SmsService {
  static SmsService? instance;

  final SmsQuery query = SmsQuery();

  factory SmsService() {
    instance ??= SmsService._private();
    return instance!;
  }

  SmsService._private() {
    var granted = false;
    permission.Permission.sms
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

  @Deprecated("research code")
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
    return query.querySms(address: _hipotekarna);
  }
}
