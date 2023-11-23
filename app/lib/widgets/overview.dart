import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insights_range.dart';
import '../providers/settings.dart';
import './balance_summary_card.dart';
import '../providers/transactions.dart';
import '../utils/custom_colors.dart';
import 'package:fl_chart/fl_chart.dart';

// Used in DashboardScreen.
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

class Item {
  double amount;
  int day;
  Item(this.day, this.amount);
}

class Overview extends StatefulWidget {
  @override
  _OverviewState createState() => _OverviewState();
}

class _OverviewState extends State<Overview> {
  List<Color> gradientColors = [
    AppColors.contentColorCyan,
    AppColors.contentColorBlue,
  ];
  List<Color> gradientColors2 = [
    AppColors.contentColorYellow,
    AppColors.contentColorOrange,
  ];

  List<FlSpot> cur = [];

  @override
  Widget build(BuildContext context) {
    var transactionsData = Provider.of<Transactions>(context, listen: true);
    var prev_transactions = transactionsData.filterTransactionsByRange(Range.previousMonth);
    var cur_transactions = transactionsData.filterTransactionsByRange(Range.month);

    final settingsData = Provider.of<Settings>(context, listen: false);

    Map<int, double> map = {};
    prev_transactions.forEach((element) {
      if (element.amount < 0) {
        if (!map.containsKey(element.date.day)) {
          map[element.date.day] = element.amount;
        } else {
          map[element.date.day] = map[element.date.day]! + element.amount;
        }
      }
    });
    List<Item> items = [];
    map.forEach((k, v) => items.add(Item(k, v)));
    items.sort((a, b) => a.day.compareTo(b.day));

    List<FlSpot> pre = [];
    double rolling = 0.0;
    items.forEach((element) {
      rolling -= element.amount;
      pre.add(FlSpot(element.day.toDouble(), rolling));
    });

    map = {};
    cur_transactions.forEach((element) {
      if (element.amount < 0) {
        if (!map.containsKey(element.date.day)) {
          map[element.date.day] = element.amount;
        } else {
          map[element.date.day] = map[element.date.day]! + element.amount;
        }
      }
    });
    items = [];
    map.forEach((k, v) => items.add(Item(k, v)));
    items.sort((a, b) => a.day.compareTo(b.day));

    List<FlSpot> post = [];
    rolling = 0.0;
    int last_day = 1;
    if (items[0].day != 1) post.add(FlSpot(1, rolling));
    items.forEach((element) {
      rolling -= element.amount;
      last_day = element.day;
      post.add(FlSpot(element.day.toDouble(), rolling));
    });
    final today = DateTime.now();
    if (last_day != today.day) post.add(FlSpot(today.day.toDouble(), rolling));

    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 2,
          child: Padding(
            padding: const EdgeInsets.only(
              right: 18,
              left: 12,
              top: 24,
              bottom: 12,
            ),
            child: LineChart(
              mainData(pre, post, settingsData.income_amount),
            ),
          ),
        ),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    Widget text;
    switch (value.toInt()) {
      case 1:
        text = const Text('1', style: style);
        break;
      case 15:
        text = const Text('15', style: style);
        break;
      case 31:
        text = const Text('31', style: style);
        break;
      default:
        text = const Text('', style: style);
        break;
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: text,
    );
  }

  LineChartData mainData(List<FlSpot> pre, List<FlSpot> post, double maxy) {
    return LineChartData(
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 1,
      maxX: 31,
      minY: 0,
      maxY: maxy,
      lineBarsData: [
        LineChartBarData(
          spots: pre,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors.map((color) => color.withOpacity(0.3)).toList(),
            ),
          ),
        ),
        LineChartBarData(
          spots: post,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors2,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors2.map((color) => color.withOpacity(0.3)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
