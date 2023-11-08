import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/db_helper.dart';
import '../models/transaction.dart';
import './insights_range.dart';
import './labels.dart';
import '../secrets.dart';
import 'package:influxdb_client/api.dart';

class Transactions with ChangeNotifier {
  var _items = <Transaction>[];
  var total_balance = 0.0;

  List<Transaction> get items {
    // Sort items in non-chronological order.
    _items.sort((a, b) => b.date.compareTo(a.date));
    return [..._items];
  }

  // Add them because incomeTotal will always produce a positive amount
  // while expensesTotal will always produce a negative amount.
  double get balance {
    return total_balance;
  }

  double get monthlyBalance {
    return monthIncomeTotal + monthExpensesTotal;
  }

  double get previousMonthlyBalance {
    return previousMonthIncomeTotal + previousMonthExpensesTotal;
  }

  double get incomeTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount > 0,
    );
  }

  double get expensesTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount < 0,
    );
  }

  double get monthIncomeTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount > 0 && transaction.isAfterBeginningOfMonth,
    );
  }

  double get monthExpensesTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount < 0 && transaction.isAfterBeginningOfMonth,
    );
  }

  double get previousMonthIncomeTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount > 0 && transaction.isAfterBeginningOfPreviousMonth && transaction.isBeforeBeginningOfMonth,
    );
  }

  double get previousMonthExpensesTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount < 0 && transaction.isAfterBeginningOfPreviousMonth && transaction.isBeforeBeginningOfMonth,
    );
  }

  double get prevpreviousMonthExpensesTotal {
    return _totalTransactionsAmountWithFilter(
      (transaction) => transaction.amount < 0 && transaction.isAfterBeginningOfPrevPreviousMonth && transaction.isBeforeBeginningOfPreviousMonth,
    );
  }

  List<Transaction> get sevenDaysTransactions {
    return items.where((transaction) => transaction.isWithin7Days).toList();
  }

  double _totalTransactionsAmountWithFilter(bool Function(Transaction transaction) filter) {
    var transactions = [..._items];
    transactions.retainWhere(filter);

    // This simply totals the amounts from transactions.
    return transactions.fold<double>(
      0,
      (previousValue, transaction) => previousValue + transaction.amount,
    );
  }

  Transaction? findById(String? id) {
    return _items.firstWhereOrNull(
      (transaction) => transaction.id == id,
    );
  }

  List<Transaction> filterTransactionsByLabelAndRange(BuildContext context, String? labelId, Range range) {
    return _internalFilterTransactionsByRange(
      range,
      filterTransactionsByLabel(context, labelId),
    );
  }

  List<Transaction> filterTransactionsByLabel(BuildContext context, String? labelId) {
    if (labelId == null) {
      return items;
    }
    _pruneDeletedLabelIds(context);
    // Use the getter so transactions are already sorted.
    return items.where((transaction) => transaction.labelId == labelId).toList();
  }

  // So the optional positional argument isn't visible outside the class.
  List<Transaction> filterTransactionsByRange(Range range) => _internalFilterTransactionsByRange(range);

  // optionalItems so filterTransactionByLabelAndRange is easy.
  List<Transaction> _internalFilterTransactionsByRange(Range range, [List<Transaction>? optionalItems]) {
    var transactions = optionalItems ?? items;

    switch (range) {
      case Range.lifetime:
        return transactions;

      case Range.previousMonth:
        transactions.retainWhere(
          (transaction) => transaction.isAfterBeginningOfPreviousMonth && transaction.isBeforeBeginningOfMonth,
        );
        return transactions;

      case Range.prevpreviousMonth:
        transactions.retainWhere(
          (transaction) => transaction.isAfterBeginningOfPrevPreviousMonth && transaction.isBeforeBeginningOfPreviousMonth,
        );
        return transactions;

      case Range.month:
        transactions.retainWhere(
          (transaction) => transaction.isAfterBeginningOfMonth,
        );
        return transactions;

      case Range.week:
        transactions.retainWhere(
          (transaction) => transaction.isAfterBeginningOfWeek,
        );
        return transactions;

      default:
        throw UnimplementedError('An unimplemented or null range was passed.');
    }
  }

  void addTransaction(Transaction newTransaction) {
    _items.add(newTransaction);
    notifyListeners();
    // DBHelper.insertTransaction(newTransaction);
  }

  void editTransaction(Transaction editedTransaction) async {
    final editedIndex = _items.indexWhere((transaction) => editedTransaction.id == transaction.id);

    if (editedIndex == -1) {
      return;
    }
    var old = _items[editedIndex];
    _items[editedIndex] = editedTransaction;
    notifyListeners();
    var client = InfluxDBClient(
      url: influx_url,
      token: influx_token,
      org: influx_org,
      bucket: influx_bucket,
    );
    var writeApi = WriteService(client);
    var points = [
      Point('transactions')
          .addTag('payee', old.title)
          .addTag('memo', old.description)
          .addTag('category', old.labelId)
          .addTag('id', old.id)
          .addField('amount', 0.0)
          .addTag('account', old.account!)
          .time(old.date.toUtc()),
      Point('transactions')
          .addTag('payee', old.title)
          .addTag('memo', old.description)
          .addTag('category', editedTransaction.labelId)
          .addTag('id', old.id)
          .addField('amount', old.amount)
          .addTag('account', old.account!)
          .time(old.date.toUtc())
    ];
    await writeApi.write(points).then((value) {
      print('Write completed for ${old.id}');
    }).catchError((exception) {
      // error block
      print("Handle write error here!");
      print(exception);
    });
    client.close();

    // DBHelper.updateTransaction(editedTransaction);
  }

  void _deleteTransaction(Transaction old) async {
    var client = InfluxDBClient(
      url: influx_url,
      token: influx_token,
      org: influx_org,
      bucket: influx_bucket,
    );
    var writeApi = WriteService(client);
    var points = [
      Point('transactions')
          .addTag('payee', old.title)
          .addTag('memo', old.description)
          .addTag('category', old.labelId)
          .addTag('id', old.id)
          .addField('amount', 0.0)
          .addTag('account', old.account!)
          .time(old.date.toUtc()),
    ];
    await writeApi.write(points).then((value) {
      print('Delete completed for ${old.id}');
    }).catchError((exception) {
      // error block
      print("Handle write error here!");
      print(exception);
    });
    client.close();
  }

  void deleteTransaction(String id) async {
    final editedIndex = _items.indexWhere((transaction) => id == transaction.id);
    if (editedIndex == -1) {
      return;
    }
    var old = _items[editedIndex];
    _items.removeWhere((transaction) => transaction.id == id);
    _deleteTransaction(old);

    notifyListeners();

    // DBHelper.deleteTransaction(id);
  }

  Future<void> fetchAndSetTransactions() async {
    var client = InfluxDBClient(
      url: influx_url,
      token: influx_token,
      org: influx_org,
      bucket: influx_bucket,
    );
    var queryService = client.getQueryService();
    var recordStream = await queryService.query('''
    from(bucket: "$influx_bucket")
      |> range(start: -180d)
      |> filter(fn: (r) => r["_measurement"] == "transactions" and r["_value"] != 0)
      |> group()
      |> sort(columns: ["_time"], desc: false)
  ''');
    var records = <Transaction>[];

    Map<String, Transaction> map = {};
    await recordStream.forEach((record) {
      //print(
      //    'record: ${record['_time']}: ${record['id']} ${record['category']} ${record['memo']}  ${record['payee']} ${record['_value']} acc: ${record['account']}');

      var t = Transaction(
          amount: record['_value'],
          id: record['id'],
          title: record['payee'],
          description: record['memo'],
          account: record['account'],
          date: DateTime.parse(record['_time']),
          labelId: record['category']);
      if (map.containsKey(t.id)) {
        //deal with duplicate transactions
        _deleteTransaction(t);
      } else {
        records.add(t);
        map[t.id] = t;
      }
    });
    _items = records;

    recordStream = await queryService.query('''
   from(bucket: "$influx_bucket")
      |> range(start: -1d)
      |> filter(fn: (r) => r["_measurement"] == "balances" and r["account"] == "net")
      |> group()
      |> sort(columns: ["_time"], desc: false)
  ''');
    var balance = 0.0;
    await recordStream.forEach((record) {
      balance = record['_value'];
      //print(
      //    'record: ${record['_time']}: ${record['account']} ${record['_value']}');
    });
    client.close();
    total_balance = balance;
    //await DBHelper.getTransactions();
    notifyListeners();
  }

  // If a transaction has the id of a deleted label, replace it with one of the default labels.
  void _pruneDeletedLabelIds(BuildContext context) {
    final labelsData = Provider.of<Labels>(context, listen: false);

    for (var i = 0; i < _items.length; i++) {
      final transaction = _items[i];
      if (labelsData.findById(transaction.labelId) == null) {
        final newLabelId = transaction.amount >= 0 ? Labels.otherIncomeId : Labels.otherExpenseId;

        _items[i] = Transaction(
          id: transaction.id,
          title: transaction.title,
          amount: transaction.amount,
          description: transaction.description,
          account: transaction.account,
          date: transaction.date,
          labelId: newLabelId,
        );
        DBHelper.updateTransaction(_items[i]);
      }
    }
  }
}
