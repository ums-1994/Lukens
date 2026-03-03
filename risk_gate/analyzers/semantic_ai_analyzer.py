"""
Semantic AI Analyzer Module
Uses LLM embeddings for deeper semantic risk analysis
"""

import re
import numpy as np
from typing import Dict, List, Any, Optional, Tuple
import logging

# Import local embedding system
try:
    from ..vector_store.embedder import get_embedder
    from ..vector_store.chroma_client import get_vector_store
    EMBEDDING_AVAILABLE = True
except ImportError:
    EMBEDDING_AVAILABLE = False
    logging.warning("Vector store not available, using fallback analysis")


class SemanticAIAnalyzer:
    """Uses embeddings and semantic analysis for deeper risk detection"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.embedder = None
        self.vector_store = None
        
        if EMBEDDING_AVAILABLE:
            try:
                self.embedder = get_embedder()
                self.vector_store = get_vector_store("proposal_templates")
                self.logger.info("Semantic analyzer initialized with vector store")
            except Exception as e:
                self.logger.warning(f"Failed to initialize vector store: {str(e)}")
        
        # Semantic risk patterns
        self.semantic_patterns = {
            'unrealistic_timeline': {
                'keywords': ['impossible', 'unrealistic', 'cannot', 'unable', 'difficult'],
                'context_patterns': [
                    r'(?i)(complete|finish|deliver)(.{0,100})(in\s+\d+\s+days?|within\s+\d+\s+days?)',
                    r'(?i)(timeline|schedule)(.{0,100})(impossible|unrealistic|ambitious)',
                    r'(?i)(\d+\s+days?|\d+\s+weeks?)(.{0,100})(complete|finish|entire|full)'
                ],
                'weight': 0.25
            },
            'budget_scope_mismatch': {
                'keywords': ['expensive', 'costly', 'overpriced', 'underfunded', 'insufficient'],
                'context_patterns': [
                    r'(?i)(budget|cost|price)(.{0,100})(too\s+high|excessive|expensive)',
                    r'(?i)(scope|work)(.{0,100})(underfunded|insufficient|inadequate)',
                    r'(?i)(complex|extensive|comprehensive)(.{0,100})(budget|cost|price)'
                ],
                'weight': 0.25
            },
            'incoherent_deliverables': {
                'keywords': ['unclear', 'vague', 'undefined', 'confusing', 'ambiguous'],
                'context_patterns': [
                    r'(?i)(deliverables|outputs)(.{0,100})(unclear|vague|undefined)',
                    r'(?i)(results|outcomes)(.{0,100})(uncertain|unclear|ambiguous)',
                    r'(?i)(provide|deliver)(.{0,100})(etc|and\s+more|various)'
                ],
                'weight': 0.20
            },
            'missing_justification': {
                'keywords': ['because', 'since', 'due to', 'therefore', 'thus'],
                'context_patterns': [
                    r'(?i)(cost|price|budget)(.{0,200})(without|no|lacking)(.{0,50})(justification|explanation|reason)',
                    r'(?i)(timeline|schedule)(.{0,200})(without|no|lacking)(.{0,50})(justification|reason|basis)',
                    r'(?i)(require|need)(.{0,100})(but|however)(.{0,100})(no|without)(.{0,50})(explanation)'
                ],
                'weight': 0.15
            },
            'contradictions': {
                'keywords': ['but', 'however', 'although', 'despite', 'whereas'],
                'context_patterns': [
                    r'(?i)(experience|qualified)(.{0,100})(but|however)(.{0,100})(inexperienced|new|junior)',
                    r'(?i)(complete|finish)(.{0,100})(but|however)(.{0,100})(delay|extend|postpone)',
                    r'(?i)(budget|cost)(.{0,100})(but|however)(.{0,100})(expensive|costly|overpriced)',
                    r'(?i)(scope|work)(.{0,100})(but|however)(.{0,100})(limited|small|basic)'
                ],
                'weight': 0.15
            }
        }
    
    def analyze_semantic_risks(self, proposal_text: str) -> Dict[str, Any]:
        """
        Perform semantic risk analysis using embeddings and pattern matching
        
        Args:
            proposal_text: The proposal text to analyze
            
        Returns:
            Dict with semantic risk analysis results
        """
        try:
            results = {
                'ai_semantic_flags': [],
                'semantic_risk_score': 0.0,
                'ai_score': 0.0,
                'embedding_analysis': {},
                'recommendations': []
            }
            
            # Pattern-based semantic analysis
            pattern_results = self._analyze_semantic_patterns(proposal_text)
            
            # Embedding-based analysis if available
            if EMBEDDING_AVAILABLE and self.embedder and self.vector_store:
                embedding_results = self._analyze_with_embeddings(proposal_text)
                results['embedding_analysis'] = embedding_results
            else:
                embedding_results = {'similarity_score': 0.5, 'anomalies': []}
                results['embedding_analysis'] = embedding_results
            
            # Combine results
            results['ai_semantic_flags'] = pattern_results['flags'] + embedding_results.get('anomalies', [])
            results['semantic_risk_score'] = self._calculate_semantic_risk_score(pattern_results, embedding_results)
            results['ai_score'] = 1.0 - results['semantic_risk_score']  # Convert to positive score
            results['recommendations'] = self._generate_semantic_recommendations(results)
            
            self.logger.info(f"Semantic analysis complete: {len(results['ai_semantic_flags'])} flags found")
            
            return results
            
        except Exception as e:
            self.logger.error(f"Error in semantic analysis: {str(e)}")
            return {
                'ai_semantic_flags': [],
                'semantic_risk_score': 0.0,
                'ai_score': 0.0,
                'embedding_analysis': {},
                'recommendations': [],
                'error': str(e)
            }
    
    def _analyze_semantic_patterns(self, text: str) -> Dict[str, Any]:
        """Analyze semantic patterns for risks"""
        results = {
            'flags': [],
            'pattern_scores': {}
        }
        
        total_weight = 0.0
        weighted_score = 0.0
        
        for risk_type, config in self.semantic_patterns.items():
            flags = []
            score = 0.0
            
            # Check keyword presence
            keyword_matches = 0
            for keyword in config['keywords']:
                if re.search(rf'(?i)\b{re.escape(keyword)}\b', text):
                    keyword_matches += 1
            
            # Check context patterns
            context_matches = 0
            for pattern in config['context_patterns']:
                matches = re.findall(pattern, text, re.IGNORECASE)
                if matches:
                    context_matches += len(matches)
                    # Extract context for flags
                    for match in matches[:3]:  # Limit to 3 matches per pattern
                        context = str(match[0] if isinstance(match, tuple) else match)
                        if len(context) > 50:
                            context = context[:100] + "..."
                        flags.append({
                            'type': risk_type,
                            'pattern': pattern,
                            'context': context,
                            'severity': 'high' if context_matches > 2 else 'medium'
                        })
            
            # Calculate score for this risk type
            if keyword_matches > 0 or context_matches > 0:
                # Base score from matches
                base_score = (keyword_matches * 0.3 + context_matches * 0.7) / max(1, len(config['keywords']) + len(config['context_patterns']))
                score = min(1.0, base_score)
            
            results['pattern_scores'][risk_type] = score
            results['flags'].extend(flags)
            
            # Weighted contribution
            weighted_score += score * config['weight']
            total_weight += config['weight']
        
        # Calculate overall pattern score
        if total_weight > 0:
            results['overall_pattern_score'] = weighted_score / total_weight
        else:
            results['overall_pattern_score'] = 0.0
        
        return results
    
    def _analyze_with_embeddings(self, text: str) -> Dict[str, Any]:
        """Analyze using embeddings and vector similarity"""
        try:
            if not self.embedder or not self.vector_store:
                return {'similarity_score': 0.5, 'anomalies': []}
            
            # Get embedding for the proposal text
            proposal_embedding = self.embedder.embed([text])[0]
            
            # Query similar templates - handle different ChromaDB versions
            try:
                # Try newer API first
                similar_templates = self.vector_store.query_similar(
                    query_embeddings=[proposal_embedding],
                    n_results=5,
                    include=['documents', 'metadatas', 'distances']
                )
            except TypeError:
                # Fallback to older API
                try:
                    similar_templates = self.vector_store.collection.query(
                        query_embeddings=[proposal_embedding],
                        n_results=5,
                        include=['documents', 'metadatas', 'distances']
                    )
                except Exception as e:
                    self.logger.warning(f"ChromaDB query failed: {str(e)}")
                    return {'similarity_score': 0.5, 'anomalies': [], 'error': 'ChromaDB API compatibility issue'}
            
            anomalies = []
            similarity_score = 0.0
            
            if similar_templates and similar_templates['ids'] and similar_templates['ids'][0]:
                # Analyze similarity patterns
                distances = similar_templates['distances'][0]
                documents = similar_templates['documents'][0]
                metadatas = similar_templates['metadatas'][0]
                
                # Calculate average similarity
                if distances:
                    # Convert distances to similarities (inverse distance)
                    similarities = [1.0 / (1.0 + d) for d in distances]
                    similarity_score = np.mean(similarities)
                
                # Look for semantic anomalies
                for i, (doc, meta, dist) in enumerate(zip(documents, metadatas, distances)):
                    similarity = 1.0 / (1.0 + dist)
                    
                    # Check for significant deviations
                    if similarity < 0.3:  # Low similarity might indicate issues
                        anomalies.append({
                            'type': 'semantic_deviation',
                            'template_id': meta.get('template_id', f'template_{i}'),
                            'similarity': similarity,
                            'context': f"Low similarity ({similarity:.2f}) with template",
                            'severity': 'medium' if similarity < 0.2 else 'low'
                        })
                    
                    # Check for content length anomalies
                    if len(text) < 0.5 * len(doc):
                        anomalies.append({
                            'type': 'content_length_anomaly',
                            'template_id': meta.get('template_id', f'template_{i}'),
                            'similarity': similarity,
                            'context': f"Proposal significantly shorter than similar template",
                            'severity': 'medium'
                        })
                    elif len(text) > 2.0 * len(doc):
                        anomalies.append({
                            'type': 'content_length_anomaly',
                            'template_id': meta.get('template_id', f'template_{i}'),
                            'similarity': similarity,
                            'context': f"Proposal significantly longer than similar template",
                            'severity': 'low'
                        })
            
            return {
                'similarity_score': similarity_score,
                'anomalies': anomalies,
                'similar_templates_count': len(similar_templates['ids'][0]) if similar_templates and similar_templates['ids'] else 0
            }
            
        except Exception as e:
            self.logger.error(f"Error in embedding analysis: {str(e)}")
            return {'similarity_score': 0.5, 'anomalies': [], 'error': str(e)}
    
    def _calculate_semantic_risk_score(self, pattern_results: Dict[str, Any], embedding_results: Dict[str, Any]) -> float:
        """Calculate overall semantic risk score"""
        # Pattern-based risk (70% weight)
        pattern_risk = pattern_results.get('overall_pattern_score', 0.0)
        
        # Embedding-based risk (30% weight)
        embedding_similarity = embedding_results.get('similarity_score', 0.5)
        embedding_risk = 1.0 - embedding_similarity  # Convert similarity to risk
        
        # Check for anomalies (increase risk)
        anomaly_count = len(embedding_results.get('anomalies', []))
        anomaly_penalty = min(0.2, anomaly_count * 0.05)
        
        # Combined risk score
        combined_risk = (pattern_risk * 0.7) + (embedding_risk * 0.3) + anomaly_penalty
        
        return min(1.0, combined_risk)
    
    def _generate_semantic_recommendations(self, results: Dict[str, Any]) -> List[str]:
        """Generate recommendations based on semantic analysis"""
        recommendations = []
        
        # Recommendations based on semantic flags
        flag_types = [flag['type'] for flag in results['ai_semantic_flags']]
        
        if 'unrealistic_timeline' in flag_types:
            recommendations.append("Timeline appears unrealistic - revise with more achievable deadlines")
        
        if 'budget_scope_mismatch' in flag_types:
            recommendations.append("Budget and scope appear misaligned - adjust cost or modify scope")
        
        if 'incoherent_deliverables' in flag_types:
            recommendations.append("Deliverables are unclear - define specific, measurable outcomes")
        
        if 'missing_justification' in flag_types:
            recommendations.append("Add justifications for budget, timeline, and scope decisions")
        
        if 'contradictions' in flag_types:
            recommendations.append("Resolve contradictions in proposal statements")
        
        if 'semantic_deviation' in flag_types:
            recommendations.append("Proposal deviates significantly from standard templates - review for completeness")
        
        if 'content_length_anomaly' in flag_types:
            recommendations.append("Consider expanding or condensing proposal content to match standard templates")
        
        # Recommendations based on embedding analysis
        similarity_score = results['embedding_analysis'].get('similarity_score', 0.5)
        if similarity_score < 0.3:
            recommendations.append("Proposal content differs significantly from templates - ensure all required sections are included")
        elif similarity_score > 0.9:
            recommendations.append("Proposal very similar to templates - ensure customization for specific requirements")
        
        # Overall recommendations
        if results['semantic_risk_score'] > 0.7:
            recommendations.append("High semantic risk detected - comprehensive review recommended")
        elif results['semantic_risk_score'] > 0.5:
            recommendations.append("Moderate semantic risk - targeted improvements needed")
        
        return recommendations
    
    def check_semantic_coherence(self, text: str) -> Dict[str, Any]:
        """
        Check semantic coherence of the proposal
        
        Args:
            text: Proposal text
            
        Returns:
            Dict with coherence analysis
        """
        try:
            coherence_score = 0.0
            coherence_issues = []
            
            # Check for contradictory statements
            contradiction_patterns = [
                (r'(?i)(experienced|qualified)(.{0,100})(but|however)(.{0,100})(inexperienced|new|junior)', 'experience_contradiction'),
                (r'(?i)(complete|finish)(.{0,100})(but|however)(.{0,100})(delay|extend|postpone)', 'timeline_contradiction'),
                (r'(?i)(budget|cost)(.{0,100})(but|however)(.{0,100})(expensive|costly|overpriced)', 'budget_contradiction'),
                (r'(?i)(comprehensive|complete)(.{0,100})(but|however)(.{0,100})(limited|small|basic)', 'scope_contradiction')
            ]
            
            for pattern, issue_type in contradiction_patterns:
                matches = re.findall(pattern, text, re.IGNORECASE)
                if matches:
                    coherence_issues.append({
                        'type': issue_type,
                        'matches': len(matches),
                        'severity': 'high'
                    })
                    coherence_score -= 0.2
            
            # Normalize score
            coherence_score = max(0.0, min(1.0, coherence_score + 1.0))
            
            return {
                'coherence_score': coherence_score,
                'coherence_issues': coherence_issues,
                'is_coherent': coherence_score > 0.7
            }
            
        except Exception as e:
            self.logger.error(f"Error checking coherence: {str(e)}")
            return {
                'coherence_score': 0.5,
                'coherence_issues': [],
                'is_coherent': True,
                'error': str(e)
            }
