import 'package:flutter/material.dart';

import '../../widgets/analytics/analytics_dashboard.dart';

class CreatorAnalyticsPage extends StatelessWidget {
  const CreatorAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnalyticsDashboard(
      title: 'Analytics (My Pipeline)',
      scope: 'self',
      showOwnerFilter: false,
    );
  }
}
