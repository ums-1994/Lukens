"""
Clause Analyzer Module
Detects altered or incomplete clauses by comparing against templates
"""

import re
from typing import Dict, List, Any, Optional, Tuple
import logging
from difflib import SequenceMatcher
import numpy as np


class ClauseAnalyzer:
    """Analyzes proposal clauses against template clauses for alterations"""
    
    def __init__(self, template_loader=None):
        self.logger = logging.getLogger(__name__)
        self.template_loader = template_loader
        self.similarity_threshold = 0.7
        
        # Common clause patterns to identify
        self.clause_patterns = {
            'ip_clause': [
                r'(?i)(intellectual\s+property\s+rights?|ip\s+rights?|ownership)',
                r'(?i)(proprietary\s+information|confidential\s+information)',
                r'(?i)(copyright|trademark|patent\s+rights?)',
                r'(?i)(work\s+for\s+hire|work\s+made\s+for\s+hire)'
            ],
            'payment_terms': [
                r'(?i)(payment\s+terms?|payment\s+schedule|billing\s+terms?)',
                r'(?i)(net\s+\d+|payment\s+within|due\s+upon)',
                r'(?i)(invoice|billing|payment\s+method)'
            ],
            'termination': [
                r'(?i)(termination|cancellation|exit\s+clause)',
                r'(?i)(terminate\s+this\s+agreement|cancel\s+this\s+contract)',
                r'(?i)(notice\s+period|termination\s+notice)'
            ],
            'liability': [
                r'(?i)(liability|limitation\s+of\s+liability)',
                r'(?i)(indemnify|indemnification|hold\s+harmless)',
                r'(?i)(damages|compensation|reimbursement)'
            ],
            'confidentiality': [
                r'(?i)(confidential\s+information|non-disclosure|nd[a])',
                r'(?i)(proprietary\s+information|trade\s+secrets)',
                r'(?i)(keep\s+confidential|maintain\s+secrecy)'
            ],
            'warranty': [
                r'(?i)(warranty|guarantee|assurance)',
                r'(?i)(work\s+performed\s+in\s+a|workmanlike\s+manner)',
                r'(?i)(fit\s+for\s+purpose|suitable\s+for)'
            ]
        }
    
    def analyze_clauses(self, proposal_text: str) -> Dict[str, Any]:
        """
        Analyze proposal clauses against templates
        
        Args:
            proposal_text: The proposal text to analyze
            
        Returns:
            Dict with clause analysis results
        """
        try:
            results = {
                'altered_clauses': [],
                'missing_clauses': [],
                'clause_similarity_scores': {},
                'clause_risk_score': 0.0,
                'recommendations': []
            }
            
            if not self.template_loader:
                self.logger.warning("No template loader provided, using basic analysis")
                return self._basic_clause_analysis(proposal_text)
            
            # Extract clauses from proposal
            proposal_clauses = self._extract_clauses(proposal_text)
            
            # Compare each clause type against templates
            for clause_type, patterns in self.clause_patterns.items():
                clause_result = self._analyze_clause_type(
                    clause_type, patterns, proposal_clauses, proposal_text
                )
                
                if clause_result['altered_clauses']:
                    results['altered_clauses'].extend(clause_result['altered_clauses'])
                
                if clause_result['missing_clauses']:
                    results['missing_clauses'].extend(clause_result['missing_clauses'])
                
                results['clause_similarity_scores'][clause_type] = clause_result['similarity_score']
            
            # Calculate overall clause risk score
            results['clause_risk_score'] = self._calculate_clause_risk_score(results)
            
            # Generate recommendations
            results['recommendations'] = self._generate_clause_recommendations(results)
            
            self.logger.info(f"Clause analysis complete: {len(results['altered_clauses'])} altered clauses found")
            
            return results
            
        except Exception as e:
            self.logger.error(f"Error in clause analysis: {str(e)}")
            return {
                'altered_clauses': [],
                'missing_clauses': [],
                'clause_similarity_scores': {},
                'clause_risk_score': 0.0,
                'recommendations': [],
                'error': str(e)
            }
    
    def _basic_clause_analysis(self, proposal_text: str) -> Dict[str, Any]:
        """Basic clause analysis without template comparison"""
        results = {
            'altered_clauses': [],
            'missing_clauses': [],
            'clause_similarity_scores': {},
            'clause_risk_score': 0.0,
            'recommendations': []
        }
        
        # Just check for presence of common clauses
        for clause_type, patterns in self.clause_patterns.items():
            has_clause = any(re.search(pattern, proposal_text) for pattern in patterns)
            
            if not has_clause:
                results['missing_clauses'].append({
                    'clause_type': clause_type,
                    'description': f"Missing {clause_type.replace('_', ' ').title()} clause",
                    'severity': 'medium'
                })
                
                results['clause_similarity_scores'][clause_type] = 0.0
            else:
                results['clause_similarity_scores'][clause_type] = 1.0
        
        # Calculate basic risk score
        if results['clause_similarity_scores']:
            results['clause_risk_score'] = 1.0 - (sum(results['clause_similarity_scores'].values()) / len(results['clause_similarity_scores']))
        
        results['recommendations'] = self._generate_clause_recommendations(results)
        
        return results
    
    def _extract_clauses(self, text: str) -> Dict[str, List[str]]:
        """Extract clauses from text based on patterns"""
        clauses = {}
        
        for clause_type, patterns in self.clause_patterns.items():
            clause_texts = []
            
            for pattern in patterns:
                matches = re.finditer(pattern, text)
                for match in matches:
                    # Extract context around the match
                    start = max(0, match.start() - 50)
                    end = min(len(text), match.end() + 200)
                    clause_text = text[start:end].strip()
                    
                    if clause_text and clause_text not in clause_texts:
                        clause_texts.append(clause_text)
            
            clauses[clause_type] = clause_texts
        
        return clauses
    
    def _analyze_clause_type(self, clause_type: str, patterns: List[str], 
                            proposal_clauses: Dict[str, List[str]], proposal_text: str) -> Dict[str, Any]:
        """Analyze a specific clause type"""
        result = {
            'altered_clauses': [],
            'missing_clauses': [],
            'similarity_score': 0.0
        }
        
        # Get template clauses for this type
        template_clauses = self.template_loader.get_template_sections(clause_type)
        
        if not template_clauses:
            # No templates available, just check for presence
            if clause_type not in proposal_clauses or not proposal_clauses[clause_type]:
                result['missing_clauses'].append({
                    'clause_type': clause_type,
                    'description': f"Missing {clause_type.replace('_', ' ').title()} clause",
                    'severity': 'medium'
                })
            else:
                result['similarity_score'] = 1.0
            
            return result
        
        # Compare proposal clauses against templates
        best_similarity = 0.0
        
        for proposal_clause in proposal_clauses.get(clause_type, []):
            max_similarity = 0.0
            best_template = ""
            
            for template_clause in template_clauses:
                similarity = self._calculate_similarity(proposal_clause, template_clause)
                
                if similarity > max_similarity:
                    max_similarity = similarity
                    best_template = template_clause
            
            if max_similarity < self.similarity_threshold:
                result['altered_clauses'].append({
                    'clause_type': clause_type,
                    'proposal_clause': proposal_clause[:200] + "..." if len(proposal_clause) > 200 else proposal_clause,
                    'best_template_match': best_template[:200] + "..." if len(best_template) > 200 else best_template,
                    'similarity_score': max_similarity,
                    'severity': 'high' if max_similarity < 0.5 else 'medium'
                })
            
            best_similarity = max(best_similarity, max_similarity)
        
        # Check for missing clauses
        if clause_type not in proposal_clauses or not proposal_clauses[clause_type]:
            result['missing_clauses'].append({
                'clause_type': clause_type,
                'description': f"Missing {clause_type.replace('_', ' ').title()} clause",
                'severity': 'high'
            })
            best_similarity = 0.0
        
        result['similarity_score'] = best_similarity
        
        return result
    
    def _calculate_similarity(self, text1: str, text2: str) -> float:
        """Calculate similarity between two text strings"""
        # Use multiple similarity measures for robustness
        
        # 1. Sequence matcher (good for structural similarity)
        seq_similarity = SequenceMatcher(None, text1.lower(), text2.lower()).ratio()
        
        # 2. Word overlap (good for content similarity)
        words1 = set(text1.lower().split())
        words2 = set(text2.lower().split())
        
        if not words1 or not words2:
            word_similarity = 0.0
        else:
            intersection = words1.intersection(words2)
            union = words1.union(words2)
            word_similarity = len(intersection) / len(union)
        
        # 3. Jaccard similarity on character n-grams (good for phrasing)
        def ngram_similarity(s1, s2, n=3):
            ngrams1 = set(s1[i:i+n] for i in range(len(s1)-n+1))
            ngrams2 = set(s2[i:i+n] for i in range(len(s2)-n+1))
            
            if not ngrams1 or not ngrams2:
                return 0.0
            
            intersection = ngrams1.intersection(ngrams2)
            union = ngrams1.union(ngrams2)
            
            return len(intersection) / len(union)
        
        ngram_sim = ngram_similarity(text1.lower(), text2.lower())
        
        # Weighted combination
        combined_similarity = (0.4 * seq_similarity + 0.4 * word_similarity + 0.2 * ngram_sim)
        
        return combined_similarity
    
    def _calculate_clause_risk_score(self, results: Dict[str, Any]) -> float:
        """Calculate overall clause risk score"""
        if not results['clause_similarity_scores']:
            return 0.0
        
        # Weight by clause importance
        clause_weights = {
            'ip_clause': 0.25,
            'payment_terms': 0.20,
            'termination': 0.20,
            'liability': 0.15,
            'confidentiality': 0.10,
            'warranty': 0.10
        }
        
        weighted_score = 0.0
        total_weight = 0.0
        
        for clause_type, similarity_score in results['clause_similarity_scores'].items():
            weight = clause_weights.get(clause_type, 0.1)
            risk_score = 1.0 - similarity_score  # Convert similarity to risk
            weighted_score += risk_score * weight
            total_weight += weight
        
        if total_weight > 0:
            return weighted_score / total_weight
        
        return 0.0
    
    def _generate_clause_recommendations(self, results: Dict[str, Any]) -> List[str]:
        """Generate recommendations based on clause analysis"""
        recommendations = []
        
        # Recommendations for altered clauses
        for altered_clause in results['altered_clauses']:
            clause_type = altered_clause['clause_type']
            severity = altered_clause['severity']
            
            if severity == 'high':
                recommendations.append(f"Critical: {clause_type.replace('_', ' ').title()} clause appears significantly altered from standard templates")
            else:
                recommendations.append(f"Review {clause_type.replace('_', ' ').title()} clause for alignment with standard practices")
        
        # Recommendations for missing clauses
        for missing_clause in results['missing_clauses']:
            clause_type = missing_clause['clause_type']
            severity = missing_clause['severity']
            
            if severity == 'high':
                recommendations.append(f"Add {clause_type.replace('_', ' ').title()} clause to protect both parties")
            else:
                recommendations.append(f"Consider adding {clause_type.replace('_', ' ').title()} clause for clarity")
        
        # General recommendations
        if results['clause_risk_score'] > 0.7:
            recommendations.append("Multiple clause issues detected - consider legal review before proceeding")
        elif results['clause_risk_score'] > 0.4:
            recommendations.append("Some clause deviations detected - review for compliance")
        
        return recommendations
