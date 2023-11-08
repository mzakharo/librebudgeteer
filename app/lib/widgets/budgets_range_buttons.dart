import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/insights_range.dart';

class _ChipsData {
  final Range rangeValue;
  final String text;

  const _ChipsData({
    required this.rangeValue,
    required this.text,
  });
}

class BudgetsRangeButtons extends StatelessWidget {
  Widget buildRangeButton(bool isSelected, _ChipsData e, InsightsRange insightsRangeData) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
              width: 2,
              color: isSelected ? Colors.white60 : Colors.transparent,
            ),
          ),
        ),
        child: FittedBox(
          child: Text(
            e.text,
            style: TextStyle(color: isSelected ? Colors.white : Colors.white54),
          ),
        ),
        onPressed: () {
          // Don't want to have to unnecessarily call notifyListeners.
          if (!isSelected) {
            insightsRangeData.range = e.rangeValue;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insightsRangeData = Provider.of<InsightsRange>(context);

    var today = DateTime.now();
    var lastMonth = new DateTime(today.year, today.month - 1, 1);
    var lastlastmonth = new DateTime(today.year, today.month - 2, 1);

    var _chipsData = <_ChipsData>[
      _ChipsData(rangeValue: Range.prevpreviousMonth, text: DateFormat("MMMM").format(lastlastmonth)),
      _ChipsData(rangeValue: Range.previousMonth, text: DateFormat("MMMM").format(lastMonth)),
      _ChipsData(rangeValue: Range.month, text: DateFormat("MMMM").format(today)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _chipsData.map(
          (e) {
            final isSelected = e.rangeValue == insightsRangeData.range;

            return buildRangeButton(isSelected, e, insightsRangeData);
          },
        ).toList(),
      ),
    );
  }
}
