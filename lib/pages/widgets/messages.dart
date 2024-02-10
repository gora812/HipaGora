import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sms_to_sheet/models/sms.dart';
import 'package:sms_to_sheet/providers/sms_provider.dart';

class MessagesWidget extends ConsumerWidget {
  const MessagesWidget({super.key});

  static final DateFormat _format = DateFormat("dd.MM.yyyy hh:mm");
  static const _cardPadding = EdgeInsets.only(left: 15, right: 15, top: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(SmsProviders.hipotekarna);
    final Color accentColor = Theme.of(context).primaryColor;

    return CustomScrollView(
      slivers: [
        if (messages.isEmpty || !true)
          SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  height: 70,
                  width: 70,
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.transparent,
                    strokeWidth: 4.0,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ))
        else ...[
          SliverAppBar(
            title: Row(
              children: [
                const Icon(Icons.food_bank),
                Text("Hipotekarna",
                    style: TextStyle(
                        color: accentColor,
                        decoration: TextDecoration.underline)),
                const Spacer(flex: 5),
                Text('total: ${messages.length}'),
              ],
            ),
            floating: true,
            pinned: false,
          ),
          // Next, create a SliverList
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _messageWidget(messages[index]),
              childCount: messages.length,
            ),
          ),
        ] // Add the app bar to the CustomScrollView.
      ],
    );
  }

  Widget _messageWidget(SmsModel message) {
    return Padding(
      padding: _cardPadding,
      child: Card(
        key: ValueKey(message.id),
        child: ListTile(
          title: Text(message.raw),
          subtitle: Column(
            children: [
              Row(children: [
                Text('[id:${message.id}] ${message.type.name}'),
                Spacer(flex: 5),
                Text((message.dateTime == null)
                    ? 'unknown time'
                    : _format.format(message.dateTime!)),
              ]),
              Row(
                children: [
                  Text('amount: ${message.amount} ${message.amountCurrency} '),
                  Text('account: ${message.account} '),
                  Text('status: ${message.status} '),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
