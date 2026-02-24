"""
Compound Risk Detection Module
Groups issues by theme and calculates combined risk scores
"""

from typing import List, Dict, Any, Optional
import logging
from collections import defaultdict
from dataclasses import dataclass

@dataclass
class Issue:
    """Represents a single risk issue"""
    type: str  # 'structural', 'clause', 'weakness', 'semantic'
    severity: str  # 'low', 'medium', 'high', 'critical'
    theme: str  # 'content_completeness', 'legal_deviation', 'financial_risk', 'quality_issues'
    description: str
    location: Optional[str] = None
    confidence: float = 0.0
    weight: float = 1.0


class CompoundRiskDetector:
    """Detects compound risks by grouping and scoring related issues"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
        # Theme weights for compound risk calculation
        self.theme_weights = {
            'content_completeness': 0.8,  # Missing sections, incomplete content
            'legal_deviation': 1.0,       # Legal clauses, compliance issues
            'financial_risk': 0.9,        # Budget, timeline, payment issues
            'quality_issues': 0.7,        # Weak content, poor quality
            'semantic_risk': 0.6,          # Semantic inconsistencies
            'structural_issues': 0.5,     # Structure problems
        }
        
        # Issue type severity scores
        self.severity_scores = {
            'low': 1,
            'medium': 2,
            'high': 3,
            'critical': 4
        }
        
        # Compound risk threshold
        self.compound_risk_threshold = 7.0
        
        # Theme descriptions for summaries
        self.theme_descriptions = {
            'content_completeness': "Missing or incomplete proposal sections",
            'legal_deviation': "Legal clauses that deviate from standards",
            'financial_risk': "Budget, timeline, or payment-related issues",
            'quality_issues': "Weak or low-quality content areas",
            'semantic_risk': "Semantic inconsistencies or contradictions",
            'structural_issues': "Document structure problems"
        }
    
    def calculate_compound_risk(self, issues: List[Issue]) -> Dict[str, Any]:
        """
        Calculate compound risk score and generate recommendations
        
        Args:
            issues: List of individual risk issues
            
        Returns:
            Compound risk assessment with recommendations
        """
        try:
            if not issues:
                return self._create_low_risk_result()
            
            # Group issues by theme
            themed_issues = self._group_issues_by_theme(issues)
            
            # Calculate theme scores
            theme_scores = self._calculate_theme_scores(themed_issues)
            
            # Calculate overall compound risk score
            compound_score = self._calculate_overall_score(theme_scores)
            
            # Determine if compound risk is high
            is_high_risk = compound_score >= self.compound_risk_threshold
            
            # Generate summary and recommendations
            summary = self._generate_risk_summary(themed_issues, theme_scores, compound_score)
            recommended_action = self._generate_recommended_action(is_high_risk, compound_score, themed_issues)
            ai_global_suggestion = self._generate_ai_suggestion(is_high_risk, themed_issues)
            
            return {
                'is_high': is_high_risk,
                'score': round(compound_score, 2),
                'summary': summary,
                'recommended_action': recommended_action,
                'ai_global_suggestion': ai_global_suggestion,
                'theme_breakdown': {
                    theme: {
                        'score': round(theme_scores.get(theme, 0.0), 2),
                        'count': len(issues),
                        'severity_breakdown': self._get_severity_breakdown(issues)
                    }
                    for theme, issues in themed_issues.items()
                }
            }
            
        except Exception as e:
            self.logger.error(f"Error calculating compound risk: {str(e)}")
            return self._create_error_result(str(e))
    
    def _group_issues_by_theme(self, issues: List[Issue]) -> Dict[str, List[Issue]]:
        """Group issues by their theme"""
        themed = defaultdict(list)
        
        for issue in issues:
            theme = issue.theme or 'other'
            themed[theme].append(issue)
        
        return dict(themed)
    
    def _calculate_theme_scores(self, themed_issues: Dict[str, List[Issue]]) -> Dict[str, float]:
        """Calculate risk score for each theme"""
        theme_scores = {}
        
        for theme, issues in themed_issues.items():
            theme_weight = self.theme_weights.get(theme, 0.5)
            
            # Calculate weighted severity score for this theme
            total_score = 0
            for issue in issues:
                severity_score = self.severity_scores.get(issue.severity, 1)
                weighted_score = severity_score * issue.weight * theme_weight
                total_score += weighted_score
            
            theme_scores[theme] = total_score
        
        return theme_scores
    
    def _calculate_overall_score(self, theme_scores: Dict[str, float]) -> float:
        """Calculate overall compound risk score"""
        if not theme_scores:
            return 0.0
        
        # Use the highest theme score as the primary indicator
        # but add weight from other themes
        max_score = max(theme_scores.values())
        other_scores_sum = sum(score for score in theme_scores.values() if score != max_score)
        
        # 70% weight to highest score, 30% to others
        overall_score = (max_score * 0.7) + (other_scores_sum * 0.3)
        
        return overall_score
    
    def _generate_risk_summary(self, themed_issues: Dict[str, List[Issue]], 
                            theme_scores: Dict[str, float], compound_score: float) -> str:
        """Generate a summary of the compound risk"""
        if not themed_issues:
            return "No significant risks detected."
        
        # Identify the highest risk theme
        highest_risk_theme = max(theme_scores.items(), key=lambda x: x[1])
        theme_name, theme_score = highest_risk_theme
        
        # Count total issues by severity
        severity_counts = defaultdict(int)
        total_issues = 0
        
        for issues in themed_issues.values():
            for issue in issues:
                severity_counts[issue.severity] += 1
                total_issues += 1
        
        # Build summary
        summary_parts = []
        
        # Main risk area
        theme_desc = self.theme_descriptions.get(theme_name, f"Issues in {theme_name}")
        summary_parts.append(f"Primary risk area: {theme_desc}")
        
        # Issue count and severity
        summary_parts.append(f"Total issues detected: {total_issues}")
        
        if severity_counts:
            severity_list = []
            for severity in ['critical', 'high', 'medium', 'low']:
                count = severity_counts.get(severity, 0)
                if count > 0:
                    severity_list.append(f"{count} {severity}")
            
            if severity_list:
                summary_parts.append(f"Severity breakdown: {', '.join(severity_list)}")
        
        # Compound score
        summary_parts.append(f"Compound risk score: {compound_score:.1f}/10")
        
        return ". ".join(summary_parts)
    
    def _generate_recommended_action(self, is_high_risk: bool, compound_score: float, 
                                   themed_issues: Dict[str, List[Issue]]) -> str:
        """Generate recommended action based on risk level"""
        if is_high_risk:
            # High risk - block and fix
            return "BLOCK proposal release. Address critical issues before proceeding. Use AI Writer to generate missing content and fix identified problems."
        
        elif compound_score >= 5.0:
            # Medium risk - manual review
            return "REVIEW required. Manual review recommended before release. Consider using AI Writer to improve weak areas."
        
        else:
            # Low risk - proceed with monitoring
            return "PROCEED with proposal release. Monitor for any additional issues during review."
    
    def _generate_ai_suggestion(self, is_high_risk: bool, themed_issues: Dict[str, List[Issue]]) -> str:
        """Generate AI-powered global suggestion"""
        if not themed_issues:
            return "No AI assistance needed - proposal appears to be in good condition."
        
        # Identify most common issue types
        issue_types = defaultdict(int)
        for issues in themed_issues.values():
            for issue in issues:
                issue_types[issue.type] += 1
        
        # Generate targeted suggestion
        suggestions = []
        
        if 'structural' in issue_types:
            suggestions.append("Use AI Writer to generate missing sections and improve document structure")
        
        if 'clause' in issue_types:
            suggestions.append("Use AI Writer to correct legal clauses and ensure compliance")
        
        if 'weakness' in issue_types:
            suggestions.append("Use AI Writer to strengthen weak content areas and improve quality")
        
        if 'semantic' in issue_types:
            suggestions.append("Review semantic consistency and use AI Writer to resolve contradictions")
        
        if is_high_risk:
            base_suggestion = "CRITICAL: Immediate action required. "
        else:
            base_suggestion = "RECOMMENDED: Improve proposal quality. "
        
        if suggestions:
            return base_suggestion + "; ".join(suggestions[:3])  # Limit to top 3 suggestions
        else:
            return base_suggestion + "Review all identified issues and use AI Writer for content improvements."
    
    def _get_severity_breakdown(self, issues: List[Issue]) -> Dict[str, int]:
        """Get breakdown of issues by severity"""
        breakdown = defaultdict(int)
        for issue in issues:
            breakdown[issue.severity] += 1
        return dict(breakdown)
    
    def _create_low_risk_result(self) -> Dict[str, Any]:
        """Create result for low/no risk scenarios"""
        return {
            'is_high': False,
            'score': 0.0,
            'summary': 'No significant risks detected. Proposal appears to be in good condition.',
            'recommended_action': 'PROCEED with proposal release.',
            'ai_global_suggestion': 'No AI assistance needed - proposal is ready for review.',
            'theme_breakdown': {}
        }
    
    def _create_error_result(self, error_message: str) -> Dict[str, Any]:
        """Create result for error scenarios"""
        return {
            'is_high': True,  # Conservative approach - treat errors as high risk
            'score': 10.0,
            'summary': f'Error during risk assessment: {error_message}',
            'recommended_action': 'BLOCK proposal release. Manual review required due to assessment error.',
            'ai_global_suggestion': 'Risk assessment failed. Please review proposal manually and retry assessment.',
            'theme_breakdown': {}
        }
