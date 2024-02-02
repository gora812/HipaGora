import 'dart:developer' as dev;

import "package:collection/collection.dart";
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

const _hipotekarna = 'Hipotekarna';
final DateFormat _hbFormat = DateFormat("dd.MM.yyyy hh:mm:ss");
final DateFormat _format = DateFormat("yy-MM-dd hh:mm");
// final DateFormat _format = DateFormat("yyyy-MM-ddThh:mm:ss");
final NumberFormat _numberFormat = NumberFormat.decimalPattern('en-US');

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

extension on SmsMessage {
  static final DateTime _null = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime get time => (dateSent?.millisecondsSinceEpoch ?? 0) > 1E11 // 2001
      ? dateSent!
      : date ?? _null;
}

extension on String {
  double toDecimal() {
    var split = replaceAll(',', '.').split('.');
    if (split.length == 1) return double.tryParse(this) ?? 0;
    var cents = split.removeLast();
    var dollars = split.join();
    return double.tryParse('$dollars.$cents') ?? 0;
  }
}

class SmsModel {
  static const smsIdTitle = 'Sms ID';
  static const titles = [
    'Date Time',
    'Amount',
    'Amount\nCurrency',
    'Account',
    'Balance',
    'Balance\nCurrency',
    'Status',
    'Status\nFactor',
    'Counterparty',
    'CP\nLocation',
    'CP\nCountry',
    'CP\nAccount',
    'Fee',
    'Fee\nCurrency',
    'Account\nAmount',
    'Account\nCunensy',
    'Exchange\nRate',
    smsIdTitle,
    'Type',
    'Raw'
  ];

  //region RegExp
  static final _waste_of_funds = RegExp(
      r"^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$");
  static final _waste_of_funds_fee = RegExp(
      r"^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nNaknada: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$");
  static final _one_time_password = RegExp(
      r"^(\d{6}) je jednokratna lozinka za transakciju u iznosu (\w{3}) ([\d.]+), izvrsenu kod (.+)$");
  static final _hb_commission = RegExp(
      r"^Odliv Naplata naknada sa Vaseg racuna broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$");
  static final _account_credit = RegExp(
      r"^Odliv sa Vaseg racuna broj (\d+) na racun (.+) broj (\d*|\s*) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$");
  static final _account_debit = RegExp(
      r"^Priliv sa racuna (.+) broj (\d+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$");
  static final _account_debit_extra = RegExp(
      r"^Priliv od (.+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$");

  static final mapping = [
    (_waste_of_funds, (sms, m) => _SmsWasteOfFunds(sms, m)),
    (_waste_of_funds_fee, (sms, m) => _SmsWasteOfFundsFee(sms, m)),
    (_one_time_password, (sms, m) => _SmsOneTimePassword(sms, m)),
    (_hb_commission, (sms, m) => _SmsHbCommission(sms, m)),
    (_account_credit, (sms, m) => _SmsAccountCredit(sms, m)),
    (_account_debit, (sms, m) => _SmsAccountDebit(sms, m)),
    (_account_debit_extra, (sms, m) => _SmsAccountDebitExtra(sms, m))
  ];

  //endregion

  // region Properties
  late final String raw;
  late final int id;

  DateTime? dateTime;

  double? amount;
  String? amountCurrency;
  String? account;
  double? balance;
  String? balanceCurrency;
  String? status;
  double? statusFactor;
  String? counterparty;
  String? counterpartyLocation;
  String? counterpartyCountry;
  String? counterpartyAccount;
  double? fee;
  String? feeCurrency;
  double? accountAmount;
  String? accountCurrency;
  double? exchangeRate;

  late final String type;

  //
  late final bool forPublish;

  RegExpMatch? _match;

  // endregion

  factory SmsModel(SmsMessage message) {
    final text = message.body!;
    var match = mapping.map((pair) {
      final match = (pair.$1).firstMatch(text);
      return (match != null) ? pair.$2(message, match) : null;
    }).firstOrNull;

    return match ?? SmsModel._(message, null);
  }

  SmsModel._private(SmsMessage message, RegExpMatch? match) {
    id = message.id!;
    raw = message.body!;
    dateTime = message.time;
    _match = match;
  }

  SmsModel._(SmsMessage message, RegExpMatch? match) {
    raw = message.body!;
    dateTime = message.time;
    _match = match;
    type = "Unknown";
    forPublish = false;
  }

  static final _cpParser =
      RegExp(r"^(\S+(?: \S+)+)\s{2,}(\S*)\s{2,}(\w{2,3})$");

  counterpartyParser(String value) {
    var cpMatch = _cpParser.firstMatch(value);
    if (cpMatch != null) {
      counterparty = cpMatch.group(1);
      counterpartyLocation = cpMatch.group(2);
      counterpartyCountry = cpMatch.group(3);
    } else
      counterparty = value;
  }

  // _number(double? value) => value == null ? "" : _numberFormat.format(value);
  _number(double? value) => value;

  List getRow() {
    return [
      dateTime,
      _number(amount),
      amountCurrency,
      account,
      _number(balance),
      balanceCurrency,
      status,
      _number(statusFactor),
      counterparty,
      counterpartyLocation,
      counterpartyCountry,
      counterpartyAccount,
      _number(fee),
      feeCurrency,
      _number(accountAmount),
      accountCurrency,
      _number(exchangeRate),
      id,
      type,
      raw
    ];
  }
}

class _SmsWasteOfFunds extends SmsModel {
  //r"^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$");
  _SmsWasteOfFunds(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "WasteOfFunds";
    forPublish = true;

    account = _match!.group(1);
    amount = _match!.group(2)!.toDecimal();
    amountCurrency = _match!.group(3);
    dateTime = _hbFormat.parse(_match!.group(4)!);
    status = _match!.group(5);
    statusFactor = status == "ODOBRENO" ? 1 : 0;

    counterpartyParser(_match!.group(6)!);

    balance = _match!.group(7)!.toDecimal();
    balanceCurrency = _match!.group(8);
  }
}

class _SmsWasteOfFundsFee extends SmsModel {
  //^Kartica: (\d+)\nIznos: (-?[\d.,]+) (\w{3})\nNaknada: (-?[\d.,]+) (\w{3})\nVrijeme: ([\d:. ]+)\nStatus: (.+)\nOpis: (.+)\nRaspolozivo: ([\d.,]+) (\w{3})$")
  _SmsWasteOfFundsFee(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "WasteOfFundsFee";
    forPublish = true;

    account = _match!.group(1);
    amount = _match!.group(2)!.toDecimal();
    amountCurrency = _match!.group(3);
    fee = _match!.group(4)!.toDecimal();
    feeCurrency = _match!.group(5);
    dateTime = _hbFormat.parse(_match!.group(6)!);
    status = _match!.group(7);
    statusFactor = status == "ODOBRENO" ? 1 : 0;

    counterpartyParser(_match!.group(8)!);

    balance = _match!.group(9)!.toDecimal();
    balanceCurrency = _match!.group(10);
  }
}

class _SmsOneTimePassword extends SmsModel {
  //^(\d{6}) je jednokratna lozinka za transakciju u iznosu (\w{3}) ([\d.]+), izvrsenu kod (.+)$
  _SmsOneTimePassword(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "OneTimePassword";
    forPublish = false;
  }
}

class _SmsHbCommission extends SmsModel {
  //^Odliv Naplata naknada sa Vaseg racuna broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$
  _SmsHbCommission(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "HbCommission";
    forPublish = true;

    account = _match!.group(1);
    amount = _match!.group(2)!.toDecimal();
    amountCurrency = _match!.group(3);
    balance = _match!.group(4)!.toDecimal();
    balanceCurrency = _match!.group(5);
  }
}

class _SmsAccountCredit extends SmsModel {
  //^Odliv sa Vaseg racuna broj (\d+) na racun (.+) broj (\d*|\s*) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$
  _SmsAccountCredit(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "AccountCredit";
    forPublish = true;

    account = _match!.group(1);
    counterparty = _match!.group(2);
    counterpartyAccount = _match!.group(3);
    amount = _match!.group(4)!.toDecimal();
    amountCurrency = _match!.group(5);
    balance = _match!.group(6)!.toDecimal();
    balanceCurrency = _match!.group(7);
  }
}

class _SmsAccountDebit extends SmsModel {
  //^Priliv sa racuna (.+) broj (\d+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$
  _SmsAccountDebit(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "AccountDebit";
    forPublish = true;

    counterparty = _match!.group(1);
    counterpartyAccount = _match!.group(2);
    account = _match!.group(3);
    amount = _match!.group(4)!.toDecimal();
    amountCurrency = _match!.group(5);
    balance = _match!.group(6)!.toDecimal();
    balanceCurrency = _match!.group(7);
  }
}

class _SmsAccountDebitExtra extends SmsModel {
  //^Priliv od (.+) na Vas racun broj (\d+) u iznosu od ([\d.,]+) (\w{3})\. Raspolozivo: ([\d.,]+) (\w{3})\.$
  _SmsAccountDebitExtra(SmsMessage message, RegExpMatch match)
      : super._private(message, match) {
    type = "AccountDebitExtra";
    forPublish = true;

    counterparty = _match!.group(1);
    account = _match!.group(2);
    amount = _match!.group(3)!.toDecimal();
    amountCurrency = _match!.group(4);
    balance = _match!.group(5)!.toDecimal();
    balanceCurrency = _match!.group(6);
  }
}
