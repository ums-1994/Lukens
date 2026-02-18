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
from .ai_writer import AIWriter

__version__ = "1.0.0"
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
    
    # AI Writer
    'AIWriter'
]