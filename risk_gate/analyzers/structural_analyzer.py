"""
Structural Analyzer Module
Detects missing sections and structural issues in proposals
"""

import re
from typing import Dict, List, Any, Optional
import logging


class StructuralAnalyzer:
    """Analyzes proposal structure for missing sections and components"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
        # Required sections for a complete proposal
        self.required_sections = {
            'executive_summary': {
                'patterns': [r'(?i)(executive\s+summary|overview|introduction|project\s+overview)'],
                'weight': 0.15,
                'description': 'Executive Summary/Overview'
            },
            'scope': {
                'patterns': [r'(?i)(scope\s+of\s+work|project\s+scope|statement\s+of\s+work|work\s+scope)'],
                'weight': 0.20,
                'description': 'Scope of Work'
            },
            'deliverables': {
                'patterns': [r'(?i)(deliverables|outputs|results|project\s+deliverables)'],
                'weight': 0.15,
                'description': 'Deliverables'
            },
            'timeline': {
                'patterns': [r'(?i)(timeline|schedule|project\s+schedule|milestones|delivery\s+schedule)'],
                'weight': 0.15,
                'description': 'Timeline/Schedule'
            },
            'budget': {
                'patterns': [r'(?i)(budget|cost|pricing|fees|investment|financial|payment)'],
                'weight': 0.20,
                'description': 'Budget/Pricing'
            },
            'team': {
                'patterns': [r'(?i)(team|personnel|staff|bios|about\s+us|our\s+team|key\s+personnel)'],
                'weight': 0.10,
                'description': 'Team/Bios'
            },
            'assumptions': {
                'patterns': [r'(?i)(assumptions|preconditions|requirements|prerequisites)'],
                'weight': 0.05,
                'description': 'Assumptions'
            }
        }
        
        # Optional but recommended sections
        self.optional_sections = {
            'ip_clause': {
                'patterns': [r'(?i)(intellectual\s+property|ip\s+rights|ownership|proprietary)'],
                'weight': 0.05,
                'description': 'Intellectual Property Clause'
            },
            'payment_terms': {
                'patterns': [r'(?i)(payment\s+terms|billing|invoicing|payment\s+schedule)'],
                'weight': 0.05,
                'description': 'Payment Terms'
            },
            'termination': {
                'patterns': [r'(?i)(termination|cancellation|exit\s+clause|contract\s+termination)'],
                'weight': 0.05,
                'description': 'Termination Clause'
            }
        }
    
    def analyze_structure(self, proposal_text: str) -> Dict[str, Any]:
        """
        Analyze proposal structure for missing sections
        
        Args:
            proposal_text: The proposal text to analyze
            
        Returns:
            Dict with structural analysis results
        """
        try:
            results = {
                'missing_sections': [],
                'present_sections': [],
                'structural_score': 0.0,
                'section_details': {},
                'recommendations': []
            }
            
            # Check required sections
            required_weight_total = 0
            required_weight_found = 0
            
            for section_name, section_config in self.required_sections.items():
                required_weight_total += section_config['weight']
                
                if self._section_exists(proposal_text, section_config['patterns']):
                    results['present_sections'].append(section_name)
                    required_weight_found += section_config['weight']
                    results['section_details'][section_name] = {
                        'present': True,
                        'weight': section_config['weight'],
                        'description': section_config['description']
                    }
                else:
                    results['missing_sections'].append(section_name)
                    results['section_details'][section_name] = {
                        'present': False,
                        'weight': section_config['weight'],
                        'description': section_config['description']
                    }
            
            # Check optional sections
            optional_bonus = 0
            for section_name, section_config in self.optional_sections.items():
                if self._section_exists(proposal_text, section_config['patterns']):
                    results['present_sections'].append(section_name)
                    optional_bonus += section_config['weight'] * 0.5  # Half weight for optional
                    results['section_details'][section_name] = {
                        'present': True,
                        'weight': section_config['weight'],
                        'description': section_config['description'],
                        'optional': True
                    }
                else:
                    results['section_details'][section_name] = {
                        'present': False,
                        'weight': section_config['weight'],
                        'description': section_config['description'],
                        'optional': True
                    }
            
            # Calculate structural score
            if required_weight_total > 0:
                base_score = required_weight_found / required_weight_total
                results['structural_score'] = min(1.0, base_score + optional_bonus)
            
            # Generate recommendations
            results['recommendations'] = self._generate_recommendations(results['missing_sections'])
            
            self.logger.info(f"Structural analysis complete: {len(results['missing_sections'])} missing sections")
            
            return results
            
        except Exception as e:
            self.logger.error(f"Error in structural analysis: {str(e)}")
            return {
                'missing_sections': [],
                'present_sections': [],
                'structural_score': 0.0,
                'section_details': {},
                'recommendations': [],
                'error': str(e)
            }
    
    def _section_exists(self, text: str, patterns: List[str]) -> bool:
        """Check if a section exists in the text using patterns"""
        for pattern in patterns:
            if re.search(pattern, text):
                return True
        return False
    
    def _generate_recommendations(self, missing_sections: List[str]) -> List[str]:
        """Generate recommendations for missing sections"""
        recommendations = []
        
        section_recommendations = {
            'executive_summary': 'Add an executive summary to provide a high-level overview of the proposal',
            'scope': 'Include a detailed scope of work section defining project boundaries and deliverables',
            'deliverables': 'Specify clear deliverables with measurable outcomes and timelines',
            'timeline': 'Provide a project timeline with key milestones and delivery dates',
            'budget': 'Include a detailed budget breakdown with cost justification',
            'team': 'Add team bios to showcase relevant experience and qualifications',
            'assumptions': 'List key assumptions that the proposal is based on',
            'ip_clause': 'Include intellectual property rights and ownership clauses',
            'payment_terms': 'Specify payment terms, schedule, and invoicing procedures',
            'termination': 'Add termination clauses and exit procedures'
        }
        
        for section in missing_sections:
            if section in section_recommendations:
                recommendations.append(section_recommendations[section])
        
        return recommendations
    
    def check_section_completeness(self, proposal_text: str, section_name: str) -> Dict[str, Any]:
        """
        Check if a specific section is complete and detailed enough
        
        Args:
            proposal_text: The proposal text
            section_name: Name of the section to check
            
        Returns:
            Dict with completeness analysis
        """
        try:
            if section_name not in self.required_sections and section_name not in self.optional_sections:
                return {'error': f'Unknown section: {section_name}'}
            
            section_config = self.required_sections.get(section_name, self.optional_sections.get(section_name))
            
            # Extract section content
            section_content = self._extract_section_content(proposal_text, section_config['patterns'])
            
            if not section_content:
                return {
                    'present': False,
                    'completeness_score': 0.0,
                    'word_count': 0,
                    'recommendations': [f"Add {section_config['description']} section"]
                }
            
            # Analyze completeness
            word_count = len(section_content.split())
            completeness_score = self._calculate_completeness_score(section_name, section_content, word_count)
            
            recommendations = self._generate_section_recommendations(section_name, section_content, completeness_score)
            
            return {
                'present': True,
                'completeness_score': completeness_score,
                'word_count': word_count,
                'content_length': len(section_content),
                'recommendations': recommendations
            }
            
        except Exception as e:
            self.logger.error(f"Error checking section completeness: {str(e)}")
            return {'error': str(e)}
    
    def _extract_section_content(self, text: str, patterns: List[str]) -> str:
        """Extract content for a section based on patterns"""
        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                start_pos = match.start()
                # Find next section header
                remaining_text = text[start_pos:]
                next_section_match = re.search(r'(?i)(executive\s+summary|scope\s+of\s+work|deliverables|timeline|budget|team|assumptions|intellectual\s+property|payment\s+terms|termination)', remaining_text[100:])
                
                if next_section_match:
                    return remaining_text[:100 + next_section_match.start()]
                else:
                    return remaining_text[:1000]  # Limit to reasonable length
        return ""
    
    def _calculate_completeness_score(self, section_name: str, content: str, word_count: int) -> float:
        """Calculate completeness score for a section"""
        # Base score from word count
        min_words = {
            'executive_summary': 50,
            'scope': 100,
            'deliverables': 80,
            'timeline': 60,
            'budget': 80,
            'team': 100,
            'assumptions': 30,
            'ip_clause': 40,
            'payment_terms': 30,
            'termination': 30
        }
        
        optimal_words = {
            'executive_summary': 150,
            'scope': 300,
            'deliverables': 200,
            'timeline': 150,
            'budget': 200,
            'team': 250,
            'assumptions': 80,
            'ip_clause': 80,
            'payment_terms': 60,
            'termination': 60
        }
        
        min_word = min_words.get(section_name, 50)
        optimal_word = optimal_words.get(section_name, 150)
        
        if word_count < min_word:
            return 0.3
        elif word_count >= optimal_word:
            return 1.0
        else:
            # Linear scaling between min and optimal
            return 0.3 + 0.7 * ((word_count - min_word) / (optimal_word - min_word))
    
    def _generate_section_recommendations(self, section_name: str, content: str, score: float) -> List[str]:
        """Generate specific recommendations for a section"""
        recommendations = []
        
        if score < 0.5:
            recommendations.append(f"Expand {section_name} section with more detail")
        
        # Section-specific recommendations
        if section_name == 'scope':
            if 'out of scope' not in content.lower():
                recommendations.append("Consider adding 'out of scope' items to clarify boundaries")
        elif section_name == 'deliverables':
            if not re.search(r'\d', content):
                recommendations.append("Consider adding numbered deliverables for clarity")
        elif section_name == 'timeline':
            if not re.search(r'(?i)(week|month|day|date)', content):
                recommendations.append("Add specific dates or timeframes to the timeline")
        elif section_name == 'budget':
            if '$' not in content and 'cost' not in content.lower():
                recommendations.append("Include specific cost figures or budget breakdown")
        
        return recommendations
