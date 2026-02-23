import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/risk_api_service.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final RiskApiService _riskApiService = RiskApiService();
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(
          child: Text("Select or create a proposal on the Dashboard."));
    }
    final sections = Map<String, dynamic>.from(p["sections"] ?? {});
    final ctrls = {
      for (final e in sections.entries)
        e.key: TextEditingController(text: e.value?.toString() ?? "")
    };
    return Scaffold(
      appBar: AppBar(
        title: Text("${p["title"]} • ${p["client"]} • ${p["dtype"]}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: sections.keys.map((k) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrls[k],
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Enter content...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          await app.updateSections({k: ctrls[k]!.text});
                        },
                        child: const Text("Save Section"),
                      ),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAnalyzing ? null : _analyzeProposal,
        label: _isAnalyzing 
          ? const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text("Analyzing..."),
              ],
            )
          : const Text("Analyze Risk"),
        icon: _isAnalyzing ? null : const Icon(Icons.analytics),
      ),
    );
  }

  Future<void> _analyzeProposal() async {
    final app = context.read<AppState>();
    final p = app.currentProposal;
    if (p == null) return;

    // Combine all sections into one text
    final sections = p["sections"] as Map<String, dynamic>?;
    final proposalText = sections == null
        ? ""
        : sections.entries.map((e) => "${e.key}: ${e.value}").join("\n\n");

    if (proposalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add some content before analyzing.")),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      debugPrint('🚀 Starting risk analysis with text length: ${proposalText.length}');
      debugPrint('🔍 RiskApiService URL: ${_riskApiService.baseUrl}');
      
      final result = await _riskApiService.analyzeProposal(proposalText);
      
      debugPrint('✅ Risk analysis completed successfully');
      _showRiskAnalysisDialog(result);
    } catch (e) {
      debugPrint('❌ Risk analysis failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Risk analysis failed: ${e.toString()}")),
      );
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showRiskAnalysisDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Risk Analysis Results"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Risk Score Display
              if (result.containsKey('analysis') && result['analysis'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Compound Risk Score",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final analysis = result['analysis'] as Map<String, dynamic>?;
                            final compoundRisk = analysis?['compound_risk'] as Map<String, dynamic>?;
                            final score = compoundRisk?['score'];
                            
                            if (score != null) {
                              // Convert score to percentage (0-10 scale to 0-100%)
                              final percentage = (score as num) * 10;
                              return Text(
                                "${percentage.toStringAsFixed(1)}%",
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: _getRiskColor(score),
                                ),
                              );
                            } else {
                              return Text(
                                "N/A",
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        if (result['analysis']?['compound_risk']?['summary'] != null)
                          Text(
                            result['analysis']['compound_risk']['summary'].toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Analysis Summary Display
              if (result.containsKey('analysis') && result['analysis']?['compound_risk']?['summary'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Risk Summary",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(result['analysis']['compound_risk']['summary'].toString()),
                      ],
                    ),
                  ),
                ),
              // Missing Sections Display
              if (result.containsKey('analysis') && 
                  result['analysis']?['structural_analysis']?['missing_sections'] != null)
                ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Missing Sections",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...(result['analysis']['structural_analysis']['missing_sections'] as List).map(
                            (section) => Text("• ${section.toString()}"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(dynamic score) {
    if (score is num) {
      // API returns 0-10 scale: 0-3 = green, 3-7 = orange, 7-10 = red
      if (score >= 7.0) return Colors.red;
      if (score >= 3.0) return Colors.orange;
      return Colors.green;
    }
    return Colors.grey;
  }
}
