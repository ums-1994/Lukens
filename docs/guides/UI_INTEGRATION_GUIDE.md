# UI Integration Guide for AI Features
## Quick Implementation Steps

---

## 🎯 Overview

This guide shows you how to add AI features to your proposal wizard UI. The backend is ready - you just need to add buttons and display the results!

---

## 📋 Prerequisites

1. ✅ Backend AI service is running (`uvicorn app:app --reload`)
2. ✅ User is authenticated (has JWT token)
3. ✅ Proposal exists in the system

---

## 🔧 Step 1: Set Authentication Token

In your login/auth flow, set the token for AI service:

```dart
import 'package:your_app/services/ai_analysis_service.dart';

// After successful login
void onLoginSuccess(String token) {
  AIAnalysisService.setAuthToken(token);
  // ... rest of your login logic
}
```

---

## 🎨 Step 2: Add AI Buttons to Proposal Editor

### Option A: Risk Analysis Button (Wildcard Challenge)

Add this to your proposal editor toolbar:

```dart
// In your proposal editor widget
ElevatedButton.icon(
  onPressed: _analyzeRisks,
  icon: Icon(Icons.analytics),
  label: Text('Analyze Risks'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
  ),
)

// Handler method
Future<void> _analyzeRisks() async {
  setState(() => _isAnalyzing = true);
  
  try {
    final analysis = await AIAnalysisService.analyzeProposalRisks(
      widget.proposalId
    );
    
    // Show results in a dialog
    _showRiskAnalysisDialog(analysis);
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Risk analysis failed: $e')),
    );
  } finally {
    setState(() => _isAnalyzing = false);
  }
}

void _showRiskAnalysisDialog(Map<String, dynamic> analysis) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            analysis['status'] == 'Ready' 
              ? Icons.check_circle 
              : Icons.warning,
            color: analysis['status'] == 'Ready' 
              ? Colors.green 
              : Colors.red,
          ),
          SizedBox(width: 8),
          Text('Risk Analysis'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Risk Score
            Text(
              'Risk Score: ${analysis['riskScore']}/100',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: analysis['riskScore'] > 60 
                  ? Colors.red 
                  : Colors.orange,
              ),
            ),
            SizedBox(height: 8),
            
            // Status
            Chip(
              label: Text(analysis['status']),
              backgroundColor: analysis['status'] == 'Ready'
                ? Colors.green
                : Colors.red,
              labelStyle: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            
            // Summary
            Text(
              analysis['summary'] ?? 'No summary available',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            
            // Issues
            if (analysis['issues'] != null && 
                (analysis['issues'] as List).isNotEmpty) ...[
              Text(
                'Issues Found:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              ...((analysis['issues'] as List).map((issue) => 
                Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: _getSeverityColor(issue['priority']),
                    ),
                    title: Text(issue['title'] ?? 'Issue'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue['description'] ?? ''),
                        SizedBox(height: 4),
                        Text(
                          'Action: ${issue['action'] ?? 'Review'}',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    ),
  );
}

Color _getSeverityColor(String? severity) {
  switch (severity) {
    case 'critical':
      return Colors.red;
    case 'warning':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}
```

---

### Option B: Generate Content Button

Add this to each section editor:

```dart
// In your section editor (e.g., Executive Summary)
Row(
  children: [
    Text('Executive Summary', style: TextStyle(fontSize: 18)),
    Spacer(),
    ElevatedButton.icon(
      onPressed: _generateContent,
      icon: Icon(Icons.auto_awesome),
      label: Text('Generate with AI'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
      ),
    ),
  ],
)

// Handler method
Future<void> _generateContent() async {
  setState(() => _isGenerating = true);
  
  try {
    // Prepare context from your proposal data
    final context = {
      'client_name': widget.proposal.clientName,
      'project_type': widget.proposal.projectType,
      'industry': widget.proposal.industry,
      'key_objectives': widget.proposal.objectives,
    };
    
    final generatedContent = await AIAnalysisService.generateSection(
      'executive_summary', // or 'scope_deliverables', 'delivery_approach', etc.
      context,
    );
    
    // Update the text field
    setState(() {
      _contentController.text = generatedContent;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Content generated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generation failed: $e')),
    );
  } finally {
    setState(() => _isGenerating = false);
  }
}
```

---

### Option C: Improve Content Button

Add this next to your text editor:

```dart
// In your section editor
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _contentController,
        maxLines: 10,
        decoration: InputDecoration(
          hintText: 'Enter content...',
        ),
      ),
    ),
  ],
),
SizedBox(height: 8),
ElevatedButton.icon(
  onPressed: _improveContent,
  icon: Icon(Icons.lightbulb),
  label: Text('Improve with AI'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.teal,
  ),
)

// Handler method
Future<void> _improveContent() async {
  if (_contentController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please enter some content first')),
    );
    return;
  }
  
  setState(() => _isImproving = true);
  
  try {
    final improvements = await AIAnalysisService.improveContent(
      _contentController.text,
      'executive_summary', // or appropriate section type
    );
    
    // Show improvements dialog
    _showImprovementsDialog(improvements);
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Improvement failed: $e')),
    );
  } finally {
    setState(() => _isImproving = false);
  }
}

void _showImprovementsDialog(Map<String, dynamic> improvements) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Content Improvements'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quality Score
            Text(
              'Quality Score: ${improvements['quality_score']}/100',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Strengths
            if (improvements['strengths'] != null) ...[
              Text(
                'Strengths:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...((improvements['strengths'] as List).map((s) => 
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(s)),
                    ],
                  ),
                )
              )),
              SizedBox(height: 16),
            ],
            
            // Improvements
            if (improvements['improvements'] != null) ...[
              Text(
                'Suggested Improvements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...((improvements['improvements'] as List).map((imp) => 
                Card(
                  margin: EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          imp['suggestion'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (imp['example'] != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Example: ${imp['example']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Keep Original'),
        ),
        ElevatedButton(
          onPressed: () {
            // Apply improved version
            setState(() {
              _contentController.text = improvements['improved_version'];
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Improvements applied!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: Text('Apply Improvements'),
        ),
      ],
    ),
  );
}
```

---

### Option D: Compliance Check Button

Add this to your proposal review/approval screen:

```dart
ElevatedButton.icon(
  onPressed: _checkCompliance,
  icon: Icon(Icons.verified),
  label: Text('Check Compliance'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.indigo,
  ),
)

// Handler method
Future<void> _checkCompliance() async {
  setState(() => _isCheckingCompliance = true);
  
  try {
    final compliance = await AIAnalysisService.checkCompliance(
      widget.proposalId
    );
    
    // Show compliance results
    _showComplianceDialog(compliance);
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compliance check failed: $e')),
    );
  } finally {
    setState(() => _isCheckingCompliance = false);
  }
}

void _showComplianceDialog(Map<String, dynamic> compliance) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            compliance['ready_for_approval'] 
              ? Icons.check_circle 
              : Icons.warning,
            color: compliance['ready_for_approval'] 
              ? Colors.green 
              : Colors.orange,
          ),
          SizedBox(width: 8),
          Text('Compliance Check'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compliance Score: ${compliance['compliance_score']}/100',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Passed Checks
            if (compliance['passed_checks'] != null) ...[
              Text(
                'Passed Checks:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              ...((compliance['passed_checks'] as List).map((check) => 
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(check)),
                    ],
                  ),
                )
              )),
              SizedBox(height: 16),
            ],
            
            // Failed Checks
            if (compliance['failed_checks'] != null &&
                (compliance['failed_checks'] as List).isNotEmpty) ...[
              Text(
                'Failed Checks:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              ...((compliance['failed_checks'] as List).map((check) => 
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.close, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(check)),
                    ],
                  ),
                )
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
        if (!compliance['ready_for_approval'])
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to fix issues
            },
            child: Text('Fix Issues'),
          ),
      ],
    ),
  );
}
```

---

## 🚦 Step 3: Add Release Gate (Wildcard Challenge)

In your "Release Proposal" or "Submit for Approval" screen:

```dart
// Before allowing release, check AI risk analysis
Future<bool> _canReleaseProposal() async {
  try {
    final analysis = await AIAnalysisService.analyzeProposalRisks(
      widget.proposalId
    );
    
    // Check if can release
    if (analysis['status'] == 'Blocked') {
      // Show blocking dialog
      _showBlockedDialog(analysis);
      return false;
    }
    
    return true;
    
  } catch (e) {
    // If AI fails, allow manual review
    return true;
  }
}

void _showBlockedDialog(Map<String, dynamic> analysis) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('Release Blocked'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This proposal cannot be released due to multiple issues:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(analysis['summary'] ?? ''),
          SizedBox(height: 16),
          Text(
            'Required Actions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...((analysis['required_actions'] as List? ?? []).map((action) => 
            Padding(
              padding: EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  Icon(Icons.arrow_right, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(action)),
                ],
              ),
            )
          )),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate back to editor to fix issues
          },
          child: Text('Fix Issues'),
        ),
      ],
    ),
  );
}

// In your release button
ElevatedButton(
  onPressed: () async {
    if (await _canReleaseProposal()) {
      // Proceed with release
      _releaseProposal();
    }
  },
  child: Text('Release Proposal'),
)
```

---

## 📊 Step 4: Add AI Status Indicator

Add this to your app bar or dashboard:

```dart
FutureBuilder<bool>(
  future: AIAnalysisService.isConfigured,
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data == true) {
      return Chip(
        avatar: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
        label: Text('AI Enabled'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    } else {
      return Chip(
        avatar: Icon(Icons.cloud_off, size: 16, color: Colors.white),
        label: Text('AI Offline'),
        backgroundColor: Colors.grey,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    }
  },
)
```

---

## 🎬 Demo Flow for Hackathon

1. **Start**: Create new proposal with basic info
2. **Generate**: Click "Generate with AI" on Executive Summary
3. **Show**: AI creates professional content in 3-5 seconds
4. **Improve**: Write poor content, click "Improve with AI"
5. **Show**: Quality score (15/100) and specific suggestions
6. **Analyze**: Click "Analyze Risks" button
7. **Show**: Multiple issues detected (vague scope, missing sections)
8. **Show**: Risk score 75/100, Status: BLOCKED
9. **Block**: Try to release - blocked by risk gate
10. **Fix**: Use AI to generate missing sections
11. **Re-analyze**: Risk score drops to 15/100, Status: READY
12. **Release**: Now able to release proposal

---

## 🔍 Testing Checklist

- [ ] AI status indicator shows "AI Enabled"
- [ ] Generate button creates content
- [ ] Improve button shows suggestions
- [ ] Risk analysis detects issues
- [ ] Release gate blocks when risk is high
- [ ] Compliance check validates proposal
- [ ] Error messages display properly
- [ ] Loading states show during AI calls

---

## 🚀 Quick Start

1. Make sure backend is running: `uvicorn app:app --reload`
2. Add one of the buttons above to your UI
3. Test with a real proposal
4. Iterate and improve!

---

## 💡 Tips

- **Loading States**: Always show loading indicators during AI calls (3-8 seconds)
- **Error Handling**: Gracefully handle AI failures with fallback messages
- **User Feedback**: Show success/error messages after each AI operation
- **Context**: Provide as much context as possible for better AI results
- **Caching**: Consider caching AI results to reduce API calls

---

**You're ready to integrate AI! 🎉**