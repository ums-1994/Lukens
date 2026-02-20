# AI Writer Module

The AI Writer module provides intelligent content generation capabilities for proposals using local embeddings and template matching. It powers "Fix with AI / Add with AI" functionalities without requiring external APIs.

## Features

- **Local Embedding Support**: Uses `all-MiniLM-L6-v2` embeddings for semantic analysis
- **Template-Based Generation**: Leverages existing proposal templates for context-aware content
- **ChromaDB Integration**: Vector database for efficient similarity search
- **Fallback Generation**: Works even when embedding system is unavailable
- **REST API**: Complete HTTP API for easy integration

## Core Functions

### 1. `generate_missing_section`
Generates complete missing sections using template context and embeddings.

**Parameters:**
- `section_name`: Name of section to generate (executive_summary, scope, deliverables, etc.)
- `proposal_text`: Current proposal text for context
- `template_examples`: Optional list of template examples

**Returns:**
```json
{
  "success": true,
  "generated_text": "Generated section content...",
  "reasoning": "Generated executive_summary using 3 template examples with 85% confidence",
  "confidence": 0.85
}
```

### 2. `improve_weak_area`
Strengthens weak or incomplete proposal areas.

**Parameters:**
- `area_name`: Name of weak area (weak_timeline, weak_budget, weak_bios, etc.)
- `proposal_text`: Current proposal text

**Returns:**
```json
{
  "success": true,
  "generated_text": "Improved timeline content...",
  "reasoning": "Improved weak_timeline using 2 strong examples with 72% confidence",
  "confidence": 0.72
}
```

### 3. `correct_clause`
Rewrites incorrect clauses to match standard template wording.

**Parameters:**
- `clause_name`: Name of clause (payment_terms, ip_clause, termination, etc.)
- `proposal_text`: Current proposal text
- `template_clause`: Optional template clause to match

**Returns:**
```json
{
  "success": true,
  "generated_text": "Corrected payment terms clause...",
  "reasoning": "Corrected payment_terms clause to match template standards with 90% confidence",
  "confidence": 0.90
}
```

## API Endpoints

### POST `/risk-gate/ai/generate-section`
Generate missing proposal sections.

**Request:**
```json
{
  "section_name": "executive_summary",
  "proposal_text": "Current proposal text...",
  "template_examples": ["Example 1", "Example 2"]
}
```

### POST `/risk-gate/ai/improve-area`
Improve weak areas in proposals.

**Request:**
```json
{
  "area_name": "weak_timeline",
  "proposal_text": "Current proposal text..."
}
```

### POST `/risk-gate/ai/correct-clause`
Correct incorrect clauses.

**Request:**
```json
{
  "clause_name": "payment_terms",
  "proposal_text": "Current proposal text...",
  "template_clause": "Standard clause text..."
}
```

### GET `/risk-gate/ai/status`
Get system status and capabilities.

**Response:**
```json
{
  "success": true,
  "system_status": "operational",
  "available_functions": ["generate_missing_section", "improve_weak_area", "correct_clause"],
  "supported_sections": ["executive_summary", "scope", "deliverables", ...],
  "embedding_status": "available",
  "template_count": 25
}
```

### GET `/risk-gate/ai/health`
Simple health check endpoint.

## Supported Content Types

### Sections
- `executive_summary`
- `scope`
- `deliverables`
- `timeline`
- `budget`
- `team`
- `assumptions`

### Weak Areas
- `weak_bios`
- `weak_timeline`
- `weak_budget`
- `weak_scope`
- `weak_deliverables`

### Clauses
- `ip_clause`
- `payment_terms`
- `termination`
- `liability`
- `confidentiality`
- `warranty`

## Usage Examples

### Python Integration
```python
from risk_gate.ai_writer import AIWriter

# Initialize AI Writer
ai_writer = AIWriter()

# Generate missing section
result = ai_writer.generate_missing_section(
    section_name="executive_summary",
    proposal_text="Your proposal text..."
)

if result['success']:
    print(f"Generated: {result['generated_text']}")
    print(f"Confidence: {result['confidence']}")
```

### API Integration
```python
import requests

# Generate section via API
response = requests.post('http://localhost:5000/risk-gate/ai/generate-section', json={
    'section_name': 'executive_summary',
    'proposal_text': 'Your proposal text...'
})

result = response.json()
if result['success']:
    print(f"Generated: {result['generated_text']}")
```

### Flask Integration
```python
from flask import Flask
from risk_gate.api.ai_writer_routes import ai_writer_bp

app = Flask(__name__)
app.register_blueprint(ai_writer_bp)

# AI Writer endpoints now available at:
# POST /risk-gate/ai/generate-section
# POST /risk-gate/ai/improve-area
# POST /risk-gate/ai/correct-clause
```

## Configuration

### Template Directory
Default: `C:/Users/User/Downloads/Lukens-AI_RiskGate/risk_gate/Templates`

### Embedding Model
- Model: `sentence-transformers/all-MiniLM-L6-v2`
- Dimensions: 384
- Local only (no external API calls)

### Vector Database
- System: ChromaDB
- Collection: `proposal_templates`
- Local storage only

## Dependencies

### Required
- `numpy`
- `PyPDF2`
- `python-docx`
- `sentence-transformers`
- `chromadb`

### Optional
- `flask` (for API server)
- `requests` (for API client)

## Testing

Run the test suite:
```bash
# Test core functionality
python test_ai_writer.py

# Test API endpoints
python test_ai_writer_api.py

# Start API server
python ai_writer_api_server.py
```

## Error Handling

The system includes comprehensive error handling:

- **Fallback Generation**: Works without embeddings
- **Graceful Degradation**: Reduces functionality when components unavailable
- **Detailed Logging**: Comprehensive error messages and reasoning
- **Confidence Scoring**: Indicates reliability of generated content

## Performance

- **Generation Time**: ~1-3 seconds per request
- **Memory Usage**: ~500MB for embeddings
- **Template Loading**: ~2 seconds initial load
- **Concurrent Requests**: Supports multiple simultaneous requests

## Security

- **No External APIs**: All processing is local
- **No Data Transmission**: No data sent to external services
- **Template Isolation**: Uses only local template files
- **Input Validation**: Comprehensive request validation

## Integration Examples

### Frontend Integration
```javascript
// Generate section via fetch
const response = await fetch('/risk-gate/ai/generate-section', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    section_name: 'executive_summary',
    proposal_text: proposalText
  })
});

const result = await response.json();
if (result.success) {
  // Use generated content
  updateProposalSection(result.generated_text);
}
```

### Backend Integration
```python
# In your existing Flask app
from risk_gate.api.ai_writer_routes import ai_writer_bp

app.register_blueprint(ai_writer_bp)

# Now available in your existing application
```

## Troubleshooting

### Common Issues

1. **"Vector store not available"**
   - Install dependencies: `pip install sentence-transformers chromadb`
   - System will work with fallback generation

2. **"Template loading failed"**
   - Check template directory path
   - Ensure template files exist and are readable

3. **"Low confidence scores"**
   - Provide more template examples
   - Ensure proposal text has sufficient context

### Debug Mode
Enable debug logging:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## License

This module is part of the Risk Gate system and follows the same licensing terms.
