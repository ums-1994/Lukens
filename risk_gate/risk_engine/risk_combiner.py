"""
Risk Combiner Module
Combines all analysis results into final compound risk assessment
"""

from typing import Dict, List, Any, Optional
import logging
from datetime import datetime

from ..utils.scoring import RiskScorer
from ..utils.template_loader import TemplateLoader


class RiskCombiner:
    """Combines analysis results from all analyzers into final risk assessment"""
    
    def __init__(self, template_loader: TemplateLoader = None):
        self.logger = logging.getLogger(__name__)
        self.template_loader = template_loader
        self.scorer = RiskScorer()
        
        # Risk decision thresholds
        self.decision_thresholds = {
            'auto_approve': 0.2,      # Below this, auto-approve
            'manual_review': 0.5,     # Below this, manual review
            'requires_changes': 0.7,  # Below this, requires changes
            'auto_block': 0.85        # Above this, auto-block
        }
    
    def combine_risk_analysis(self, analysis_results: Dict[str, Any]) -> Dict[str, Any]:
        """
        Combine all analysis results into final risk assessment
        
        Args:
            analysis_results: Results from all analyzers
            
        Returns:
            Dict with combined risk assessment and recommendations
        """
        try:
            # Calculate compound risk score
            scoring_results = self.scorer.calculate_compound_risk_score(analysis_results)
            
            # Calculate improvement potential
            improvement_results = self.scorer.calculate_improvement_potential(analysis_results)
            
            # Make final decision
            decision_result = self._make_risk_decision(scoring_results)
            
            # Generate comprehensive summary
            summary = self._generate_comprehensive_summary(analysis_results, scoring_results, decision_result)
            
            # Generate actionable recommendations
            recommendations = self._generate_actionable_recommendations(analysis_results, scoring_results, improvement_results)
            
            # Combine all results
            combined_results = {
                # Core risk assessment
                'risk_score': scoring_results['compound_risk_score'],
                'compound_risk': decision_result['compound_risk'],
                'risk_level': scoring_results['risk_level'],
                'decision': decision_result['decision'],
                'confidence': decision_result['confidence'],
                
                # Component breakdown
                'component_scores': scoring_results['component_scores'],
                'component_risks': scoring_results['component_risks'],
                'risk_breakdown': scoring_results['risk_breakdown'],
                
                # Issues identified
                'missing_sections': analysis_results.get('structural_analysis', {}).get('missing_sections', []),
                'altered_clauses': analysis_results.get('clause_analysis', {}).get('altered_clauses', []),
                'weak_areas': analysis_results.get('weakness_analysis', {}).get('weak_areas', []),
                'ai_semantic_flags': analysis_results.get('semantic_analysis', {}).get('ai_semantic_flags', []),
                
                # Recommendations and summary
                'summary': summary,
                'recommendations': recommendations,
                'priority_fixes': improvement_results.get('priority_fixes', []),
                
                # Metadata
                'analysis_timestamp': datetime.now().isoformat(),
                'analysis_version': '1.0',
                'template_count': len(self.template_loader.get_all_templates()) if self.template_loader else 0
            }
            
            self.logger.info(f"Risk combination complete: {scoring_results['risk_level']} risk level, decision: {decision_result['decision']}")
            
            return combined_results
            
        except Exception as e:
            self.logger.error(f"Error combining risk analysis: {str(e)}")
            return {
                'risk_score': 0.0,
                'compound_risk': False,
                'risk_level': 'error',
                'decision': 'error',
                'confidence': 0.0,
                'summary': f"Error in risk analysis: {str(e)}",
                'recommendations': ["Please retry analysis or contact support"],
                'error': str(e)
            }
    
    def _make_risk_decision(self, scoring_results: Dict[str, Any]) -> Dict[str, Any]:
        """Make final risk decision based on scoring results"""
        risk_score = scoring_results['compound_risk_score']
        risk_level = scoring_results['risk_level']
        
        # Determine decision
        if risk_score <= self.decision_thresholds['auto_approve']:
            decision = 'auto_approve'
            compound_risk = False
            confidence = 0.9
        elif risk_score <= self.decision_thresholds['manual_review']:
            decision = 'manual_review'
            compound_risk = False
            confidence = 0.7
        elif risk_score <= self.decision_thresholds['requires_changes']:
            decision = 'requires_changes'
            compound_risk = True
            confidence = 0.8
        elif risk_score <= self.decision_thresholds['auto_block']:
            decision = 'auto_block'
            compound_risk = True
            confidence = 0.9
        else:
            decision = 'critical_block'
            compound_risk = True
            confidence = 0.95
        
        # Adjust confidence based on risk level consistency
        component_risks = scoring_results['component_risks']
        risk_variance = max(component_risks.values()) - min(component_risks.values())
        
        if risk_variance > 0.5:  # High variance in component risks
            confidence -= 0.1  # Reduce confidence
        
        confidence = max(0.5, min(0.95, confidence))  # Keep confidence in reasonable range
        
        return {
            'decision': decision,
            'compound_risk': compound_risk,
            'confidence': confidence,
            'threshold_used': self._get_threshold_used(risk_score),
            'risk_variance': risk_variance
        }
    
    def _get_threshold_used(self, risk_score: float) -> str:
        """Get which threshold was triggered"""
        if risk_score <= self.decision_thresholds['auto_approve']:
            return 'auto_approve'
        elif risk_score <= self.decision_thresholds['manual_review']:
            return 'manual_review'
        elif risk_score <= self.decision_thresholds['requires_changes']:
            return 'requires_changes'
        elif risk_score <= self.decision_thresholds['auto_block']:
            return 'auto_block'
        else:
            return 'critical_block'
    
    def _generate_comprehensive_summary(self, analysis_results: Dict[str, Any], 
                                      scoring_results: Dict[str, Any], 
                                      decision_result: Dict[str, Any]) -> str:
        """Generate human-readable summary of risk analysis"""
        
        risk_score = scoring_results['compound_risk_score']
        risk_level = scoring_results['risk_level']
        decision = decision_result['decision']
        
        # Start with risk level and decision
        summary_parts = []
        
        if decision == 'auto_approve':
            summary_parts.append(f"✅ Proposal Approved - Low Risk ({risk_score:.2f})")
        elif decision == 'manual_review':
            summary_parts.append(f"⚠️ Proposal Requires Manual Review - Medium Risk ({risk_score:.2f})")
        elif decision == 'requires_changes':
            summary_parts.append(f"🔄 Proposal Requires Changes - High Risk ({risk_score:.2f})")
        elif decision == 'auto_block':
            summary_parts.append(f"🚫 Proposal Blocked - Critical Risk ({risk_score:.2f})")
        else:
            summary_parts.append(f"❌ Proposal Critical Block - Severe Risk ({risk_score:.2f})")
        
        # Add key issues
        issues_found = []
        
        # Structural issues
        missing_sections = analysis_results.get('structural_analysis', {}).get('missing_sections', [])
        if missing_sections:
            issues_found.append(f"Missing {len(missing_sections)} sections: {', '.join(missing_sections[:3])}")
        
        # Clause issues
        altered_clauses = analysis_results.get('clause_analysis', {}).get('altered_clauses', [])
        if altered_clauses:
            issues_found.append(f"{len(altered_clauses)} altered clauses detected")
        
        # Weak areas
        weak_areas = analysis_results.get('weakness_analysis', {}).get('weak_areas', [])
        if weak_areas:
            weak_types = [area['type'].replace('weak_', '').replace('_', ' ') for area in weak_areas]
            issues_found.append(f"Weak areas: {', '.join(weak_types[:3])}")
        
        # Semantic issues
        semantic_flags = analysis_results.get('semantic_analysis', {}).get('ai_semantic_flags', [])
        if semantic_flags:
            issues_found.append(f"{len(semantic_flags)} semantic issues detected")
        
        if issues_found:
            summary_parts.append("Issues:")
            for issue in issues_found[:5]:  # Limit to top 5 issues
                summary_parts.append(f"• {issue}")
        
        # Add component scores if significant
        component_risks = scoring_results['component_risks']
        high_risk_components = [comp for comp, risk in component_risks.items() if risk > 0.6]
        
        if high_risk_components:
            summary_parts.append("High-risk components:")
            for comp in high_risk_components:
                risk_percent = component_risks[comp] * 100
                summary_parts.append(f"• {comp.title()}: {risk_percent:.0f}% risk")
        
        # Add confidence level
        confidence = decision_result['confidence']
        summary_parts.append(f"Analysis confidence: {confidence:.0%}")
        
        return "\n".join(summary_parts)
    
    def _generate_actionable_recommendations(self, analysis_results: Dict[str, Any],
                                           scoring_results: Dict[str, Any],
                                           improvement_results: Dict[str, Any]) -> List[str]:
        """Generate actionable recommendations based on all analysis results"""
        
        recommendations = []
        
        # Priority fixes from improvement analysis
        priority_fixes = improvement_results.get('priority_fixes', [])
        for fix in priority_fixes:
            recommendations.append(f"Priority: {fix['description']}")
        
        # Component-specific recommendations
        structural_analysis = analysis_results.get('structural_analysis', {})
        clause_analysis = analysis_results.get('clause_analysis', {})
        weakness_analysis = analysis_results.get('weakness_analysis', {})
        semantic_analysis = analysis_results.get('semantic_analysis', {})
        
        # Structural recommendations
        missing_sections = structural_analysis.get('missing_sections', [])
        if missing_sections:
            section_names = {
                'executive_summary': 'Executive Summary',
                'scope': 'Scope of Work',
                'deliverables': 'Deliverables',
                'timeline': 'Timeline',
                'budget': 'Budget',
                'team': 'Team Bios',
                'assumptions': 'Assumptions'
            }
            
            for section in missing_sections[:3]:  # Limit to top 3
                readable_name = section_names.get(section, section.replace('_', ' ').title())
                recommendations.append(f"Add {readable_name} section")
        
        # Clause recommendations
        altered_clauses = clause_analysis.get('altered_clauses', [])
        for clause in altered_clauses[:3]:  # Limit to top 3
            clause_type = clause.get('clause_type', 'unknown').replace('_', ' ').title()
            recommendations.append(f"Review and fix {clause_type} clause")
        
        missing_clauses = clause_analysis.get('missing_clauses', [])
        for clause in missing_clauses[:2]:  # Limit to top 2
            clause_type = clause.get('clause_type', 'unknown').replace('_', ' ').title()
            recommendations.append(f"Add {clause_type} clause")
        
        # Weakness recommendations
        weak_areas = weakness_analysis.get('weak_areas', [])
        for area in weak_areas[:3]:  # Limit to top 3
            area_type = area.get('type', 'unknown').replace('weak_', '').replace('_', ' ').title()
            severity = area.get('severity', 'medium')
            if severity == 'high':
                recommendations.append(f"Urgent: Strengthen {area_type}")
            else:
                recommendations.append(f"Improve {area_type}")
        
        # Semantic recommendations
        semantic_flags = semantic_analysis.get('ai_semantic_flags', [])
        semantic_recs = semantic_analysis.get('recommendations', [])
        recommendations.extend(semantic_recs[:3])  # Limit to top 3
        
        # Risk-based recommendations
        risk_level = scoring_results['risk_level']
        if risk_level in ['high', 'critical']:
            recommendations.append("Comprehensive proposal revision recommended")
        elif risk_level == 'medium':
            recommendations.append("Targeted improvements needed before approval")
        
        # Remove duplicates while preserving order
        seen = set()
        unique_recommendations = []
        for rec in recommendations:
            if rec not in seen:
                seen.add(rec)
                unique_recommendations.append(rec)
        
        return unique_recommendations[:10]  # Limit to top 10 recommendations
    
    def get_risk_assessment_summary(self, combined_results: Dict[str, Any]) -> str:
        """
        Get a concise risk assessment summary for quick review
        
        Args:
            combined_results: Combined risk analysis results
            
        Returns:
            Concise summary string
        """
        try:
            risk_score = combined_results.get('risk_score', 0.0)
            risk_level = combined_results.get('risk_level', 'unknown')
            decision = combined_results.get('decision', 'unknown')
            
            # Count issues
            missing_count = len(combined_results.get('missing_sections', []))
            altered_count = len(combined_results.get('altered_clauses', []))
            weak_count = len(combined_results.get('weak_areas', []))
            semantic_count = len(combined_results.get('ai_semantic_flags', []))
            
            total_issues = missing_count + altered_count + weak_count + semantic_count
            
            # Create summary
            summary = f"Risk Level: {risk_level.title()} ({risk_score:.2f})\n"
            summary += f"Decision: {decision.replace('_', ' ').title()}\n"
            summary += f"Issues Found: {total_issues} total\n"
            
            if total_issues > 0:
                summary += f"  • Missing sections: {missing_count}\n"
                summary += f"  • Altered clauses: {altered_count}\n"
                summary += f"  • Weak areas: {weak_count}\n"
                summary += f"  • Semantic issues: {semantic_count}\n"
            
            return summary.strip()
            
        except Exception as e:
            self.logger.error(f"Error generating assessment summary: {str(e)}")
            return f"Error generating summary: {str(e)}"
