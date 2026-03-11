"""
Scoring Module
Implements risk scoring calculations for the Risk Gate system
"""

from typing import Dict, List, Any, Optional
import logging
import math


class RiskScorer:
    """Handles risk scoring calculations for different analysis components"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
        # Risk weights for different components
        self.risk_weights = {
            'structural': 0.25,      # Missing sections, structure issues
            'clause': 0.30,         # Altered or missing clauses
            'weakness': 0.25,       # Weak areas in proposal
            'semantic': 0.20        # Semantic and AI-detected issues
        }
        
        # Risk thresholds
        self.thresholds = {
            'low_risk': 0.3,        # Below this is low risk
            'medium_risk': 0.6,     # Below this is medium risk
            'high_risk': 0.8,       # Below this is high risk
            'critical_risk': 0.9    # Above this is critical risk
        }
    
    def calculate_structural_risk_score(self, structural_analysis: Dict[str, Any]) -> float:
        """
        Calculate structural risk score from structural analysis
        
        Args:
            structural_analysis: Results from structural analyzer
            
        Returns:
            Structural risk score (0.0 to 1.0)
        """
        try:
            if 'structural_score' in structural_analysis:
                # Convert structural score to risk score
                structural_score = structural_analysis['structural_score']
                risk_score = 1.0 - structural_score
                
                # Adjust for missing critical sections
                missing_sections = structural_analysis.get('missing_sections', [])
                critical_sections = ['scope', 'budget', 'deliverables', 'timeline']
                
                critical_missing = [s for s in missing_sections if s in critical_sections]
                if critical_missing:
                    critical_penalty = len(critical_missing) * 0.1
                    risk_score = min(1.0, risk_score + critical_penalty)
                
                return risk_score
            
            return 0.0
            
        except Exception as e:
            self.logger.error(f"Error calculating structural risk score: {str(e)}")
            return 0.0
    
    def calculate_clause_risk_score(self, clause_analysis: Dict[str, Any]) -> float:
        """
        Calculate clause risk score from clause analysis
        
        Args:
            clause_analysis: Results from clause analyzer
            
        Returns:
            Clause risk score (0.0 to 1.0)
        """
        try:
            if 'clause_risk_score' in clause_analysis:
                return clause_analysis['clause_risk_score']
            
            # Calculate from altered and missing clauses
            altered_clauses = clause_analysis.get('altered_clauses', [])
            missing_clauses = clause_analysis.get('missing_clauses', [])
            
            # Weight altered clauses more heavily than missing ones
            altered_weight = 0.7
            missing_weight = 0.3
            
            # Normalize by total possible clauses (6 main types)
            total_possible = 6
            
            altered_score = (len(altered_clauses) * altered_weight) / total_possible
            missing_score = (len(missing_clauses) * missing_weight) / total_possible
            
            # Add severity weighting
            severity_multiplier = 1.0
            for clause in altered_clauses:
                if clause.get('severity') == 'high':
                    severity_multiplier += 0.1
            for clause in missing_clauses:
                if clause.get('severity') == 'high':
                    severity_multiplier += 0.15
            
            combined_score = altered_score + missing_score
            final_score = min(1.0, combined_score * severity_multiplier)
            
            return final_score
            
        except Exception as e:
            self.logger.error(f"Error calculating clause risk score: {str(e)}")
            return 0.0
    
    def calculate_weakness_risk_score(self, weakness_analysis: Dict[str, Any]) -> float:
        """
        Calculate weakness risk score from weakness analysis
        
        Args:
            weakness_analysis: Results from weakness analyzer
            
        Returns:
            Weakness risk score (0.0 to 1.0)
        """
        try:
            if 'overall_weakness_score' in weakness_analysis:
                return weakness_analysis['overall_weakness_score']
            
            # Calculate from weak areas
            weak_areas = weakness_analysis.get('weak_areas', [])
            
            if not weak_areas:
                return 0.0
            
            # Weight by severity
            severity_weights = {'high': 1.0, 'medium': 0.6, 'low': 0.3}
            total_weighted_score = 0.0
            
            for area in weak_areas:
                severity = area.get('severity', 'medium')
                score = area.get('score', 0.5)
                weight = severity_weights.get(severity, 0.6)
                
                total_weighted_score += score * weight
            
            # Normalize by number of possible weak areas (5)
            normalized_score = total_weighted_score / 5.0
            
            return min(1.0, normalized_score)
            
        except Exception as e:
            self.logger.error(f"Error calculating weakness risk score: {str(e)}")
            return 0.0
    
    def calculate_semantic_risk_score(self, semantic_analysis: Dict[str, Any]) -> float:
        """
        Calculate semantic risk score from semantic analysis
        
        Args:
            semantic_analysis: Results from semantic AI analyzer
            
        Returns:
            Semantic risk score (0.0 to 1.0)
        """
        try:
            if 'semantic_risk_score' in semantic_analysis:
                return semantic_analysis['semantic_risk_score']
            
            # Calculate from semantic flags
            semantic_flags = semantic_analysis.get('ai_semantic_flags', [])
            
            if not semantic_flags:
                return 0.0
            
            # Weight by severity and type
            severity_weights = {'high': 1.0, 'medium': 0.6, 'low': 0.3}
            type_weights = {
                'unrealistic_timeline': 0.3,
                'budget_scope_mismatch': 0.3,
                'incoherent_deliverables': 0.2,
                'missing_justification': 0.1,
                'contradictions': 0.1
            }
            
            total_weighted_score = 0.0
            
            for flag in semantic_flags:
                flag_type = flag.get('type', 'unknown')
                severity = flag.get('severity', 'medium')
                
                severity_weight = severity_weights.get(severity, 0.6)
                type_weight = type_weights.get(flag_type, 0.2)
                
                total_weighted_score += severity_weight * type_weight
            
            # Normalize by number of flags
            if semantic_flags:
                normalized_score = total_weighted_score / len(semantic_flags)
            else:
                normalized_score = 0.0
            
            return min(1.0, normalized_score)
            
        except Exception as e:
            self.logger.error(f"Error calculating semantic risk score: {str(e)}")
            return 0.0
    
    def calculate_compound_risk_score(self, analysis_results: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calculate compound risk score from all analysis components
        
        Args:
            analysis_results: Combined results from all analyzers
            
        Returns:
            Dict with compound risk score and breakdown
        """
        try:
            # Extract individual risk scores
            structural_risk = self.calculate_structural_risk_score(
                analysis_results.get('structural_analysis', {})
            )
            
            clause_risk = self.calculate_clause_risk_score(
                analysis_results.get('clause_analysis', {})
            )
            
            weakness_risk = self.calculate_weakness_risk_score(
                analysis_results.get('weakness_analysis', {})
            )
            
            semantic_risk = self.calculate_semantic_risk_score(
                analysis_results.get('semantic_analysis', {})
            )
            
            # Calculate weighted compound risk score
            compound_risk = (
                structural_risk * self.risk_weights['structural'] +
                clause_risk * self.risk_weights['clause'] +
                weakness_risk * self.risk_weights['weakness'] +
                semantic_risk * self.risk_weights['semantic']
            )
            
            # Determine risk level
            risk_level = self._determine_risk_level(compound_risk)
            
            # Calculate individual component scores (positive scores)
            structural_score = 1.0 - structural_risk
            clause_score = 1.0 - clause_risk
            weakness_score = 1.0 - weakness_risk
            semantic_score = 1.0 - semantic_risk
            
            return {
                'compound_risk_score': compound_risk,
                'risk_level': risk_level,
                'compound_risk': compound_risk > self.thresholds['medium_risk'],
                'component_scores': {
                    'structural': structural_score,
                    'clause': clause_score,
                    'weakness': weakness_score,
                    'semantic': semantic_score
                },
                'component_risks': {
                    'structural': structural_risk,
                    'clause': clause_risk,
                    'weakness': weakness_risk,
                    'semantic': semantic_risk
                },
                'risk_breakdown': {
                    'structural_contribution': structural_risk * self.risk_weights['structural'],
                    'clause_contribution': clause_risk * self.risk_weights['clause'],
                    'weakness_contribution': weakness_risk * self.risk_weights['weakness'],
                    'semantic_contribution': semantic_risk * self.risk_weights['semantic']
                }
            }
            
        except Exception as e:
            self.logger.error(f"Error calculating compound risk score: {str(e)}")
            return {
                'compound_risk_score': 0.0,
                'risk_level': 'low',
                'compound_risk': False,
                'component_scores': {'structural': 0.0, 'clause': 0.0, 'weakness': 0.0, 'semantic': 0.0},
                'component_risks': {'structural': 0.0, 'clause': 0.0, 'weakness': 0.0, 'semantic': 0.0},
                'risk_breakdown': {},
                'error': str(e)
            }
    
    def _determine_risk_level(self, risk_score: float) -> str:
        """Determine risk level based on score"""
        if risk_score >= self.thresholds['critical_risk']:
            return 'critical'
        elif risk_score >= self.thresholds['high_risk']:
            return 'high'
        elif risk_score >= self.thresholds['medium_risk']:
            return 'medium'
        elif risk_score >= self.thresholds['low_risk']:
            return 'low'
        else:
            return 'minimal'
    
    def get_risk_level_description(self, risk_level: str) -> str:
        """Get human-readable description of risk level"""
        descriptions = {
            'minimal': 'Minimal risk - Proposal appears solid with minor issues',
            'low': 'Low risk - Some minor issues that should be addressed',
            'medium': 'Medium risk - Several issues requiring attention before approval',
            'high': 'High risk - Significant issues that must be resolved',
            'critical': 'Critical risk - Major problems requiring immediate attention'
        }
        
        return descriptions.get(risk_level, 'Unknown risk level')
    
    def calculate_improvement_potential(self, analysis_results: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calculate potential for improvement based on identified issues
        
        Args:
            analysis_results: Combined analysis results
            
        Returns:
            Dict with improvement potential analysis
        """
        try:
            improvement_areas = []
            total_improvement_potential = 0.0
            
            # Analyze each component for improvement potential
            components = ['structural', 'clause', 'weakness', 'semantic']
            
            for component in components:
                component_data = analysis_results.get(f'{component}_analysis', {})
                
                if component == 'structural':
                    missing_sections = component_data.get('missing_sections', [])
                    if missing_sections:
                        improvement_areas.append({
                            'component': component,
                            'area': 'missing_sections',
                            'potential': len(missing_sections) * 0.1,
                            'description': f"Add {len(missing_sections)} missing sections"
                        })
                        total_improvement_potential += len(missing_sections) * 0.1
                
                elif component == 'clause':
                    altered_clauses = component_data.get('altered_clauses', [])
                    missing_clauses = component_data.get('missing_clauses', [])
                    if altered_clauses or missing_clauses:
                        clause_count = len(altered_clauses) + len(missing_clauses)
                        improvement_areas.append({
                            'component': component,
                            'area': 'clause_issues',
                            'potential': clause_count * 0.08,
                            'description': f"Fix {clause_count} clause issues"
                        })
                        total_improvement_potential += clause_count * 0.08
                
                elif component == 'weakness':
                    weak_areas = component_data.get('weak_areas', [])
                    if weak_areas:
                        improvement_areas.append({
                            'component': component,
                            'area': 'weak_areas',
                            'potential': len(weak_areas) * 0.06,
                            'description': f"Strengthen {len(weak_areas)} weak areas"
                        })
                        total_improvement_potential += len(weak_areas) * 0.06
                
                elif component == 'semantic':
                    semantic_flags = component_data.get('ai_semantic_flags', [])
                    if semantic_flags:
                        improvement_areas.append({
                            'component': component,
                            'area': 'semantic_issues',
                            'potential': len(semantic_flags) * 0.05,
                            'description': f"Resolve {len(semantic_flags)} semantic issues"
                        })
                        total_improvement_potential += len(semantic_flags) * 0.05
            
            # Sort by improvement potential
            improvement_areas.sort(key=lambda x: x['potential'], reverse=True)
            
            return {
                'total_improvement_potential': min(1.0, total_improvement_potential),
                'improvement_areas': improvement_areas,
                'priority_fixes': improvement_areas[:3]  # Top 3 priority fixes
            }
            
        except Exception as e:
            self.logger.error(f"Error calculating improvement potential: {str(e)}")
            return {
                'total_improvement_potential': 0.0,
                'improvement_areas': [],
                'priority_fixes': [],
                'error': str(e)
            }
