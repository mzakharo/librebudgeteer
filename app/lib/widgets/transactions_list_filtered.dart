import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';

import '../card_items/transaction_card.dart';
import '../providers/transactions.dart';
import '../providers/labels.dart';
import '../providers/insights_range.dart';
import '../screens/transaction_details_screen.dart';
import '../utils/custom_colors.dart';

// Used in HistoryScreen.

class TransactionsListFiltered extends StatelessWidget {
  TransactionsListFiltered(this.filterLabelId, this.range);
  final Range range;
  final String filterLabelId;
  SliverList buildEmptyListMessage(String message) {
    return SliverList(
      delegate: SliverChildListDelegate(
        <Widget>[
          const SizedBox(height: 20),
          Center(
            child: Text(message),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsData = Provider.of<Transactions>(context);
    final labelsData = Provider.of<Labels>(context, listen: false);
    var label = labelsData.findById(filterLabelId);
    var filteredTransactions;
    if (label == null) {
      filteredTransactions = transactionsData.filterTransactionsByRange(range);
    } else {
      filteredTransactions = transactionsData.filterTransactionsByLabelAndRange(context, filterLabelId, range);
    }

    if (transactionsData.items.isEmpty) {
      return buildEmptyListMessage('No transactions for this filter!');
    }

    if (filteredTransactions.isEmpty) {
      return buildEmptyListMessage('No transactions for this filter!');
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Column(
            children: <Widget>[
              OpenContainer(
                closedColor: Theme.of(context).colorScheme.transactionCards(context),
                openColor: Theme.of(context).colorScheme.surface,
                closedShape: const BeveledRectangleBorder(),
                closedElevation: 0,
                closedBuilder: (_, __) {
                  return TransactionCard(
                    transaction: filteredTransactions[index],
                  );
                },
                openBuilder: (_, __) {
                  return TransactionDetailsScreen(
                    transactionId: filteredTransactions[index].id,
                  );
                },
              ),
              const Divider(height: 1),
            ],
          );
        },
        childCount: filteredTransactions.length,
      ),
    );
  }
}
