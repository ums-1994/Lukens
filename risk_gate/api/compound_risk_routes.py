"""
Compound Risk Detection API Routes
Provides endpoints for compound risk analysis and AI Writer global fixes
"""

from flask import Blueprint, request, jsonify
import logging
from typing import Dict, Any

from ..risk_engine.compound_risk import CompoundRiskDetector, Issue
from ..risk_engine.ai_writer_helper import AIWriterGlobalHelper
from ..risk_engine.risk_gate import RiskGate

# Create Blueprint
compound_risk_bp = Blueprint('compound_risk', __name__, url_prefix='/api/compound-risk')

# Initialize components
compound_risk_detector = CompoundRiskDetector()
ai_writer_helper = AIWriterGlobalHelper()
risk_gate = RiskGate()

logger = logging.getLogger(__name__)


@compound_risk_bp.route('/analyze', methods=['POST'])
def analyze_compound_risk():
    """
    Analyze compound risk for a proposal
    
    Request body:
    {
        "proposal_text": "Full proposal text here",
        "include_ai_fixes": true  # Optional, defaults to false
    }
    
    Returns:
    {
        "success": true,
        "overall_score": 0.5,
        "compound_risk": {
            "is_high": false,
            "score": 4.5,
            "summary": "...",
            "recommended_action": "...",
            "ai_global_suggestion": "...",
            "theme_breakdown": {...}
        },
        "issues": [...],
        "analysis_details": {...},
        "ai_global_fix": {...},  # Only if include_ai_fixes is true and risk is high
        "release_blocked": false,
        "block_reason": null
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'proposal_text' not in data:
            return jsonify({
                'success': False,
                'error': 'Missing proposal_text in request body'
            }), 400
        
        proposal_text = data['proposal_text']
        include_ai_fixes = data.get('include_ai_fixes', False)
        
        # Run full risk analysis with compound risk detection
        analysis_result = risk_gate.analyze_proposal(proposal_text)
        
        # If AI fixes are requested and compound risk is high, generate fixes
        if include_ai_fixes and analysis_result.get('compound_risk', {}).get('is_high', False):
            issues = analysis_result.get('issues', [])
            ai_fix_result = ai_writer_helper.write_global_summary(issues, proposal_text)
            analysis_result['ai_global_fix'] = ai_fix_result
        
        return jsonify(analysis_result)
        
    except Exception as e:
        logger.error(f"Error in compound risk analysis: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'compound_risk': {
                'is_high': True,
                'score': 10.0,
                'summary': f'Error during analysis: {str(e)}',
                'recommended_action': 'BLOCK proposal release. Analysis failed.',
                'ai_global_suggestion': 'Please retry analysis or contact support.',
                'theme_breakdown': {}
            },
            'issues': [],
            'release_blocked': True,
            'block_reason': f'Analysis error: {str(e)}'
        }), 500


@compound_risk_bp.route('/quick-assess', methods=['POST'])
def quick_compound_risk_assessment():
    """
    Quick compound risk assessment without full analysis
    
    Request body:
    {
        "issues": [
            {
                "type": "structural",
                "severity": "high",
                "theme": "content_completeness",
                "description": "Missing executive summary",
                "location": "executive_summary",
                "confidence": 0.9
            }
        ]
    }
    
    Returns:
    {
        "success": true,
        "compound_risk": {
            "is_high": false,
            "score": 4.5,
            "summary": "...",
            "recommended_action": "...",
            "ai_global_suggestion": "...",
            "theme_breakdown": {...}
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'issues' not in data:
            return jsonify({
                'success': False,
                'error': 'Missing issues array in request body'
            }), 400
        
        issues_data = data['issues']
        
        # Convert dict issues to Issue objects
        issues = []
        for issue_data in issues_data:
            issue = Issue(
                type=issue_data.get('type', 'unknown'),
                severity=issue_data.get('severity', 'medium'),
                theme=issue_data.get('theme', 'other'),
                description=issue_data.get('description', 'Unknown issue'),
                location=issue_data.get('location'),
                confidence=issue_data.get('confidence', 0.5),
                weight=issue_data.get('weight', 1.0)
            )
            issues.append(issue)
        
        # Calculate compound risk
        compound_result = compound_risk_detector.calculate_compound_risk(issues)
        
        return jsonify({
            'success': True,
            'compound_risk': compound_result
        })
        
    except Exception as e:
        logger.error(f"Error in quick compound risk assessment: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@compound_risk_bp.route('/generate-fixes', methods=['POST'])
def generate_ai_global_fixes():
    """
    Generate AI Writer global fixes for identified issues
    
    Request body:
    {
        "issues": [...],
        "proposal_text": "Full proposal text here"
    }
    
    Returns:
    {
        "success": true,
        "global_summary": "...",
        "fixes": {...},
        "action_plan": "...",
        "total_issues_fixed": 4,
        "confidence": 0.75
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'issues' not in data or 'proposal_text' not in data:
            return jsonify({
                'success': False,
                'error': 'Missing issues array or proposal_text in request body'
            }), 400
        
        issues = data['issues']
        proposal_text = data['proposal_text']
        
        # Generate global fixes
        fix_result = ai_writer_helper.write_global_summary(issues, proposal_text)
        
        return jsonify(fix_result)
        
    except Exception as e:
        logger.error(f"Error generating AI global fixes: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'global_summary': '',
            'fixes': {},
            'action_plan': '',
            'total_issues_fixed': 0,
            'confidence': 0.0
        }), 500


@compound_risk_bp.route('/status', methods=['GET'])
def get_compound_risk_status():
    """
    Get compound risk system status
    
    Returns:
    {
        "success": true,
        "system_status": "operational",
        "compound_risk_detector": "operational",
        "ai_writer_helper": "operational",
        "risk_gate": "operational",
        "version": "2.0.0",
        "features": [...]
    }
    """
    try:
        # Get system status from risk gate
        system_status = risk_gate.get_system_status()
        
        return jsonify({
            'success': True,
            'system_status': system_status['system_status'],
            'compound_risk_detector': 'operational',
            'ai_writer_helper': 'operational',
            'risk_gate': system_status['risk_engine'],
            'version': system_status['version'],
            'features': system_status.get('features', [])
        })
        
    except Exception as e:
        logger.error(f"Error getting compound risk status: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
            'system_status': 'error'
        }), 500


@compound_risk_bp.route('/health', methods=['GET'])
def health_check():
    """
    Simple health check endpoint
    
    Returns:
    {
        "status": "healthy",
        "timestamp": "2025-02-18T07:30:00Z"
    }
    """
    from datetime import datetime
    
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })


@compound_risk_bp.route('/thresholds', methods=['GET'])
def get_risk_thresholds():
    """
    Get current risk thresholds used by the compound risk detector
    
    Returns:
    {
        "success": true,
        "compound_risk_threshold": 7.0,
        "theme_weights": {...},
        "severity_scores": {...}
    }
    """
    try:
        return jsonify({
            'success': True,
            'compound_risk_threshold': compound_risk_detector.compound_risk_threshold,
            'theme_weights': compound_risk_detector.theme_weights,
            'severity_scores': compound_risk_detector.severity_scores
        })
        
    except Exception as e:
        logger.error(f"Error getting risk thresholds: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@compound_risk_bp.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404


@compound_risk_bp.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500
