import 'package:flutter/material.dart';

import '../../widgets/analytics/analytics_dashboard.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return const AnalyticsDashboard(
      title: 'All analytics',
      scope: 'all',
      showOwnerFilter: true,
    );
  }
}
