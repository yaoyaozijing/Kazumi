import 'package:flutter/material.dart';

class SortFilterTabPanel extends StatelessWidget {
  const SortFilterTabPanel({
    super.key,
    required this.sortChild,
    required this.filterChild,
    this.heightFactor = 0.46,
  });

  final Widget sortChild;
  final Widget filterChild;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.of(context).size.height * heightFactor;
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: panelHeight,
        child: Column(
          children: [
            const SizedBox(height: 4),
            const TabBar(
              tabs: [
                Tab(text: '排序'),
                Tab(text: '筛选'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: sortChild,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: filterChild,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
