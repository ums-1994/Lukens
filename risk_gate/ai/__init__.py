"""
AI Package Initialization
"""

from .model_client import HFModelClient, get_model_client
from .risk_analyzer import RiskAnalyzer, get_risk_analyzer

__version__ = "1.0.0"

# Main exports
__all__ = [
    'HFModelClient',
    'get_model_client',
    'RiskAnalyzer',
    'get_risk_analyzer'
]
