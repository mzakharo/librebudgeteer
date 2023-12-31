import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/insights_range.dart';
import '../providers/transactions.dart';

enum LabelType { INCOME, EXPENSE }

class MyLabel {
  final String id;
  final String title;
  final Color color;
  final LabelType labelType;

  const MyLabel({
    required this.id,
    required this.title,
    required this.color,
    required this.labelType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'color': color.value,
      'labelType': labelType.index,
    };
  }

  static MyLabel fromMap(Map<String, dynamic> map) {
    return MyLabel(
      id: map['id'],
      title: map['title'],
      color: Color(map['color']),
      labelType: LabelType.values[map['labelType']],
    );
  }

  double getLabelAmountTotal(BuildContext context) => getLabelTotalWithRange(context, Range.lifetime);

  // From the beginning of the month.
  double getLabelMonthAmountTotal(BuildContext context) => getLabelTotalWithRange(context, Range.month);
  double getLabelPreviousMonthAmountTotal(BuildContext context) => getLabelTotalWithRange(context, Range.previousMonth);
  double getLabelPrevPreviousMonthAmountTotal(BuildContext context) => getLabelTotalWithRange(context, Range.prevpreviousMonth);

  double getLabelTotalWithRange(BuildContext context, Range range) {
    final transactionsData = Provider.of<Transactions>(context, listen: false);
    final labelTransactionsWithRange = transactionsData.filterTransactionsByLabelAndRange(context, id, range);

    return labelTransactionsWithRange.fold<double>(
      0,
      (previousValue, transaction) => previousValue + transaction.amount,
    );
  }
}
