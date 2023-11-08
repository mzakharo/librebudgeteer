import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/insights_range.dart';
import '../../providers/labels.dart';
import '../../providers/transactions.dart';
import '../../models/transaction.dart';
import '../../providers/settings.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import '../../widgets/transactions_list_filtered.dart';

class _BarData2 {
  _BarData2(this.color, this.note, this.value, this.label, this.range);
  final Color color;
  double value;
  final String note;
  final String label;
  final Range range;
}

// This screen is a screen under home_screen.
class _BarData {
  const _BarData(this.color, this.note, this.value, this.shadowValue, this.icon, this.label, this.labelTotal, this.range);
  final Color color;
  final double value;
  final String note;
  final double shadowValue;
  final IconData icon;
  final String label;
  final List<_BarData2> labelTotal;
  final Range range;
}

class AppColors {
  static const Color primary = contentColorCyan;
  static const Color menuBackground = Color(0xFF090912);
  static const Color itemsBackground = Color(0xFF1B2339);
  static const Color pageBackground = Color(0xFF282E45);
  static const Color mainTextColor1 = Colors.white;
  static const Color mainTextColor2 = Colors.white70;
  static const Color mainTextColor3 = Colors.white38;
  static const Color mainGridLineColor = Colors.white10;
  static const Color borderColor = Colors.white54;
  static const Color gridLinesColor = Color(0x11FFFFFF);

  static const Color contentColorBlack = Colors.black;
  static const Color contentColorWhite = Colors.white;
  static const Color contentColorBlue = Color(0xFF2196F3);
  static const Color contentColorYellow = Color(0xFFFFC300);
  static const Color contentColorOrange = Color(0xFFFF683B);
  static const Color contentColorGreen = Color(0xFF3BFF49);
  static const Color contentColorPurple = Color(0xFF6E1BFF);
  static const Color contentColorPink = Color(0xFFFF3AF2);
  static const Color contentColorRed = Color(0xFFE80054);
  static const Color contentColorCyan = Color(0xFF50E4FF);
}

class _IconWidget extends ImplicitlyAnimatedWidget {
  const _IconWidget({
    required this.color,
    required this.isSelected,
    required this.icon,
  }) : super(duration: const Duration(milliseconds: 300));
  final Color color;
  final bool isSelected;
  final IconData icon;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _IconWidgetState();
}

class _IconWidgetState extends AnimatedWidgetBaseState<_IconWidget> {
  Tween<double>? _rotationTween;

  @override
  Widget build(BuildContext context) {
    final rotation = math.pi * 4 * _rotationTween!.evaluate(animation);
    final scale = 1 + _rotationTween!.evaluate(animation) * 0.5;
    return Transform(
      transform: Matrix4.rotationZ(rotation).scaled(scale, scale),
      origin: const Offset(14, 14),
      child: Icon(
        widget.isSelected ? widget.icon : widget.icon,
        color: widget.color,
        size: 28,
      ),
    );
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _rotationTween = visitor(
      _rotationTween,
      widget.isSelected ? 1.0 : 0.0,
      (dynamic value) => Tween<double>(
        begin: value as double,
        end: widget.isSelected ? 1.0 : 0.0,
      ),
    ) as Tween<double>?;
  }
}

class BudgetsPieChart extends StatefulWidget {
  final shadowColor = AppColors.contentColorGreen;
  final fullColor = AppColors.contentColorRed;
  final mediumColor = AppColors.contentColorYellow;

  @override
  _BudgetPicChartState createState() => _BudgetPicChartState();
}

class _BudgetPicChartState extends State<BudgetsPieChart> {
  BarChartGroupData generateBarGroup(
    int x,
    Color color,
    double value,
    double shadowValue,
  ) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 6,
        ),
        BarChartRodData(
          toY: shadowValue,
          color: (value < 99)
              ? (value < 85)
                  ? widget.shadowColor
                  : widget.mediumColor
              : widget.fullColor,
          width: 6,
        ),
      ],
      showingTooltipIndicators: touchedGroupIndex == x ? [0] : [],
    );
  }

  int touchedGroupIndex = -1;

  @override
  Widget build(BuildContext context) {
    final transactionsData = Provider.of<Transactions>(context);
    final labelsData = Provider.of<Labels>(context, listen: false);
    final range = Provider.of<InsightsRange>(context).range;

    final settingsData = Provider.of<Settings>(context, listen: false);

    final transactions = transactionsData.filterTransactionsByRange(range);

    double budgeted_amount = 0.0;
    double budgeted_total = 0.0;
    double over_amount = 0.0;

    List<_BarData> dataList = [];

    Map<String, int> settingsMap = {};

    settingsData.items.forEach((element) {
      var label = labelsData.findById(element.label);
      budgeted_total += element.limit;
      settingsMap[element.label] = 0;
      if (label != null) {
        var amount = label.getLabelTotalWithRange(context, range).abs();
        budgeted_amount += amount;
        if (amount > element.limit) {
          over_amount += amount - element.limit;
        }
        var value = (amount / element.limit * 100).toInt();
        dataList.add(_BarData(AppColors.contentColorPink, '${amount.toInt()} / ${element.limit.toInt()}\n${element.label}', value.toDouble(), 100,
            Icons.access_alarm, element.label, [], range));
        //print('${element.label}  ${label} ${element.limit} ${value}');
      }
    });

    var month_total = 0.0;
    if (range == Range.prevpreviousMonth) {
      month_total = transactionsData.prevpreviousMonthExpensesTotal;
    } else if (range == Range.previousMonth) {
      month_total = transactionsData.previousMonthExpensesTotal;
    } else {
      month_total = transactionsData.monthExpensesTotal;
    }
    month_total = month_total.abs();

    var everything_else = month_total - budgeted_amount;
    var everything_else_total = settingsData.income_amount - budgeted_total - over_amount;
    if (everything_else_total <= 0) {
      everything_else_total = 1;
    }
    var value = ((everything_else / everything_else_total) * 100).toInt();

    double max_amount = 0;
    List<_BarData2> lableAmounts = labelsData.items.map((label) {
      double amount = getLabelTotalWithRange(transactions, label.id);
      amount = (amount > 0) ? 0 : -amount;
      if (settingsMap.containsKey(label.id)) {
        amount = 0; //only for everything else
      }
      if (max_amount < amount) max_amount = amount;
      return _BarData2(label.color, '\$${amount.toInt()}: ${label.id}', amount, label.id, range);
    }).toList();
    lableAmounts.removeWhere(
      (label) => label.value == 0,
    );
    lableAmounts.every((item) {
      item.value = item.value / max_amount * 100;
      return true;
    });
    lableAmounts.sort((a, b) => b.value.compareTo(a.value));

    dataList.insert(
        0,
        _BarData(AppColors.contentColorPink, '${everything_else.toInt()} / ${everything_else_total.toInt()}\nEverything Else', value.toDouble(), 100,
            Icons.access_alarm, "Everything Else", lableAmounts, range));

    value = ((month_total / settingsData.income_amount) * 100).toInt();
    dataList.insert(
        0,
        _BarData(AppColors.contentColorPink, '${month_total.toInt()} / ${settingsData.income_amount.toInt()}\nTotal Spending', value.toDouble(), 100,
            Icons.access_alarm, "Total Spending", [], range));

    var seriesList = [
      new charts.Series<_BarData, String>(
          id: 'Budgets',
          domainFn: (_BarData v, _) => v.label,
          measureFn: (_BarData v, _) => (v.value > 100)
              ? 100
              : (v.value == 0)
                  ? 1
                  : v.value,
          colorFn: (_BarData v, _) => charts.ColorUtil.fromDartColor((v.value > 100)
              ? Color(0xFFFF683B)
              : (v.value > 90)
                  ? Color(0xFF8B8000)
                  : AppColors.contentColorBlue),
          data: dataList,
          // Set a label accessor to control the text of the bar label.
          labelAccessorFn: (_BarData v, _) => '${v.note}')
    ];

    return new charts.BarChart(
      seriesList,
      animate: true,
      vertical: false,
      // Set a bar label decorator.
      // Example configuring different styles for inside/outside:
      //       barRendererDecorator: new charts.BarLabelDecorator(
      //          insideLabelStyleSpec: new charts.TextStyleSpec(...),
      //          outsideLabelStyleSpec: new charts.TextStyleSpec(...)),
      selectionModels: [
        new charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          //changedListener: _onSelectionChanged,
          updatedListener: _onSelectionChanged,
        )
      ],
      barRendererDecorator: new charts.BarLabelDecorator<String>(
          labelPosition: charts.BarLabelPosition.auto,
          outsideLabelStyleSpec:
              charts.TextStyleSpec(fontSize: 12, color: Theme.of(context).brightness == Brightness.light ? charts.Color.black : charts.Color.white)),
      // Hide domain axis.
      domainAxis: new charts.OrdinalAxisSpec(renderSpec: new charts.NoneRenderSpec()),
      primaryMeasureAxis: new charts.NumericAxisSpec(renderSpec: new charts.NoneRenderSpec(), viewport: charts.NumericExtents(0, 100)),
    );
  }

  _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;

    if (selectedDatum.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SecondRoute(selectedDatum.first.datum)),
      );
    }
  }
}

class SecondRoute extends StatelessWidget {
  SecondRoute(this.val);
  final _BarData val;

  @override
  Widget build(BuildContext context) {
    _onSelectionChanged(charts.SelectionModel model) {
      final selectedDatum = model.selectedDatum;

      if (selectedDatum.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ThirdRoute(selectedDatum.first.datum)),
        );
      }
    }

    var seriesList = [
      new charts.Series<_BarData2, String>(
          id: 'Budgets',
          domainFn: (_BarData2 v, _) => v.label,
          measureFn: (_BarData2 v, _) => (v.value > 100)
              ? 100
              : (v.value == 0)
                  ? 1
                  : v.value,
          colorFn: (_BarData2 v, _) => charts.ColorUtil.fromDartColor((v.value > 100)
              ? Color(0xFFFF683B)
              : (v.value > 90)
                  ? Color(0xFF8B8000)
                  : AppColors.contentColorBlue),
          data: val.labelTotal,
          // Set a label accessor to control the text of the bar label.
          labelAccessorFn: (_BarData2 v, _) => '${v.note}')
    ];

    var chart = new charts.BarChart(
      seriesList,
      animate: false,
      vertical: false,
      // Set a bar label decorator.
      // Example configuring different styles for inside/outside:
      //       barRendererDecorator: new charts.BarLabelDecorator(
      //          insideLabelStyleSpec: new charts.TextStyleSpec(...),
      //          outsideLabelStyleSpec: new charts.TextStyleSpec(...)),

      selectionModels: [
        new charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          //changedListener: _onSelectionChanged,
          updatedListener: _onSelectionChanged,
        )
      ],
      barRendererDecorator: new charts.BarLabelDecorator<String>(
          labelPosition: charts.BarLabelPosition.auto,
          outsideLabelStyleSpec:
              charts.TextStyleSpec(fontSize: 12, color: Theme.of(context).brightness == Brightness.light ? charts.Color.black : charts.Color.white)),
      // Hide domain axis.
      domainAxis: new charts.OrdinalAxisSpec(renderSpec: new charts.NoneRenderSpec()),
      primaryMeasureAxis: new charts.NumericAxisSpec(renderSpec: new charts.NoneRenderSpec(), viewport: charts.NumericExtents(0, 100)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(val.note),
      ),
      body: Center(
        child: Container(
            height: 700,
            child: SingleChildScrollView(
                child: Container(
              // Uneven because room is needed for ScrollingPageIndicator.
              height: 700,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: (val.labelTotal.length == 0)
                  ? CustomScrollView(
                      slivers: <Widget>[
                        TransactionsListFiltered(val.label, val.range), //chart,
                      ],
                    )
                  : chart,
            ))),
      ),
    );
  }
}

class ThirdRoute extends StatelessWidget {
  ThirdRoute(this.val);
  final _BarData2 val;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(val.note),
      ),
      body: Center(
        child: Container(
            height: 700,
            child: SingleChildScrollView(
                child: Container(
                    // Uneven because room is needed for ScrollingPageIndicator.
                    height: 700,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: CustomScrollView(
                      slivers: <Widget>[
                        TransactionsListFiltered(val.label, val.range), //chart,
                      ],
                    )))),
      ),
    );
  }
}
