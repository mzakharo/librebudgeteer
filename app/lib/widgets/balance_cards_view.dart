import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './balance_summary_card.dart';
import '../providers/transactions.dart';
import '../utils/custom_colors.dart';

// Used in DashboardScreen.

class BalanceCardsView extends StatefulWidget {
  @override
  _BalanceCardsViewState createState() => _BalanceCardsViewState();
}

class _BalanceCardsViewState extends State<BalanceCardsView> {
  @override
  Widget build(BuildContext context) {
    final transactionsData = Provider.of<Transactions>(context);
    final themeData = Theme.of(context);

    return Container(
      color: themeData.colorScheme.dashboardHeader(context),
      child: Column(
        children: <Widget>[
          SizedBox(
            // This is the height of the BalanceSummaryCard.
            height: 135,
            child: BalanceSummaryCard(
              title: 'Net Balance',
              balance: transactionsData.balance,
            ),
          )
        ],
      ),
    );
  }
}
