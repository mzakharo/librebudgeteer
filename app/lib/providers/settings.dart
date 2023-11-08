import 'package:flutter/material.dart';

import '../utils/db_helper.dart';
//import 'package:notion_api/notion_databases.dart';
//import 'package:notion_api/responses/notion_response.dart';

import 'package:notion_sdk/notion_sdk.dart';
import 'package:http/http.dart' as http;
import '../models/budget.dart';
import '../secrets.dart';

// Used anywhere the currency symbol is needed, and in settings screen.

class Settings with ChangeNotifier {
  // Have default values for now so null errors aren't thrown.
  String? _currencySymbol = '\$';
  bool _showCurrency = true;
  var items = <BudgetData>[];
  double income_amount = 0;

  Future<void> fetchAndSetSettings() async {
    final settingsMap = await DBHelper.getSettingsMap();
    _currencySymbol = settingsMap['currency'];
    _showCurrency = settingsMap['showCurrency'] == 1;

    try {
      var hClient = http.Client();
      var client = NotionClient(httpClient: hClient, apiKey: notion_secret);
      var database = await client.databaseApi.queryDatabase(notion_database);
      if (database.hasMore) {
        throw UnimplementedError('database too large');
      }
      var _items = <BudgetData>[];
      database.page?.forEach((page) {
        double amount = page.properties.getProperty('Amount')?.value.number ?? 0;
        String label = page.properties.getProperty('Category')?.value.toString() ?? '';
        double order = page.properties.getProperty('Order')?.value.number ?? 0;
        if (amount < 0) {
          if (label != '') {
            _items.add(BudgetData(label, -amount, order));
          }
          //print('label: $label amount: $amount');
        } else if (amount > 0) {
          if (label == 'Income') {
            //print('income $amount');
            income_amount = amount;
          }
        }
      });
      _items.sort((a, b) => a.order.compareTo(b.order));
      items = _items;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
    notifyListeners();
  }

  // This is what the app actually displays.
  String? get displayedCurrencySymbol {
    // If we're showing the currency symbol, return a currency symbol.
    // Otherwise, just return an empty string. It's easier to deal with that way.
    if (_showCurrency) {
      return _currencySymbol;
    }
    return '';
  }

  // These methods are what the settings screen actually displays/changes.
  String? get currencySymbol => _currencySymbol;

  bool get showCurrency => _showCurrency;

  set currencySymbol(String? currencySymbol) {
    _currencySymbol = currencySymbol;
    notifyListeners();
    DBHelper.updateSettings({'currency': currencySymbol});
  }

  set showCurrency(bool showCurrency) {
    _showCurrency = showCurrency;
    notifyListeners();
    DBHelper.updateSettings({'showCurrency': showCurrency ? 1 : 0});
  }
}
