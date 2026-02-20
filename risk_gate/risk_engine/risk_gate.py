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
from ..risk_engine.compound_risk import CompoundRiskDetector, Issue
from ..risk_engine.ai_writer_helper import AIWriterGlobalHelper


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
        self.compound_risk_detector = CompoundRiskDetector()
        self.ai_writer_helper = AIWriterGlobalHelper()
        
        self.logger.info("Risk Gate system initialized with compound risk detection")
    
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
            
            # Convert analysis results to Issue objects for compound risk detection
            issues = self._convert_to_issues(analysis_results)
            
            # Calculate compound risk
            self.logger.info("Calculating compound risk")
            compound_risk_result = self.compound_risk_detector.calculate_compound_risk(issues)
            
            # Generate AI Writer global suggestions if compound risk is high
            ai_global_fix = None
            if compound_risk_result['is_high']:
                self.logger.info("Generating AI Writer global fixes for high compound risk")
                ai_global_fix = self.ai_writer_helper.write_global_summary(
                    issues, processed_text
                )
            
            # Build final assessment output
            final_result = {
                'success': True,
                'overall_score': combined_results.get('risk_score', 0),
                'compound_risk': compound_risk_result,
                'issues': self._format_issues_for_output(issues),
                'analysis_details': analysis_results,
                'ai_global_fix': ai_global_fix,
                'proposal_metadata': load_result['metadata'],
                'recommendations': combined_results.get('recommendations', []),
                'risk_level': combined_results.get('risk_level', 'unknown')
            }
            
            # Block proposal release if compound risk is high
            if compound_risk_result['is_high']:
                final_result['release_blocked'] = True
                final_result['block_reason'] = compound_risk_result['summary']
            else:
                final_result['release_blocked'] = False
                final_result['block_reason'] = None
            
            self.logger.info(f"Risk analysis complete: {final_result['risk_level']} risk level, compound risk: {compound_risk_result['is_high']}")
            
            return final_result
            
        except Exception as e:
            self.logger.error(f"Error in proposal analysis: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'overall_score': 0,
                'compound_risk': {
                    'is_high': True,  # Conservative approach
                    'score': 10.0,
                    'summary': f'Error during risk assessment: {str(e)}',
                    'recommended_action': 'BLOCK proposal release. Manual review required due to assessment error.',
                    'ai_global_suggestion': 'Risk assessment failed. Please review proposal manually and retry assessment.',
                    'theme_breakdown': {}
                },
                'issues': [],
                'analysis_details': {},
                'ai_global_fix': None,
                'release_blocked': True,
                'block_reason': f'Assessment error: {str(e)}',
                'recommendations': ["Please retry analysis or contact support"],
                'risk_level': 'error'
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
                    'overall_score': 0,
                    'compound_risk': {
                        'is_high': True,
                        'score': 10.0,
                        'summary': f"Error loading file: {load_result['error']}",
                        'recommended_action': 'BLOCK proposal release. File loading failed.',
                        'ai_global_suggestion': 'Please check file format and retry.',
                        'theme_breakdown': {}
                    },
                    'issues': [],
                    'analysis_details': {},
                    'ai_global_fix': None,
                    'release_blocked': True,
                    'block_reason': f'File loading error: {load_result["error"]}',
                    'recommendations': ["Check file format and retry"],
                    'risk_level': 'error'
                }
            
            # Analyze the loaded text
            return self.analyze_proposal(load_result['text'])
            
        except Exception as e:
            self.logger.error(f"Error analyzing proposal file: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'overall_score': 0,
                'compound_risk': {
                    'is_high': True,
                    'score': 10.0,
                    'summary': f"Error analyzing file: {str(e)}",
                    'recommended_action': 'BLOCK proposal release. File analysis failed.',
                    'ai_global_suggestion': 'Please check file and retry analysis.',
                    'theme_breakdown': {}
                },
                'issues': [],
                'analysis_details': {},
                'ai_global_fix': None,
                'release_blocked': True,
                'block_reason': f'File analysis error: {str(e)}',
                'recommendations': ["Check file and retry analysis"],
                'risk_level': 'error'
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
                'compound_risk_detector': 'operational',
                'ai_writer_helper': 'operational',
                'vector_store_available': self.semantic_analyzer.embedder is not None,
                'version': '2.0.0',
                'features': [
                    'compound_risk_detection',
                    'ai_writer_integration',
                    'local_embeddings_only',
                    'template_based_analysis'
                ]
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
    
    def _convert_to_issues(self, analysis_results: Dict[str, Any]) -> List[Issue]:
        """Convert analysis results to Issue objects for compound risk detection"""
        issues = []
        
        try:
            # Convert structural analysis issues
            structural = analysis_results.get('structural_analysis', {})
            if isinstance(structural, dict):
                missing_sections = structural.get('missing_sections', [])
                if isinstance(missing_sections, list):
                    for missing_section in missing_sections:
                        if isinstance(missing_section, dict):
                            issues.append(Issue(
                                type='structural',
                                severity=self._determine_severity(missing_section.get('importance', 'medium')),
                                theme='content_completeness',
                                description=f"Missing section: {missing_section.get('name', 'Unknown')}",
                                location=missing_section.get('name'),
                                confidence=missing_section.get('confidence', 0.8)
                            ))
                        else:
                            # Handle string case
                            issues.append(Issue(
                                type='structural',
                                severity='medium',
                                theme='content_completeness',
                                description=f"Missing section: {str(missing_section)}",
                                location=str(missing_section),
                                confidence=0.8
                            ))
            
            # Convert clause analysis issues
            clause = analysis_results.get('clause_analysis', {})
            if isinstance(clause, dict):
                altered_clauses = clause.get('altered_clauses', [])
                if isinstance(altered_clauses, list):
                    for altered_clause in altered_clauses:
                        if isinstance(altered_clause, dict):
                            issues.append(Issue(
                                type='clause',
                                severity=self._determine_severity(altered_clause.get('similarity_score', 0.5), inverse=True),
                                theme='legal_deviation',
                                description=f"Altered clause: {altered_clause.get('name', 'Unknown')}",
                                location=altered_clause.get('name'),
                                confidence=altered_clause.get('similarity_score', 0.5)
                            ))
                        else:
                            # Handle string case
                            issues.append(Issue(
                                type='clause',
                                severity='medium',
                                theme='legal_deviation',
                                description=f"Altered clause: {str(altered_clause)}",
                                location=str(altered_clause),
                                confidence=0.7
                            ))
            
            # Convert weakness analysis issues
            weakness = analysis_results.get('weakness_analysis', {})
            if isinstance(weakness, dict):
                weak_areas = weakness.get('weak_areas', [])
                if isinstance(weak_areas, list):
                    for weak_area in weak_areas:
                        if isinstance(weak_area, dict):
                            issues.append(Issue(
                                type='weakness',
                                severity=self._determine_severity(weak_area.get('severity', 'medium')),
                                theme='quality_issues',
                                description=f"Weak area: {weak_area.get('area', 'Unknown')}",
                                location=weak_area.get('area'),
                                confidence=weak_area.get('confidence', 0.7)
                            ))
                        else:
                            # Handle string case
                            issues.append(Issue(
                                type='weakness',
                                severity='medium',
                                theme='quality_issues',
                                description=f"Weak area: {str(weak_area)}",
                                location=str(weak_area),
                                confidence=0.7
                            ))
            
            # Convert semantic analysis issues
            semantic = analysis_results.get('semantic_analysis', {})
            if isinstance(semantic, dict):
                semantic_flags = semantic.get('semantic_flags', [])
                if isinstance(semantic_flags, list):
                    for semantic_flag in semantic_flags:
                        if isinstance(semantic_flag, dict):
                            issues.append(Issue(
                                type='semantic',
                                severity=self._determine_severity(semantic_flag.get('risk_level', 'medium')),
                                theme='semantic_risk',
                                description=semantic_flag.get('description', 'Semantic issue detected'),
                                location=semantic_flag.get('location'),
                                confidence=semantic_flag.get('confidence', 0.6)
                            ))
                        else:
                            # Handle string case
                            issues.append(Issue(
                                type='semantic',
                                severity='medium',
                                theme='semantic_risk',
                                description=str(semantic_flag),
                                location='semantic_area',
                                confidence=0.6
                            ))
        
        except Exception as e:
            self.logger.error(f"Error converting analysis results to issues: {str(e)}")
            # Return a generic issue if conversion fails
            issues.append(Issue(
                type='conversion_error',
                severity='high',
                theme='system_error',
                description=f'Error converting analysis results: {str(e)}',
                location='system',
                confidence=0.0
            ))
        
        return issues
    
    def _determine_severity(self, indicator, inverse: bool = False) -> str:
        """Determine severity from various indicators"""
        if isinstance(indicator, str):
            return indicator.lower()
        elif isinstance(indicator, (int, float)):
            if inverse:
                # For similarity scores (lower = more severe)
                if indicator < 0.3:
                    return 'critical'
                elif indicator < 0.5:
                    return 'high'
                elif indicator < 0.7:
                    return 'medium'
                else:
                    return 'low'
            else:
                # For risk scores (higher = more severe)
                if indicator >= 0.8:
                    return 'critical'
                elif indicator >= 0.6:
                    return 'high'
                elif indicator >= 0.4:
                    return 'medium'
                else:
                    return 'low'
        else:
            return 'medium'  # Default
    
    def _format_issues_for_output(self, issues: List[Issue]) -> List[Dict[str, Any]]:
        """Format Issue objects for JSON output"""
        formatted_issues = []
        
        for issue in issues:
            formatted_issues.append({
                'type': issue.type,
                'severity': issue.severity,
                'theme': issue.theme,
                'description': issue.description,
                'location': issue.location,
                'confidence': issue.confidence,
                'weight': issue.weight
            })
        
        return formatted_issues


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
