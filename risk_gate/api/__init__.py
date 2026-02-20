"""
Risk Gate API Package Initialization
"""

from .ai_writer_routes import ai_writer_bp
from .compound_risk_routes import compound_risk_bp
from .analyze_endpoint import analyze_router

# Export blueprints
__all__ = [
    'ai_writer_bp',
    'compound_risk_bp',
    'analyze_router'
]
