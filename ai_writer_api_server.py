#!/usr/bin/env python3
"""
AI Writer API Integration Example
Shows how to integrate the AI Writer routes into a Flask application
"""

from flask import Flask, request, jsonify
import logging
from datetime import datetime

# Import AI Writer routes
from risk_gate.api.ai_writer_routes import ai_writer_bp

# Create Flask app
app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Register AI Writer Blueprint
app.register_blueprint(ai_writer_bp)

# Add CORS headers (optional)
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

# Root endpoint
@app.route('/')
def home():
    return jsonify({
        'message': 'AI Writer API Server',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat(),
        'endpoints': {
            'generate_section': 'POST /risk-gate/ai/generate-section',
            'improve_area': 'POST /risk-gate/ai/improve-area',
            'correct_clause': 'POST /risk-gate/ai/correct-clause',
            'status': 'GET /risk-gate/ai/status',
            'health': 'GET /risk-gate/ai/health'
        }
    })

# Example usage endpoint
@app.route('/example', methods=['GET'])
def example_usage():
    """Show example API usage"""
    examples = {
        'generate_section': {
            'url': 'POST /risk-gate/ai/generate-section',
            'payload': {
                'section_name': 'executive_summary',
                'proposal_text': 'This is a basic proposal...',
                'template_examples': ['Example executive summary...']
            }
        },
        'improve_area': {
            'url': 'POST /risk-gate/ai/improve-area',
            'payload': {
                'area_name': 'weak_timeline',
                'proposal_text': 'Current proposal text with weak timeline...'
            }
        },
        'correct_clause': {
            'url': 'POST /risk-gate/ai/correct-clause',
            'payload': {
                'clause_name': 'payment_terms',
                'proposal_text': 'Current proposal text with clause...',
                'template_clause': 'Standard payment terms clause...'
            }
        }
    }
    
    return jsonify({
        'message': 'AI Writer API Usage Examples',
        'examples': examples,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("🚀 Starting AI Writer API Server...")
    print("📡 Server will be available at: http://localhost:5000")
    print("📖 API Documentation: http://localhost:5000/example")
    print("🔍 Health Check: http://localhost:5000/risk-gate/ai/health")
    print("📊 Status: http://localhost:5000/risk-gate/ai/status")
    print("\n🎯 Available Endpoints:")
    print("  POST /risk-gate/ai/generate-section")
    print("  POST /risk-gate/ai/improve-area")
    print("  POST /risk-gate/ai/correct-clause")
    print("  GET  /risk-gate/ai/status")
    print("  GET  /risk-gate/ai/health")
    print("\n⚠️  Press Ctrl+C to stop the server")
    
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True
    )
