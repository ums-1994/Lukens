import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/ai_analysis_service.dart';

class GovernancePanel extends StatefulWidget {
  final String proposalId;
  final Map<String, dynamic> proposalData;
  final VoidCallback? onStatusChange;

  const GovernancePanel({
    super.key,
    required this.proposalId,
    required this.proposalData,
    this.onStatusChange,
  });

  @override
  State<GovernancePanel> createState() => _GovernancePanelState();
}

class _GovernancePanelState extends State<GovernancePanel>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _riskScore = 0;
  String _status = 'Draft';
  List<Map<String, dynamic>> _issues = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _analyzeProposal();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _analyzeProposal() async {
    setState(() => _isAnalyzing = true);

    try {
      // Use real AI analysis
      final analysis =
          await AIAnalysisService.analyzeProposalContent(widget.proposalData);

      setState(() {
        _riskScore = analysis['riskScore'];
        _status = analysis['status'];
        _issues = List<Map<String, dynamic>>.from(analysis['issues'] ?? []);
        _isAnalyzing = false;
      });

      _animationController.forward();

      if (widget.onStatusChange != null) {
        widget.onStatusChange!();
      }
    } catch (e) {
      print('AI Analysis Error: $e');
      // Fallback to basic analysis
      final analysis = _performBasicRiskAnalysis();
      setState(() {
        _riskScore = analysis['riskScore'];
        _status = analysis['status'];
        _issues = analysis['issues'];
        _isAnalyzing = false;
      });
    }
  }

  Map<String, dynamic> _performBasicRiskAnalysis() {
    final issues = <Map<String, dynamic>>[];
    int riskScore = 0;

    // Check for missing required sections
    final requiredSections = [
      'executive_summary',
      'scope_deliverables',
      'company_profile',
      'terms_conditions',
    ];

    for (final section in requiredSections) {
      if (!_hasContent(section)) {
        issues.add({
          'type': 'missing_section',
          'title': _getSectionTitle(section),
          'description': 'This section is required for proposal submission',
          'points': 10,
          'priority': 'critical',
          'action': 'Add content from Content Library',
        });
        riskScore += 10;
      }
    }

    // Check for incomplete content
    final contentChecks = [
      {
        'field': 'clientName',
        'title': 'Client Name',
        'points': 5,
        'priority': 'warning',
      },
      {
        'field': 'projectType',
        'title': 'Project Type',
        'points': 3,
        'priority': 'info',
      },
      {
        'field': 'timeline',
        'title': 'Project Timeline',
        'points': 5,
        'priority': 'warning',
      },
    ];

    for (final check in contentChecks) {
      if (!_hasContent(check['field'] as String)) {
        issues.add({
          'type': 'incomplete_content',
          'title': '${check['title']} Missing',
          'description': 'This information is required for a complete proposal',
          'points': check['points'],
          'priority': check['priority'],
          'action': 'Complete the required information',
        });
        riskScore += check['points'] as int;
      }
    }

    // AI-powered content analysis
    final aiIssues = _performAIContentAnalysis();
    issues.addAll(aiIssues);
    riskScore +=
        aiIssues.fold(0, (sum, issue) => sum + (issue['points'] as int));

    // Determine status
    String status;
    if (riskScore == 0) {
      status = 'Ready';
    } else if (riskScore <= 15) {
      status = 'At Risk';
    } else {
      status = 'Blocked';
    }

    return {
      'riskScore': riskScore,
      'status': status,
      'issues': issues,
    };
  }

  List<Map<String, dynamic>> _performAIContentAnalysis() {
    final issues = <Map<String, dynamic>>[];

    // Check for aggressive timelines
    final timeline =
        widget.proposalData['timeline']?.toString().toLowerCase() ?? '';
    if (timeline.contains('half') ||
        timeline.contains('quick') ||
        timeline.contains('urgent')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Aggressive Timeline Detected',
        'description':
            'Timeline may be unrealistic and could lead to project failure',
        'points': 8,
        'priority': 'warning',
        'action': 'Review timeline with delivery team',
      });
    }

    // Check for vague scope
    final scope = widget.proposalData['scope']?.toString().toLowerCase() ?? '';
    if (scope.contains('and other') ||
        scope.contains('etc') ||
        scope.contains('various')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Vague Scope Detected',
        'description':
            'Scope contains vague language that could lead to scope creep',
        'points': 6,
        'priority': 'warning',
        'action': 'Make deliverables more specific',
      });
    }

    // Check for missing assumptions
    if (!_hasContent('assumptions') && !_hasContent('assumptions_risks')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'No Assumptions Section',
        'description': 'Project assumptions should be clearly documented',
        'points': 4,
        'priority': 'info',
        'action': 'Add assumptions from Content Library',
      });
    }

    // Check for team completeness
    if (_hasContent('team_bios') && !_hasCompleteTeamInfo()) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Incomplete Team Information',
        'description':
            'Team bios should include relevant experience and qualifications',
        'points': 3,
        'priority': 'info',
        'action': 'Complete team member profiles',
      });
    }

    return issues;
  }

  bool _hasContent(String field) {
    final content = widget.proposalData[field]?.toString().trim();
    return content != null && content.isNotEmpty && content != 'null';
  }

  bool _hasCompleteTeamInfo() {
    // Simple check - in real app, would analyze team bio content
    return (widget.proposalData['team_bios']?.toString().length ?? 0) > 100;
  }

  String _getSectionTitle(String section) {
    switch (section) {
      case 'executive_summary':
        return 'Executive Summary';
      case 'scope_deliverables':
        return 'Scope & Deliverables';
      case 'company_profile':
        return 'Company Profile';
      case 'terms_conditions':
        return 'Terms & Conditions';
      default:
        return section
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'Ready':
        return const Color(0xFF2ECC71);
      case 'At Risk':
        return const Color(0xFFF39C12);
      case 'Blocked':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case 'Ready':
        return Icons.check_circle;
      case 'At Risk':
        return Icons.warning;
      case 'Blocked':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: Color(0xFFE5E5E5)),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2C3E50),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E5E5)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.security_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Governance Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (_isAnalyzing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Status Overview
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status Indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor().withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Risk Score: $_riskScore',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Risk Meter
                  _buildRiskMeter(),

                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _status == 'Ready' ? _submitForApproval : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _status == 'Ready'
                            ? const Color(0xFF2ECC71)
                            : Colors.grey[400],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Submit for Approval',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Issues List
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issues to Resolve',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _issues.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 48,
                                    color: Colors.green[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No issues found!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _issues.length,
                              itemBuilder: (context, index) {
                                final issue = _issues[index];
                                return _buildIssueCard(issue);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _maxPossibleRiskScore {
    // Only count points for issues that are actually possible for this proposal
    int maxScore = 0;
    final issues = <Map<String, dynamic>>[];
    // Required sections
    final requiredSections = [
      'executive_summary',
      'scope_deliverables',
      'company_profile',
      'terms_conditions',
    ];
    for (final section in requiredSections) {
      if (!_hasContent(section)) {
        maxScore += 10;
      }
    }
    // Content checks
    final contentChecks = [
      {
        'field': 'clientName',
        'points': 5,
      },
      {
        'field': 'projectType',
        'points': 3,
      },
      {
        'field': 'timeline',
        'points': 5,
      },
    ];
    for (final check in contentChecks) {
      if (!_hasContent(check['field'] as String)) {
        maxScore += check['points'] as int;
      }
    }
    // AI checks
    final timeline = widget.proposalData['timeline']?.toString().toLowerCase() ?? '';
    if (timeline.contains('half') || timeline.contains('quick') || timeline.contains('urgent')) {
      maxScore += 8;
    }
    final scope = widget.proposalData['scope']?.toString().toLowerCase() ?? '';
    if (scope.contains('and other') || scope.contains('etc') || scope.contains('various')) {
      maxScore += 6;
    }
    if (!_hasContent('assumptions') && !_hasContent('assumptions_risks')) {
      maxScore += 4;
    }
    if (_hasContent('team_bios') && !_hasCompleteTeamInfo()) {
      maxScore += 3;
    }
    return maxScore == 0 ? 1 : maxScore; // Prevent divide by zero
  }

  Widget _buildRiskMeter() {
    final maxScore = _maxPossibleRiskScore;
    final percentage = maxScore == 0 ? 0.0 : (_riskScore / maxScore).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Risk Level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (percentage * 100).toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                flex: 100 - (percentage * 100).toInt(),
                child: Container(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low Risk',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'High Risk',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    Color priorityColor;
    IconData priorityIcon;

    switch (issue['priority']) {
      case 'critical':
        priorityColor = const Color(0xFFE74C3C);
        priorityIcon = Icons.error;
        break;
      case 'warning':
        priorityColor = const Color(0xFFF39C12);
        priorityIcon = Icons.warning;
        break;
      case 'info':
        priorityColor = const Color(0xFF3498DB);
        priorityIcon = Icons.info;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: priorityColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                priorityIcon,
                color: priorityColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${issue['points']} pts',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            issue['description'],
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Action: ${issue['action']}',
            style: TextStyle(
              fontSize: 11,
              color: priorityColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForApproval() async {
    try {
      // Update proposal status
      final app = context.read<AppState>();
      await app.updateProposalStatus(widget.proposalId, 'In Review');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal submitted for approval'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );

      if (widget.onStatusChange != null) {
        widget.onStatusChange!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
