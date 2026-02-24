"""
Risk Analyzer AI Module
Integrates HF model with vector retrieval for comprehensive proposal analysis
"""

import json
import logging
from typing import Dict, Any, List, Optional
import re

from .model_client import get_model_client
from ..vector_store.similarity_search import TemplateSimilaritySearch


class RiskAnalyzer:
    """AI-powered risk analyzer with vector retrieval integration"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.model_client = get_model_client()
        self.vector_search = TemplateSimilaritySearch()
        
        # Analysis prompt template
        self.analysis_prompt = """You are RiskGate AI. Analyze the proposal for completeness, deviations, and risks.
Return JSON ONLY with keys: missing_sections, weak_sections, compound_risks, summary.

Missing sections: List required sections that are completely absent.
Weak sections: List sections that exist but are incomplete or inadequate.
Compound risks: List combined risks from multiple deviations.
Summary: Brief overview of all identified issues.

Proposal:
{proposal_text}

Similar Templates:
{similar_templates}

Analysis:"""
    
    def analyze_proposal(self, text: str) -> Dict[str, Any]:
        """
        Analyze proposal for risks using AI and vector retrieval
        
        Args:
            text: Proposal text to analyze
            
        Returns:
            Analysis results with missing sections, weak sections, compound risks, and summary
        """
        try:
            if not text or not text.strip():
                return {
                    "missing_sections": ["Empty proposal text"],
                    "weak_sections": [],
                    "compound_risks": ["No content to analyze"],
                    "summary": "Proposal text is empty or invalid"
                }
            
            # Retrieve similar templates from vector store
            similar_templates = self._retrieve_similar_templates(text)
            
            # Build analysis prompt
            prompt = self.analysis_prompt.format(
                proposal_text=text.strip(),
                similar_templates=self._format_templates(similar_templates)
            )
            
            # Generate analysis using HF model
            response = self.model_client.generate_text(prompt)
            
            # Parse JSON response
            analysis = self._parse_analysis_response(response)
            
            # Validate and enhance results
            return self._validate_and_enhance_analysis(analysis, text)
            
        except Exception as e:
            self.logger.error(f"Error analyzing proposal: {str(e)}")
            return {
                "missing_sections": ["Analysis failed"],
                "weak_sections": [],
                "compound_risks": [f"Error: {str(e)}"],
                "summary": "Risk analysis encountered an error"
            }
    
    def _retrieve_similar_templates(self, text: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """Retrieve similar templates from vector store"""
        try:
            results = self.vector_search.get_top_k_templates(text, k=top_k)
            # Convert TemplateMatch objects to dicts
            template_dicts = []
            for match in results:
                template_dicts.append({
                    'text': match.content,
                    'similarity_score': match.similarity_score,
                    'template_id': match.template_id,
                    'metadata': match.metadata
                })
            return template_dicts
        except Exception as e:
            self.logger.warning(f"Failed to retrieve templates: {str(e)}")
            return []
    
    def _format_templates(self, templates: List[Dict[str, Any]]) -> str:
        """Format templates for inclusion in prompt"""
        if not templates:
            return "No similar templates found."
        
        formatted = []
        for i, template in enumerate(templates, 1):
            template_text = template.get('text', '')[:500]  # Limit length
            similarity = template.get('similarity_score', 0)
            formatted.append(f"Template {i} (similarity: {similarity:.2f}):\n{template_text}")
        
        return "\n\n".join(formatted)
    
    def _parse_analysis_response(self, response: str) -> Dict[str, Any]:
        """Parse model response into structured JSON"""
        try:
            # Clean response text
            response = response.strip()
            
            # Try to extract JSON from response
            json_match = re.search(r'\{.*\}', response, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                return json.loads(json_str)
            
            # If no JSON found, try to parse entire response
            return json.loads(response)
            
        except json.JSONDecodeError:
            # Fallback: create structured response from text
            return self._create_fallback_analysis(response)
    
    def _create_fallback_analysis(self, response: str) -> Dict[str, Any]:
        """Create structured analysis from unstructured response"""
        lines = response.split('\n')
        missing_sections = []
        weak_sections = []
        compound_risks = []
        summary = response[:200]  # First 200 chars as summary
        
        # Try to extract sections from text
        for line in lines:
            line_lower = line.lower()
            if any(keyword in line_lower for keyword in ['missing', 'absent', 'not found']):
                missing_sections.append(line.strip())
            elif any(keyword in line_lower for keyword in ['weak', 'incomplete', 'inadequate']):
                weak_sections.append(line.strip())
            elif any(keyword in line_lower for keyword in ['risk', 'danger', 'problem']):
                compound_risks.append(line.strip())
        
        return {
            "missing_sections": missing_sections or ["Unable to parse missing sections"],
            "weak_sections": weak_sections or ["Unable to parse weak sections"],
            "compound_risks": compound_risks or ["Unable to parse compound risks"],
            "summary": summary
        }
    
    def _validate_and_enhance_analysis(self, analysis: Dict[str, Any], text: str) -> Dict[str, Any]:
        """Validate and enhance analysis results"""
        # Ensure all required keys exist
        required_keys = ["missing_sections", "weak_sections", "compound_risks", "summary"]
        for key in required_keys:
            if key not in analysis:
                analysis[key] = []
            elif not isinstance(analysis[key], list):
                analysis[key] = [str(analysis[key])]
        
        # Basic validation based on text content
        text_lower = text.lower()
        
        # Check for common missing sections
        common_sections = ['executive summary', 'scope', 'budget', 'timeline', 'team', 'deliverables']
        for section in common_sections:
            if section not in text_lower and section not in [s.lower() for s in analysis['missing_sections']]:
                analysis['missing_sections'].append(f"Missing {section.title()}")
        
        # Ensure summary is meaningful
        if not analysis['summary'] or len(analysis['summary']) < 10:
            total_issues = len(analysis['missing_sections']) + len(analysis['weak_sections']) + len(analysis['compound_risks'])
            analysis['summary'] = f"Analysis complete. Found {total_issues} total issues: {len(analysis['missing_sections'])} missing sections, {len(analysis['weak_sections'])} weak sections, {len(analysis['compound_risks'])} compound risks."
        
        return analysis
    
    def get_model_status(self) -> Dict[str, Any]:
        """Get status of the AI model and components"""
        return {
            "model_loaded": self.model_client.is_loaded(),
            "vector_search_available": self.vector_search is not None,
            "model_name": self.model_client.model_name,
            "device": self.model_client._device
        }


# Global instance
_risk_analyzer = None


def get_risk_analyzer() -> RiskAnalyzer:
    """Get or create global risk analyzer instance"""
    global _risk_analyzer
    if _risk_analyzer is None:
        _risk_analyzer = RiskAnalyzer()
    return _risk_analyzer
