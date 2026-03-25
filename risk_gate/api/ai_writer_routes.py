"""
AI Writer API Routes
REST API endpoints for AI-powered content generation
"""

from flask import Blueprint, request, jsonify
import logging
from datetime import datetime

# Import AI Writer module
from ..ai_writer import AIWriter

# Create Blueprint
ai_writer_bp = Blueprint('ai_writer', __name__, url_prefix='/risk-gate/ai')

# Initialize AI Writer
ai_writer = AIWriter()

logger = logging.getLogger(__name__)


@ai_writer_bp.route('/generate-section', methods=['POST'])
def generate_missing_section():
    """
    Generate a missing section using template context and embeddings
    
    Expected JSON payload:
    {
        "section_name": "executive_summary",
        "proposal_text": "Current proposal text...",
        "template_examples": ["Example 1", "Example 2"]  // Optional
    }
    """
    try:
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No JSON data provided',
                'message': 'Please provide JSON data in request body'
            }), 400
        
        # Validate required fields
        section_name = data.get('section_name')
        proposal_text = data.get('proposal_text')
        
        if not section_name:
            return jsonify({
                'success': False,
                'error': 'Missing section_name',
                'message': 'section_name is required'
            }), 400
        
        if not proposal_text:
            return jsonify({
                'success': False,
                'error': 'Missing proposal_text',
                'message': 'proposal_text is required'
            }), 400
        
        # Optional template examples
        template_examples = data.get('template_examples', [])
        
        logger.info(f"Generating section: {section_name}")
        
        # Generate the section
        result = ai_writer.generate_missing_section(
            section_name=section_name,
            proposal_text=proposal_text,
            template_examples=template_examples
        )
        
        # Add metadata
        result['timestamp'] = datetime.now().isoformat()
        result['section_name'] = section_name
        
        logger.info(f"Section generation completed: {result['success']}")
        
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error in generate-section endpoint: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'message': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


@ai_writer_bp.route('/improve-area', methods=['POST'])
def improve_weak_area():
    """
    Improve a weak area in the proposal
    
    Expected JSON payload:
    {
        "area_name": "weak_timeline",
        "proposal_text": "Current proposal text..."
    }
    """
    try:
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No JSON data provided',
                'message': 'Please provide JSON data in request body'
            }), 400
        
        # Validate required fields
        area_name = data.get('area_name')
        proposal_text = data.get('proposal_text')
        
        if not area_name:
            return jsonify({
                'success': False,
                'error': 'Missing area_name',
                'message': 'area_name is required'
            }), 400
        
        if not proposal_text:
            return jsonify({
                'success': False,
                'error': 'Missing proposal_text',
                'message': 'proposal_text is required'
            }), 400
        
        logger.info(f"Improving area: {area_name}")
        
        # Improve the area
        result = ai_writer.improve_weak_area(
            area_name=area_name,
            proposal_text=proposal_text
        )
        
        # Add metadata
        result['timestamp'] = datetime.now().isoformat()
        result['area_name'] = area_name
        
        logger.info(f"Area improvement completed: {result['success']}")
        
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error in improve-area endpoint: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'message': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


@ai_writer_bp.route('/correct-clause', methods=['POST'])
def correct_clause():
    """
    Correct an incorrect clause to match standard template wording
    
    Expected JSON payload:
    {
        "clause_name": "ip_clause",
        "proposal_text": "Current proposal text...",
        "template_clause": "Standard clause text..."  // Optional
    }
    """
    try:
        # Get request data
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No JSON data provided',
                'message': 'Please provide JSON data in request body'
            }), 400
        
        # Validate required fields
        clause_name = data.get('clause_name')
        proposal_text = data.get('proposal_text')
        
        if not clause_name:
            return jsonify({
                'success': False,
                'error': 'Missing clause_name',
                'message': 'clause_name is required'
            }), 400
        
        if not proposal_text:
            return jsonify({
                'success': False,
                'error': 'Missing proposal_text',
                'message': 'proposal_text is required'
            }), 400
        
        # Optional template clause
        template_clause = data.get('template_clause')
        
        logger.info(f"Correcting clause: {clause_name}")
        
        # Correct the clause
        result = ai_writer.correct_clause(
            clause_name=clause_name,
            proposal_text=proposal_text,
            template_clause=template_clause
        )
        
        # Add metadata
        result['timestamp'] = datetime.now().isoformat()
        result['clause_name'] = clause_name
        
        logger.info(f"Clause correction completed: {result['success']}")
        
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"Error in correct-clause endpoint: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'message': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


@ai_writer_bp.route('/status', methods=['GET'])
def get_ai_writer_status():
    """
    Get AI Writer system status and capabilities
    
    Returns:
        JSON with system status, available functions, and configuration
    """
    try:
        # Check system status
        status = {
            'success': True,
            'system_status': 'operational',
            'timestamp': datetime.now().isoformat(),
            'available_functions': [
                'generate_missing_section',
                'improve_weak_area',
                'correct_clause'
            ],
            'supported_sections': [
                'executive_summary',
                'scope',
                'deliverables',
                'timeline',
                'budget',
                'team',
                'assumptions',
                'ip_clause',
                'payment_terms',
                'termination'
            ],
            'supported_areas': [
                'weak_bios',
                'weak_timeline',
                'weak_budget',
                'weak_scope',
                'weak_deliverables'
            ],
            'supported_clauses': [
                'ip_clause',
                'payment_terms',
                'termination',
                'liability',
                'confidentiality',
                'warranty'
            ],
            'embedding_status': 'available' if ai_writer.embedder else 'unavailable',
            'template_status': 'available' if ai_writer.template_loader else 'unavailable',
            'template_count': len(ai_writer.template_loader.get_all_templates()) if ai_writer.template_loader else 0
        }
        
        logger.info("AI Writer status retrieved successfully")
        
        return jsonify(status), 200
        
    except Exception as e:
        logger.error(f"Error getting AI Writer status: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'message': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


@ai_writer_bp.route('/health', methods=['GET'])
def health_check():
    """
    Simple health check endpoint
    
    Returns:
        JSON with basic health status
    """
    try:
        health_status = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'service': 'AI Writer API',
            'version': '1.0.0'
        }
        
        return jsonify(health_status), 200
        
    except Exception as e:
        logger.error(f"Error in health check: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500


# Error handlers
@ai_writer_bp.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found',
        'message': 'The requested endpoint does not exist',
        'timestamp': datetime.now().isoformat()
    }), 404


@ai_writer_bp.errorhandler(405)
def method_not_allowed(error):
    """Handle 405 errors"""
    return jsonify({
        'success': False,
        'error': 'Method not allowed',
        'message': 'HTTP method not allowed for this endpoint',
        'timestamp': datetime.now().isoformat()
    }), 405


@ai_writer_bp.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        'success': False,
        'error': 'Internal server error',
        'message': 'An unexpected error occurred',
        'timestamp': datetime.now().isoformat()
    }), 500


# Request validation middleware
@ai_writer_bp.before_request
def validate_request():
    """Validate incoming requests"""
    # Check content type for POST requests
    if request.method in ['POST'] and not request.is_json:
        return jsonify({
            'success': False,
            'error': 'Invalid content type',
            'message': 'Content-Type must be application/json'
        }), 400
    
    # Log request
    logger.info(f"{request.method} {request.path} - {request.remote_addr}")


@ai_writer_bp.after_request
def log_response(response):
    """Log responses"""
    logger.info(f"{request.method} {request.path} - {response.status_code}")
    return response
