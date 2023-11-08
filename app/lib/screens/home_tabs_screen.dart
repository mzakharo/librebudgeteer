import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

import '../providers/labels.dart';
import '../providers/transactions.dart';
import '../providers/settings.dart';
import '../widgets/app_drawer.dart';
import 'insights_screen.dart';
import 'budget_screen.dart';
import './dashboard_screen.dart';
import '../widgets/home_tabs_bar.dart';
import 'package:provider/provider.dart';

class HomeTabsScreen extends StatefulWidget {
  @override
  _HomeTabsScreenState createState() => _HomeTabsScreenState();
}

class _HomeTabsScreenState extends State<HomeTabsScreen> {
  int _pageIndex = 0;

  final List<Widget> _pageList = <Widget>[
    DashboardScreen(),
    BudgetScreen(),
    InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Budget'),
      ),
      drawer: AppDrawer(),
      body: RefreshIndicator(
          child: PageTransitionSwitcher(
            transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
              return FadeThroughTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              );
            },
            child: _pageList[_pageIndex],
          ),
          onRefresh: () {
            print("fetch data");
            return Future.wait<void>([
              Provider.of<Settings>(context, listen: false).fetchAndSetSettings(),
              Provider.of<Labels>(context, listen: false).fetchAndSetLabels(),
              Provider.of<Transactions>(context, listen: false).fetchAndSetTransactions(),
            ]);
          }),
      bottomNavigationBar: HomeTabsBar(
        pageIndex: _pageIndex,
        onPressed: (newPageIndex) {
          setState(() {
            _pageIndex = newPageIndex;
          });
        },
      ),
    );
  }
}
