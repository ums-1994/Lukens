"""
Weakness Analyzer Module
Detects weak or incomplete areas in proposals
"""

import re
from typing import Dict, List, Any, Optional
import logging


class WeaknessAnalyzer:
    """Analyzes proposals for weak areas and incomplete information"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
        # Weakness patterns and their indicators
        self.weakness_patterns = {
            'weak_bios': {
                'indicators': [
                    r'(?i)(team|our\s+team|about\s+us)(.{0,200})?(experienced|qualified|professional)',
                    r'(?i)(\d+\+?\s*years?\s*(?:of\s*)?experience)',
                    r'(?i)(expert|specialist|professional)(.{0,100})?(without|no|missing)',
                    r'(?i)(team|staff)(.{0,100})?(will\s+be|to\s+be|tbd|to\s+be\s+determined)'
                ],
                'negative_indicators': [
                    r'(?i)(no\s+experience|limited\s+experience|new\s+team)',
                    r'(?i)(junior|entry\s+level|inexperienced)',
                    r'(?i)(to\s+be\s+hired|staffing\s+to\s+be|team\s+to\s+be)'
                ],
                'weight': 0.25,
                'description': 'Weak Team Bios'
            },
            'weak_timeline': {
                'indicators': [
                    r'(?i)(timeline|schedule)(.{0,100})?(approximate|estimated|rough|around)',
                    r'(?i)(\d+\s*weeks?|\d+\s*months?)(.{0,50})?(approximately|about|roughly)',
                    r'(?i)(delivery|completion)(.{0,50})?(asap|soon|promptly)',
                    r'(?i)(milestone|phase)(.{0,50})?(tbd|to\s+be|determined)'
                ],
                'negative_indicators': [
                    r'(?i)(unrealistic|impossible|cannot|unable)',
                    r'(?i)(delay|postpone|extend)',
                    r'(?i)(no\s+timeline|missing\s+schedule|tbd)'
                ],
                'weight': 0.20,
                'description': 'Weak Timeline'
            },
            'weak_budget': {
                'indicators': [
                    r'(?i)(budget|cost|price)(.{0,100})?(estimate|approximate|ballpark)',
                    r'(?i)(\$|cost|price)(.{0,50})?(tbd|to\s+be|determined)',
                    r'(?i)(budget|pricing)(.{0,100})?(flexible|negotiable|variable)',
                    r'(?i)(cost|budget)(.{0,100})?(very\s+reasonable|competitive|affordable)'
                ],
                'negative_indicators': [
                    r'(?i)(no\s+budget|missing\s+cost|price\s+tbd)',
                    r'(?i)(budget|cost)(.{0,50})?(insufficient|inadequate|insufficient)',
                    r'(?i)(over\s+budget|exceeds|more\s+expensive)'
                ],
                'weight': 0.25,
                'description': 'Weak Budget Details'
            },
            'weak_scope': {
                'indicators': [
                    r'(?i)(scope|work)(.{0,100})?(general|broad|basic|simple)',
                    r'(?i)(include|cover)(.{0,100})?(etc|and\s+more|additional)',
                    r'(?i)(requirements|needs)(.{0,100})?(will\s+be|to\s+be)',
                    r'(?i)(project|work)(.{0,100})?(similar|like|comparable)'
                ],
                'negative_indicators': [
                    r'(?i)(unclear|uncertain|undefined|vague)',
                    r'(?i)(scope\s+creep|changing\s+requirements)',
                    r'(?i)(out\s+of\s+scope|not\s+included)'
                ],
                'weight': 0.15,
                'description': 'Weak Scope Definition'
            },
            'weak_deliverables': {
                'indicators': [
                    r'(?i)(deliverables|outputs)(.{0,100})?(various|multiple|several)',
                    r'(?i)(provide|deliver)(.{0,100})?(high\s+quality|professional|excellent)',
                    r'(?i)(results|outcomes)(.{0,100})?(expected|anticipated|projected)',
                    r'(?i)(deliverable|output)(.{0,50})?(tbd|to\s+be)'
                ],
                'negative_indicators': [
                    r'(?i)(no\s+deliverables|missing\s+outputs)',
                    r'(?i)(unclear|vague|undefined)(.{0,50})?(deliverables|outputs)',
                    r'(?i)(deliverables)(.{0,50})?(insufficient|inadequate)'
                ],
                'weight': 0.15,
                'description': 'Weak Deliverables'
            }
        }
        
        # Quality indicators for each area
        self.quality_indicators = {
            'strong_bios': [
                r'(?i)(\d+\+?\s*years?\s*(?:of\s*)?experience\s+in)',
                r'(?i)(certified|degree|bachelor|master|phd)',
                r'(?i)(project|client|company)(.{0,100})?(successfully|completed|delivered)',
                r'(?i)(expertise|specialization|skill)(.{0,100})?(include|includes|such\s+as)'
            ],
            'strong_timeline': [
                r'(?i)(week|day|date)(.{0,30})?\d{1,2}(.{0,30})?(month|year)\d{4}',
                r'(?i)(milestone|phase|delivery)(.{0,50})?\d{1,2}(?:st|nd|rd|th)?',
                r'(?i)(duration|period)(.{0,50})?\d+\s+(weeks|months|days)',
                r'(?i)(complete|finish|deliver)(.{0,50})?\d{1,2}/\d{1,2}/\d{4}'
            ],
            'strong_budget': [
                r'(?i)\$\d{1,3}(?:,\d{3})*(?:\.\d{2})?',
                r'(?i)(total|overall|complete)(.{0,30})\$\d',
                r'(?i)(breakdown|itemized|detailed)(.{0,30})?(budget|cost|pricing)',
                r'(?i)(hourly|daily|monthly)(.{0,30})\$\d+'
            ],
            'strong_scope': [
                r'(?i)(in\s+scope|included|covered)(.{0,100})(specific|particular|detailed)',
                r'(?i)(out\s+of\s+scope|excluded)(.{0,100})(specific|particular|detailed)',
                r'(?i)(requirements|specifications)(.{0,100})(detailed|specific|clear)',
                r'(?i)(objectives|goals)(.{0,100})(measurable|specific|achievable)'
            ],
            'strong_deliverables': [
                r'(?i)(deliverable|output)(.{0,50})\d+',
                r'(?i)(report|document|software|system)(.{0,50})?(version|v\d)',
                r'(?i)(complete|finish|deliver)(.{0,50})?(by|on|before)\s+\d',
                r'(?i)(measurable|quantifiable|specific)(.{0,50})?(deliverables|outputs)'
            ]
        }
    
    def analyze_weaknesses(self, proposal_text: str) -> Dict[str, Any]:
        """
        Analyze proposal for weak areas
        
        Args:
            proposal_text: The proposal text to analyze
            
        Returns:
            Dict with weakness analysis results
        """
        try:
            results = {
                'weak_areas': [],
                'weakness_scores': {},
                'overall_weakness_score': 0.0,
                'recommendations': []
            }
            
            total_weight = 0.0
            weighted_score = 0.0
            
            # Analyze each weakness category
            for weakness_type, config in self.weakness_patterns.items():
                weakness_result = self._analyze_weakness_type(
                    weakness_type, config, proposal_text
                )
                
                if weakness_result['is_weak']:
                    results['weak_areas'].append({
                        'type': weakness_type,
                        'description': config['description'],
                        'severity': weakness_result['severity'],
                        'score': weakness_result['score'],
                        'indicators_found': weakness_result['indicators_found'],
                        'recommendations': weakness_result['recommendations']
                    })
                
                results['weakness_scores'][weakness_type] = weakness_result['score']
                
                # Calculate weighted contribution
                weighted_score += weakness_result['score'] * config['weight']
                total_weight += config['weight']
            
            # Calculate overall weakness score
            if total_weight > 0:
                results['overall_weakness_score'] = weighted_score / total_weight
            
            # Generate overall recommendations
            results['recommendations'] = self._generate_overall_recommendations(results)
            
            self.logger.info(f"Weakness analysis complete: {len(results['weak_areas'])} weak areas found")
            
            return results
            
        except Exception as e:
            self.logger.error(f"Error in weakness analysis: {str(e)}")
            return {
                'weak_areas': [],
                'weakness_scores': {},
                'overall_weakness_score': 0.0,
                'recommendations': [],
                'error': str(e)
            }
    
    def _analyze_weakness_type(self, weakness_type: str, config: Dict[str, Any], text: str) -> Dict[str, Any]:
        """Analyze a specific weakness type"""
        result = {
            'is_weak': False,
            'severity': 'low',
            'score': 0.0,
            'indicators_found': [],
            'recommendations': []
        }
        
        # Check for weakness indicators
        weakness_count = 0
        total_indicators = len(config['indicators'])
        
        for pattern in config['indicators']:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                weakness_count += len(matches)
                result['indicators_found'].extend([match[0] if isinstance(match, tuple) else match for match in matches[:3]])
        
        # Check for negative indicators (more severe)
        negative_count = 0
        for pattern in config['negative_indicators']:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                negative_count += len(matches)
                result['indicators_found'].extend([match[0] if isinstance(match, tuple) else match for match in matches[:2]])
        
        # Check for quality indicators (reduce weakness score)
        quality_count = 0
        if weakness_type.replace('weak_', 'strong_') in self.quality_indicators:
            quality_patterns = self.quality_indicators[weakness_type.replace('weak_', 'strong_')]
            for pattern in quality_patterns:
                matches = re.findall(pattern, text, re.IGNORECASE)
                if matches:
                    quality_count += len(matches)
        
        # Calculate weakness score
        base_weakness_score = (weakness_count + (negative_count * 2)) / max(1, total_indicators)
        quality_reduction = min(0.3, quality_count * 0.1)  # Quality indicators can reduce weakness by up to 30%
        
        final_score = max(0.0, base_weakness_score - quality_reduction)
        
        result['score'] = final_score
        
        # Determine if weak and severity
        if final_score > 0.6:
            result['is_weak'] = True
            result['severity'] = 'high' if final_score > 0.8 or negative_count > 0 else 'medium'
        elif final_score > 0.3:
            result['is_weak'] = True
            result['severity'] = 'medium'
        elif final_score > 0.1:
            result['is_weak'] = True
            result['severity'] = 'low'
        
        # Generate specific recommendations
        result['recommendations'] = self._generate_weakness_recommendations(
            weakness_type, result['severity'], result['indicators_found']
        )
        
        return result
    
    def _generate_weakness_recommendations(self, weakness_type: str, severity: str, indicators: List[str]) -> List[str]:
        """Generate recommendations for specific weakness type"""
        recommendations = []
        
        if weakness_type == 'weak_bios':
            if severity == 'high':
                recommendations.append("Add detailed team bios with specific experience and qualifications")
                recommendations.append("Include years of experience and relevant certifications for team members")
            else:
                recommendations.append("Enhance team bios with more specific experience details")
        
        elif weakness_type == 'weak_timeline':
            if severity == 'high':
                recommendations.append("Provide specific dates and milestones with clear deadlines")
                recommendations.append("Break down project into phases with realistic timeframes")
            else:
                recommendations.append("Add more specific timeline details and delivery dates")
        
        elif weakness_type == 'weak_budget':
            if severity == 'high':
                recommendations.append("Provide detailed budget breakdown with specific cost figures")
                recommendations.append("Include pricing methodology and cost justification")
            else:
                recommendations.append("Add more specific budget details and cost breakdown")
        
        elif weakness_type == 'weak_scope':
            if severity == 'high':
                recommendations.append("Clearly define project scope with specific deliverables")
                recommendations.append("Include both in-scope and out-of-scope items")
            else:
                recommendations.append("Add more specific details to project scope definition")
        
        elif weakness_type == 'weak_deliverables':
            if severity == 'high':
                recommendations.append("List specific, measurable deliverables with clear acceptance criteria")
                recommendations.append("Include deliverable formats and delivery schedules")
            else:
                recommendations.append("Add more specific details about project deliverables")
        
        return recommendations
    
    def _generate_overall_recommendations(self, results: Dict[str, Any]) -> List[str]:
        """Generate overall recommendations based on weakness analysis"""
        recommendations = []
        
        # High-level recommendations based on overall score
        if results['overall_weakness_score'] > 0.7:
            recommendations.append("Multiple weak areas detected - comprehensive proposal revision recommended")
        elif results['overall_weakness_score'] > 0.5:
            recommendations.append("Several weak areas identified - targeted improvements needed")
        elif results['overall_weakness_score'] > 0.3:
            recommendations.append("Some weak areas found - minor improvements recommended")
        
        # Specific recommendations based on weak areas
        weak_types = [area['type'] for area in results['weak_areas']]
        
        if 'weak_bios' in weak_types:
            recommendations.append("Strengthen team credentials and experience documentation")
        
        if 'weak_timeline' in weak_types:
            recommendations.append("Develop more detailed and realistic project timeline")
        
        if 'weak_budget' in weak_types:
            recommendations.append("Provide comprehensive budget breakdown and justification")
        
        if 'weak_scope' in weak_types:
            recommendations.append("Clarify project scope and specific requirements")
        
        if 'weak_deliverables' in weak_types:
            recommendations.append("Define specific, measurable deliverables with clear criteria")
        
        return recommendations
    
    def check_area_strength(self, proposal_text: str, area: str) -> Dict[str, Any]:
        """
        Check strength of a specific area
        
        Args:
            proposal_text: The proposal text
            area: Area to check (bios, timeline, budget, scope, deliverables)
            
        Returns:
            Dict with strength analysis
        """
        weakness_type = f'weak_{area}'
        
        if weakness_type not in self.weakness_patterns:
            return {'error': f'Unknown area: {area}'}
        
        config = self.weakness_patterns[weakness_type]
        return self._analyze_weakness_type(weakness_type, config, proposal_text)
