import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import '../chart_models/pie_chart_model.dart';
import '../charts_base/pie_chart_base.dart';
import '../../models/mylabel.dart';
import '../../providers/insights_range.dart';
import '../../providers/labels.dart';
import '../../providers/transactions.dart';
import '../../models/transaction.dart';
import 'package:intl/intl.dart';

class LabelTotal {
  final String title;
  final double amount;
  final Color color;

  const LabelTotal({
    required this.title,
    required this.amount,
    required this.color,
  });
}

class LabelsPieChart extends StatelessWidget {
  final LabelType labelType;

  const LabelsPieChart({
    required this.labelType,
  });

  @override
  Widget build(BuildContext context) {
    final labels = Provider.of<Labels>(context, listen: false);
    final transactionData = Provider.of<Transactions>(context, listen: false);
    final range = Provider.of<InsightsRange>(context).range;
    List<Transaction> transactions =
        transactionData.filterTransactionsByRange(range);

    if (labelType == LabelType.INCOME) {
      transactions =
          transactions.where((transaction) => transaction.amount > 0).toList();
    } else {
      transactions =
          transactions.where((transaction) => transaction.amount < 0).toList();
    }

    final lableAmounts = labels.items.map((label) {
      double amount = getLabelTotalWithRange(transactions, label.id);
      return LabelTotal(
          amount: amount.abs(), color: label.color, title: label.title);
    }).toList();

    // Remove the labels with 0 transactions so there's no extra labels.
    lableAmounts.removeWhere(
      (label) => label.amount == 0,
    );

    // To calculate percentages for the pie chart labels.
    final total = lableAmounts.fold<double>(
      0,
      (previousValue, label) => label.amount + previousValue,
    );

    // Return something suggesting to add transactions if there's nothing to display in the graph.
    if (total == 0) {
      return const Center(
        child: Text(
          'Start adding some transactions!',
          style: TextStyle(fontSize: 15),
        ),
      );
    }

    // Sort labels so the label with the most spending shows up first in the legend (descending order).
    lableAmounts.sort(
      (a, b) {
        return b.amount.compareTo(a.amount);
      },
    );
    var filterlabels = lableAmounts.take(14);

    //filterlabels.forEach((element) => print(element));
    var f = NumberFormat("###,###", "en_US");

    return Container(
      child: Column(
        children: <Widget>[
          Text(
            "\$${f.format(total)}",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              fontSize: 30,
              fontFamily: 'Roboto', // Replace GoogleFonts with built-in font
            ),
          ),
          Expanded(
            child: PieChartBase(
              id: labelType.toString(),
              animated: true,
              showArcLabels: true,
              // For showing the legend.
              behaviors: <charts.ChartBehavior<String>>[
                charts.DatumLegend(
                  position: charts.BehaviorPosition.bottom,
                  // Max stuff so graph itself is visible, and legend doesn't take up too much space.
                  desiredMaxColumns: 2,
                  desiredMaxRows: 3,
                  showMeasures: true,
                  entryTextStyle: charts.TextStyleSpec(fontSize: 10),
                  legendDefaultMeasure: charts.LegendDefaultMeasure.firstValue,
                  measureFormatter: (labelTotal) {
                    return '\$${(f.format(labelTotal!))}';
                  },
                ),
              ],
              pieData: filterlabels
                  .map(
                    (label) => PieChartModel(
                      label: (label.title.length > 11)
                          ? label.title.substring(0, 11)
                          : label.title,
                      amount: label.amount,
                      color: label.color,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
