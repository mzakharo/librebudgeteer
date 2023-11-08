import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'mylabel.dart';
import '../providers/labels.dart';
import '../providers/settings.dart';

enum TransactionType { Income, Expense }

class Transaction {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final String labelId;
  final String? account;

  const Transaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.labelId,
    required this.account,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'labelId': labelId,
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      amount: map['amount'],
      account: map['account'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      labelId: map['labelId'],
    );
  }

  String formattedAmount(BuildContext context) {
    final currencySymbol = Provider.of<Settings>(context).displayedCurrencySymbol;
    var formattedAmount = '$currencySymbol${amount.abs().toStringAsFixed(2)}';
    if (amount < 0) {
      formattedAmount = '-' + formattedAmount;
    }
    return formattedAmount;
  }

  String get formattedDate => DateFormat.yMMMMd().format(date);

  // Have this here so that when outputting a transaction, 2 providers aren't needed.
  MyLabel? getLabel(BuildContext context) {
    final labelsData = Provider.of<Labels>(context, listen: false);
    final label = labelsData.findById(labelId);
    // In case the label gets deleted/can't be found.
    if (label == null) {
      return labelsData.findById(amount > 0 ? Labels.otherIncomeId : Labels.otherExpenseId);
    }
    return label;
  }

  bool get isAfterBeginningOfMonth {
    // The day before the beginning of the month.
    final beginningOfMonth = DateTime(_todaysDate.year, _todaysDate.month, 0);

    return date.isAfter(beginningOfMonth);
  }

  bool get isBeforeBeginningOfMonth {
    // The day before the beginning of the month.
    final beginningOfMonth = DateTime(_todaysDate.year, _todaysDate.month, 1);

    return date.isBefore(beginningOfMonth);
  }

  bool get isBeforeBeginningOfPreviousMonth {
    // The day before the beginning of the month.
    final beginningOfMonth = DateTime(_todaysDate.year, _todaysDate.month - 1, 1);

    return date.isBefore(beginningOfMonth);
  }

  bool get isAfterBeginningOfPreviousMonth {
    // The day before the beginning of the month.
    final beginningOfMonth = DateTime(_todaysDate.year, _todaysDate.month - 1, 0);

    return date.isAfter(beginningOfMonth);
  }

  bool get isAfterBeginningOfPrevPreviousMonth {
    // The day before the beginning of the month.
    final beginningOfMonth = DateTime(_todaysDate.year, _todaysDate.month - 2, 0);

    return date.isAfter(beginningOfMonth);
  }

  bool get isAfterBeginningOfWeek {
    final beginningOfWeek = _todaysDate
        // This gives us the Saturday before the current date. This getter should then include transactions starting
        // Sunday and after.
        .subtract(_todaysDate.weekday != DateTime.sunday ? Duration(days: _todaysDate.weekday + 1) : const Duration(days: 1));

    return date.isAfter(beginningOfWeek);
  }

  bool get isWithin7Days {
    final sevenDaysAgo = _todaysDate.subtract(const Duration(days: 7));

    return date.isAfter(sevenDaysAgo);
  }

  DateTime get _todaysDate {
    final today = DateTime.now();
    // Manually put in the year month and day so time isn't involved.
    return DateTime(today.year, today.month, today.day);
  }
}

List<Transaction> filterTransactionsByLabel(List<Transaction> items, String? labelId) {
  if (labelId == null) {
    return items;
  }
  // Use the getter so transactions are already sorted.
  return items.where((transaction) => transaction.labelId == labelId).toList();
}

double getLabelTotalWithRange(List<Transaction> items, String? id) {
  final labelTransactionsWithRange = filterTransactionsByLabel(items, id);
  return labelTransactionsWithRange.fold<double>(
    0,
    (previousValue, transaction) => previousValue + transaction.amount,
  );
}
