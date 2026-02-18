"""
Risk Gate Main Module
Main entry point for proposal risk analysis
"""

from typing import Dict, List, Any, Optional
import logging

from ..utils.file_loader import FileLoader
from ..utils.template_loader import TemplateLoader
from ..utils.scoring import RiskScorer
from ..analyzers.structural_analyzer import StructuralAnalyzer
from ..analyzers.clause_analyzer import ClauseAnalyzer
from ..analyzers.weakness_analyzer import WeaknessAnalyzer
from ..analyzers.semantic_ai_analyzer import SemanticAIAnalyzer
from ..risk_engine.risk_combiner import RiskCombiner


class RiskGate:
    """Main Risk Gate system for comprehensive proposal analysis"""
    
    def __init__(self, templates_path: str = None):
        """
        Initialize Risk Gate system
        
        Args:
            templates_path: Path to templates directory
        """
        self.logger = logging.getLogger(__name__)
        
        # Initialize components
        self.file_loader = FileLoader()
        self.template_loader = TemplateLoader(templates_path)
        self.structural_analyzer = StructuralAnalyzer()
        self.clause_analyzer = ClauseAnalyzer(self.template_loader)
        self.weakness_analyzer = WeaknessAnalyzer()
        self.semantic_analyzer = SemanticAIAnalyzer()
        self.risk_combiner = RiskCombiner(self.template_loader)
        
        self.logger.info("Risk Gate system initialized")
    
    def analyze_proposal(self, proposal_text: str) -> Dict[str, Any]:
        """
        Analyze a proposal for compound risk assessment
        
        Args:
            proposal_text: The proposal text to analyze
            
        Returns:
            Dict with comprehensive risk analysis results
        """
        try:
            self.logger.info("Starting proposal risk analysis")
            
            # Load and preprocess proposal text
            load_result = self.file_loader.load_proposal_text_direct(proposal_text)
            
            if not load_result['success']:
                return {
                    'success': False,
                    'error': load_result['error'],
                    'risk_score': 0.0,
                    'compound_risk': False,
                    'summary': f"Error loading proposal: {load_result['error']}"
                }
            
            processed_text = self.file_loader.preprocess_text(load_result['text'])
            
            # Run all analyzers
            analysis_results = {}
            
            # 1. Structural Analysis
            self.logger.info("Running structural analysis")
            analysis_results['structural_analysis'] = self.structural_analyzer.analyze_structure(processed_text)
            
            # 2. Clause Analysis
            self.logger.info("Running clause analysis")
            analysis_results['clause_analysis'] = self.clause_analyzer.analyze_clauses(processed_text)
            
            # 3. Weakness Analysis
            self.logger.info("Running weakness analysis")
            analysis_results['weakness_analysis'] = self.weakness_analyzer.analyze_weaknesses(processed_text)
            
            # 4. Semantic AI Analysis
            self.logger.info("Running semantic analysis")
            analysis_results['semantic_analysis'] = self.semantic_analyzer.analyze_semantic_risks(processed_text)
            
            # Combine results into final risk assessment
            self.logger.info("Combining risk analysis results")
            combined_results = self.risk_combiner.combine_risk_analysis(analysis_results)
            
            # Add success flag and metadata
            combined_results['success'] = True
            combined_results['proposal_metadata'] = load_result['metadata']
            
            self.logger.info(f"Risk analysis complete: {combined_results['risk_level']} risk level")
            
            return combined_results
            
        except Exception as e:
            self.logger.error(f"Error in proposal analysis: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'risk_score': 0.0,
                'compound_risk': False,
                'summary': f"Error in analysis: {str(e)}",
                'missing_sections': [],
                'altered_clauses': [],
                'weak_areas': [],
                'ai_semantic_flags': [],
                'recommendations': ["Please retry analysis or contact support"]
            }
    
    def analyze_proposal_file(self, file_path: str) -> Dict[str, Any]:
        """
        Analyze a proposal from file
        
        Args:
            file_path: Path to proposal file
            
        Returns:
            Dict with comprehensive risk analysis results
        """
        try:
            # Load proposal from file
            load_result = self.file_loader.load_proposal_text(file_path)
            
            if not load_result['success']:
                return {
                    'success': False,
                    'error': load_result['error'],
                    'risk_score': 0.0,
                    'compound_risk': False,
                    'summary': f"Error loading file: {load_result['error']}"
                }
            
            # Analyze the loaded text
            return self.analyze_proposal(load_result['text'])
            
        except Exception as e:
            self.logger.error(f"Error analyzing proposal file: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'risk_score': 0.0,
                'compound_risk': False,
                'summary': f"Error analyzing file: {str(e)}"
            }
    
    def get_quick_risk_assessment(self, proposal_text: str) -> Dict[str, Any]:
        """
        Get a quick risk assessment without full analysis
        
        Args:
            proposal_text: The proposal text to assess
            
        Returns:
            Dict with quick risk assessment
        """
        try:
            # Preprocess text
            processed_text = self.file_loader.preprocess_text(proposal_text)
            
            # Run quick checks
            quick_results = {
                'word_count': len(processed_text.split()),
                'section_count': len([line for line in processed_text.split('\n') if line.strip()]),
                'has_budget': any(keyword in processed_text.lower() for keyword in ['budget', 'cost', 'price', '$']),
                'has_timeline': any(keyword in processed_text.lower() for keyword in ['timeline', 'schedule', 'deadline', 'milestone']),
                'has_scope': any(keyword in processed_text.lower() for keyword in ['scope', 'work', 'deliverables', 'objectives']),
                'has_team': any(keyword in processed_text.lower() for keyword in ['team', 'staff', 'personnel', 'bios']),
                'estimated_risk': 'medium'  # Default estimate
            }
            
            # Simple risk estimation
            missing_elements = []
            if not quick_results['has_budget']:
                missing_elements.append('budget')
            if not quick_results['has_timeline']:
                missing_elements.append('timeline')
            if not quick_results['has_scope']:
                missing_elements.append('scope')
            if not quick_results['has_team']:
                missing_elements.append('team')
            
            if len(missing_elements) >= 3:
                quick_results['estimated_risk'] = 'high'
            elif len(missing_elements) >= 2:
                quick_results['estimated_risk'] = 'medium'
            elif len(missing_elements) >= 1:
                quick_results['estimated_risk'] = 'low'
            else:
                quick_results['estimated_risk'] = 'minimal'
            
            quick_results['missing_elements'] = missing_elements
            quick_results['completeness_score'] = (4 - len(missing_elements)) / 4.0
            
            return quick_results
            
        except Exception as e:
            self.logger.error(f"Error in quick risk assessment: {str(e)}")
            return {
                'error': str(e),
                'estimated_risk': 'unknown',
                'missing_elements': [],
                'completeness_score': 0.0
            }
    
    def get_system_status(self) -> Dict[str, Any]:
        """
        Get system status and configuration
        
        Returns:
            Dict with system status information
        """
        try:
            return {
                'system_status': 'operational',
                'templates_loaded': len(self.template_loader.get_all_templates()),
                'templates_path': self.template_loader.templates_path,
                'analyzers_available': [
                    'structural_analyzer',
                    'clause_analyzer', 
                    'weakness_analyzer',
                    'semantic_ai_analyzer'
                ],
                'risk_engine': 'operational',
                'vector_store_available': self.semantic_analyzer.embedder is not None,
                'version': '1.0.0'
            }
            
        except Exception as e:
            self.logger.error(f"Error getting system status: {str(e)}")
            return {
                'system_status': 'error',
                'error': str(e)
            }
    
    def reload_templates(self):
        """Reload template files"""
        try:
            self.template_loader.reload_templates()
            self.clause_analyzer.template_loader = self.template_loader
            self.logger.info("Templates reloaded successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Error reloading templates: {str(e)}")
            return False


# Convenience function for direct usage
def analyze_proposal(text: str) -> Dict[str, Any]:
    """
    Convenience function to analyze a proposal
    
    Args:
        text: Proposal text to analyze
        
    Returns:
        Dict with risk analysis results
    """
    risk_gate = RiskGate()
    return risk_gate.analyze_proposal(text)


def analyze_proposal_file(file_path: str) -> Dict[str, Any]:
    """
    Convenience function to analyze a proposal file
    
    Args:
        file_path: Path to proposal file
        
    Returns:
        Dict with risk analysis results
    """
    risk_gate = RiskGate()
    return risk_gate.analyze_proposal_file(file_path)
