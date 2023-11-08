import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';

import '../models/mylabel.dart';
import 'package:influxdb_client/api.dart';
import 'dart:math' as math;
import '../secrets.dart';
import 'package:notion_sdk/notion_sdk.dart';
import 'package:http/http.dart' as http;

class Labels with ChangeNotifier {
  // These are the id's of default labels. They cannot be deleted.
  static const otherIncomeId = 'Other Income';
  static const otherExpenseId = 'Other Expense';

  var _items = <MyLabel>[];

  List<MyLabel> get items {
    return [..._items];
  }

  List<MyLabel> get incomeLabels {
    return _items.where((label) => label.labelType == LabelType.INCOME).toList();
  }

  List<MyLabel> get expenseLabels {
    return _items.where((label) => label.labelType == LabelType.EXPENSE).toList();
  }

  MyLabel? findById(String? id) {
    return _items.firstWhereOrNull((label) => id == label.id);
  }

  void addLabel(MyLabel label) {
    _items.add(label);
    notifyListeners();
    // DBHelper.insertLabel(label);
  }

  void editLabel(MyLabel editedLabel) {
    final editedIndex = _items.indexWhere((label) => editedLabel.id == label.id);

    if (editedIndex == -1) {
      return;
    }
    _items[editedIndex] = editedLabel;
    notifyListeners();
    // DBHelper.updateLabel(editedLabel);
  }

  void deleteLabel(String? id) {
    if (id == otherExpenseId || id == otherIncomeId) {
      return;
    }
    _items.removeWhere((label) => label.id == id);
    notifyListeners();
    // DBHelper.deleteLabel(id);
  }

  Future<void> fetchAndSetLabels() async {
    //_items = await DBHelper.getLabels();

    var client = InfluxDBClient(
      url: influx_url,
      token: influx_token,
      org: influx_org,
      bucket: influx_bucket,
    );
    var queryService = client.getQueryService();
    var recordStream = await queryService.query('''
    from(bucket: "$influx_bucket")
      |> range(start: -181d)
      |> filter(fn: (r) => r["_measurement"] == "transactions" and r["_value"] != 0)
      |> group()
      |> keep(columns: ["category", "_value"])
      |> unique(column: "category")
      |>sort(columns: ["category"])
  ''');
    List<Color> colorArray = [
      Color(0xFFFF6633),
      Color(0xFFFFB399),
      Color(0xFFFF33FF),
      Color(0xFFFFFF99),
      Color(0xFF00B3E6),
      Color(0xFFE6B333),
      Color(0xFF3366E6),
      Color(0xFF999966),
      Color(0xFF99FF99),
      Color(0xFFB34D4D),
      Color(0xFF80B300),
      Color(0xFF809900),
      Color(0xFFE6B3B3),
      Color(0xFF6680B3),
      Color(0xFF66991A),
      Color(0xFFFF99E6),
      Color(0xFFCCFF1A),
      Color(0xFFFF1A66),
      Color(0xFFE6331A),
      Color(0xFF33FFCC),
      Color(0xFF66994D),
      Color(0xFFB366CC),
      Color(0xFF4D8000),
      Color(0xFFB33300),
      Color(0xFFCC80CC),
      Color(0xFF66664D),
      Color(0xFF991AFF),
      Color(0xFFE666FF),
      Color(0xFF4DB3FF),
      Color(0xFF1AB399),
      Color(0xFFE666B3),
      Color(0xFF33991A),
      Color(0xFFCC9999),
      Color(0xFFB3B31A),
      Color(0xFF00E680),
      Color(0xFF4D8066),
      Color(0xFF809980),
      Color(0xFFE6FF80),
      Color(0xFF1AFF33),
      Color(0xFF999933),
      Color(0xFFFF3380),
      Color(0xFFCCCC00),
      Color(0xFF66E64D),
      Color(0xFF4D80CC),
      Color(0xFF9900B3),
      Color(0xFFE64D66),
      Color(0xFF4DB380),
      Color(0xFFFF4D4D),
      Color(0xFF99E6E6),
      Color(0xFF6666FF)
    ];
    var rng = math.Random(0);
    var records = <MyLabel>[];

    Map<String, MyLabel> map = {};
    await recordStream.forEach((record) {
      var label = MyLabel(
        id: record['category'],
        title: record['category'],
        color: colorArray[rng.nextInt(colorArray.length)],
        labelType: (record['_value'] < 0.0) ? LabelType.EXPENSE : LabelType.INCOME,
      );
      records.add(label);
      map[label.id] = label;
    });
    client.close();
    _items = records;

    // If the default labels weren't in storage, add them here.
    var starterLabels = <MyLabel>[
      // By adding both of these labels, the user can edit labels without a problem. If these aren't added to the db,
      // then the db will attempt to update a nonexistant label when edited.
      MyLabel(
        id: otherIncomeId,
        title: otherIncomeId,
        color: Colors.blueGrey,
        labelType: LabelType.INCOME,
      ),
      MyLabel(
        id: otherExpenseId,
        title: otherExpenseId,
        color: Colors.grey,
        labelType: LabelType.EXPENSE,
      ),
    ];

    try {
      var hClient = http.Client();
      var client = NotionClient(httpClient: hClient, apiKey: notion_secret);
      var database = await client.databaseApi.queryDatabase(notion_database);
      if (database.hasMore) {
        throw UnimplementedError('database too large');
      }
      database.page?.forEach((page) {
        //double amount = page.properties.getProperty('Amount')?.value.number ?? 0;
        String label = page.properties.getProperty('Category')?.value.toString() ?? '';
        if (label != '') {
          MyLabel lbl = MyLabel(
            id: label,
            title: label,
            color: colorArray[rng.nextInt(colorArray.length)],
            labelType: LabelType.EXPENSE,
          );
          starterLabels.add(lbl);
        }
      });
    } catch (e) {
      print(e.toString());
      rethrow;
    }
    starterLabels.forEach(
      (starterLabel) {
        if (!map.containsKey(starterLabel.id)) {
          _items.add(starterLabel);
        }
      },
    );
    _items.sort((a, b) => a.title.compareTo(b.title));
    notifyListeners();
  }
}
