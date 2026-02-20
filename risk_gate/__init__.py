"""
Risk Gate Package Initialization
"""

from .risk_engine.risk_gate import RiskGate, analyze_proposal, analyze_proposal_file
from .utils.file_loader import FileLoader
from .utils.template_loader import TemplateLoader
from .utils.scoring import RiskScorer
from .analyzers.structural_analyzer import StructuralAnalyzer
from .analyzers.clause_analyzer import ClauseAnalyzer
from .analyzers.weakness_analyzer import WeaknessAnalyzer
from .analyzers.semantic_ai_analyzer import SemanticAIAnalyzer
from .risk_engine.risk_combiner import RiskCombiner
from .risk_engine.compound_risk import CompoundRiskDetector, Issue
from .risk_engine.ai_writer_helper import AIWriterGlobalHelper
from .ai_writer import AIWriter
from .ai.model_client import HFModelClient, get_model_client
from .ai.risk_analyzer import RiskAnalyzer, get_risk_analyzer

__version__ = "2.0.0"
__author__ = "Risk Gate Team"

# Main exports
__all__ = [
    # Main entry point
    'RiskGate',
    'analyze_proposal',
    'analyze_proposal_file',
    
    # Utilities
    'FileLoader',
    'TemplateLoader',
    'RiskScorer',
    
    # Analyzers
    'StructuralAnalyzer',
    'ClauseAnalyzer',
    'WeaknessAnalyzer',
    'SemanticAIAnalyzer',
    
    # Risk Engine
    'RiskCombiner',
    'CompoundRiskDetector',
    'Issue',
    
    # AI Writer
    'AIWriter',
    'AIWriterGlobalHelper',
    
    # HF Model Inference
    'HFModelClient',
    'get_model_client',
    'RiskAnalyzer',
    'get_risk_analyzer'
]