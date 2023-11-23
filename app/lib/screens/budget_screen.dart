import 'package:flutter/material.dart';

import '../providers/insights_range.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../utils/custom_colors.dart';

import 'package:google_fonts/google_fonts.dart';

import '../widgets/budgets_range_buttons.dart';
import '../charts/chart_widgets/budgets_bar_chart.dart';

class BudgetScreen extends StatefulWidget {
  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _graphScreens = <Widget>[
      Container(
        color: Theme.of(context).brightness == Brightness.light ? Theme.of(context).colorScheme.expenseColor : Theme.of(context).canvasColor,
        child: Column(
          children: <Widget>[
            const Spacer(flex: 4),
            Text(
              "Budget",
              style: GoogleFonts.cabin(
                color: Colors.white,
                fontSize: 30,
              ),
            ),
            const Spacer(flex: 3),
            Container(
                margin: const EdgeInsets.only(left: 18, right: 25),
                height: 500,
                child: SingleChildScrollView(
                    child: Container(
                  // Uneven because room is needed for ScrollingPageIndicator.
                  //margin: const EdgeInsets.only(left: 5, right: 5),
                  height: 1000,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Theme.of(context).brightness == Brightness.light
                        ? null
                        : Border.all(color: Theme.of(context).colorScheme.expenseColor, width: 5),
                  ),
                  child: BudgetsPieChart(),
                ))),
            const Spacer(flex: 3),
            BudgetsRangeButtons(),
            const Spacer(flex: 4),
          ],
        ),
      ),
    ];

    return Stack(
      children: <Widget>[
        // Use a builder instead of directly accessing the widgets so it's less resource intensive.
        ChangeNotifierProvider(
          create: (_) => InsightsRange(),
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemBuilder: (_, index) {
              return _graphScreens[index];
            },
            itemCount: _graphScreens.length,
          ),
        ),
        Container(
          alignment: Alignment.centerRight,
          margin: const EdgeInsets.only(right: 7),
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _graphScreens.length,
            axisDirection: Axis.vertical,
            effect: SlideEffect(spacing: 16, dotColor: Colors.white30, activeDotColor: Colors.white),
          ),
        ),
      ],
    );
  }
}
