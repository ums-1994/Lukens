# Risk Gate - AI-Powered Compound Risk Analysis System

## Overview

The Risk Gate system provides comprehensive proposal risk analysis using multiple analyzers to detect structural issues, clause alterations, weaknesses, and semantic problems. It combines all results into a compound risk score and provides actionable recommendations.

## Features

### 🔍 Multi-Layer Analysis
- **Structural Analysis**: Detects missing sections and structural issues
- **Clause Analysis**: Compares clauses against template standards
- **Weakness Analysis**: Identifies weak areas in proposals
- **Semantic AI Analysis**: Uses embeddings for deeper semantic risk detection

### 📊 Comprehensive Scoring
- Individual component scores
- Compound risk calculation
- Risk level classification (Minimal, Low, Medium, High, Critical)
- Confidence metrics

### 🎯 Smart Decision Making
- Auto-approve for low-risk proposals
- Manual review for medium-risk
- Requires changes for high-risk
- Auto-block for critical-risk

### 📁 Local Template System
- Uses local template files (no Cloudinary dependency)
- Supports TXT, DOCX, PDF formats
- Template-based clause comparison
- Configurable template directory

## Quick Start

### Basic Usage

```python
from risk_gate import analyze_proposal

# Analyze proposal text
result = analyze_proposal("Your proposal text here...")

# Check results
print(f"Risk Score: {result['risk_score']:.2f}")
print(f"Compound Risk: {result['compound_risk']}")
print(f"Decision: {result['decision']}")

# View issues
print(f"Missing sections: {result['missing_sections']}")
print(f"Altered clauses: {result['altered_clauses']}")
print(f"Weak areas: {result['weak_areas']}")
print(f"Semantic flags: {result['ai_semantic_flags']}")

# View recommendations
for rec in result['recommendations']:
    print(f"- {rec}")
```

### Advanced Usage

```python
from risk_gate import RiskGate

# Initialize with custom template path
risk_gate = RiskGate(templates_path="path/to/your/templates")

# Analyze proposal file
result = risk_gate.analyze_proposal_file("proposal.txt")

# Get quick assessment
quick = risk_gate.get_quick_risk_assessment(proposal_text)
print(f"Estimated risk: {quick['estimated_risk']}")

# Check system status
status = risk_gate.get_system_status()
print(f"Templates loaded: {status['templates_loaded']}")
```

## Installation & Setup

### Requirements
- Python 3.8+
- Required packages listed in requirements.txt

### Template Setup
1. Place template files in: `C:/Users/User/Downloads/Lukens-AI_RiskGate/risk_gate/Templates`
2. Supported formats: TXT, DOCX, PDF
3. Templates should contain standard proposal sections and clauses

### Dependencies
```bash
pip install -r requirements.txt
```

Key dependencies:
- `numpy` - Numerical operations
- `PyPDF2` - PDF text extraction (optional)
- `python-docx` - DOCX text extraction (optional)
- `sentence-transformers` - Embeddings (for semantic analysis)

## Module Structure

```
risk_gate/
├── analyzers/           # Analysis modules
│   ├── structural_analyzer.py
│   ├── clause_analyzer.py
│   ├── weakness_analyzer.py
│   └── semantic_ai_analyzer.py
├── risk_engine/         # Core risk engine
│   ├── risk_gate.py
│   └── risk_combiner.py
├── utils/              # Utilities
│   ├── file_loader.py
│   ├── template_loader.py
│   └── scoring.py
├── tests/              # Test suite
│   └── test_risk_gate.py
└── Templates/          # Template files
```

## Risk Analysis Components

### 1. Structural Analysis
Detects missing sections:
- Executive Summary
- Scope of Work
- Deliverables
- Timeline
- Budget
- Team Bios
- Assumptions

### 2. Clause Analysis
Compares against template clauses:
- IP Clause
- Payment Terms
- Termination Clause
- Liability
- Confidentiality
- Warranty

### 3. Weakness Analysis
Identifies weak areas:
- Team bios
- Timeline details
- Budget explanation
- Scope definition
- Deliverable clarity

### 4. Semantic AI Analysis
Deep semantic checks:
- Unrealistic timelines
- Budget/scope mismatches
- Incoherent deliverables
- Missing justifications
- Contradictions

## Risk Scoring

### Component Weights
- Structural: 25%
- Clause: 30%
- Weakness: 25%
- Semantic: 20%

### Risk Levels
- **Minimal** (0-0.3): Auto-approve
- **Low** (0.3-0.6): Manual review
- **Medium** (0.6-0.7): Requires changes
- **High** (0.7-0.85): Auto-block
- **Critical** (0.85+): Critical block

### Output Format
```python
{
    'success': True,
    'risk_score': 0.45,
    'compound_risk': False,
    'risk_level': 'medium',
    'decision': 'manual_review',
    'confidence': 0.8,
    'missing_sections': ['assumptions'],
    'altered_clauses': [],
    'weak_areas': [{'type': 'weak_timeline', 'severity': 'medium'}],
    'ai_semantic_flags': [],
    'summary': 'Proposal requires manual review...',
    'recommendations': ['Add assumptions section', 'Strengthen timeline'],
    'component_scores': {
        'structural': 0.8,
        'clause': 0.9,
        'weakness': 0.7,
        'semantic': 0.8
    }
}
```

## Testing

Run the test suite:
```bash
cd risk_gate
python -m pytest tests/
```

Or run tests directly:
```bash
python tests/test_risk_gate.py
```

## Demo

Run the demo script to see the system in action:
```bash
python demo_risk_gate.py
```

## Configuration

### Template Directory
Default: `C:/Users/User/Downloads/Lukens-AI_RiskGate/risk_gate/Templates`

Custom path:
```python
risk_gate = RiskGate(templates_path="your/custom/path")
```

### Risk Thresholds
Modify in `utils/scoring.py`:
```python
self.decision_thresholds = {
    'auto_approve': 0.2,
    'manual_review': 0.5,
    'requires_changes': 0.7,
    'auto_block': 0.85
}
```

## Integration

### Backend Integration
```python
# In your backend API
from risk_gate import analyze_proposal

@app.route('/analyze-proposal', methods=['POST'])
def analyze_proposal_endpoint():
    data = request.get_json()
    proposal_text = data.get('text')
    
    result = analyze_proposal(proposal_text)
    
    return jsonify({
        'risk_score': result['risk_score'],
        'compound_risk': result['compound_risk'],
        'summary': result['summary'],
        'recommendations': result['recommendations']
    })
```

### Batch Processing
```python
from risk_gate import RiskGate

risk_gate = RiskGate()

# Process multiple proposals
proposals = load_proposals_from_database()
for proposal in proposals:
    result = risk_gate.analyze_proposal(proposal.text)
    update_proposal_risk(proposal.id, result)
```

## Troubleshooting

### Common Issues

1. **Templates not loading**
   - Check template directory path
   - Ensure template files exist
   - Verify file permissions

2. **Semantic analysis not working**
   - Install sentence-transformers: `pip install sentence-transformers`
   - Check vector store availability

3. **DOCX/PDF files not reading**
   - Install dependencies: `pip install PyPDF2 python-docx`

### Debug Mode
```python
import logging
logging.basicConfig(level=logging.DEBUG)

# This will show detailed logs
result = analyze_proposal(proposal_text)
```

## Performance

### Typical Performance
- Quick assessment: < 1 second
- Full analysis: 2-5 seconds
- Batch processing: ~10 proposals/second

### Optimization Tips
- Use quick assessment for initial filtering
- Cache template loading
- Process proposals in batches for large volumes

## Support

For issues and questions:
1. Check the test suite for usage examples
2. Review the demo script for integration patterns
3. Enable debug logging for detailed error information

## License

Internal use only - proprietary risk analysis system.
