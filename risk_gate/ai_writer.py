"""
AI Writer Module
Generates proposal content using local embeddings and template matching
"""

import re
import numpy as np
from typing import Dict, List, Any, Optional
import logging
from collections import Counter

# Import local embedding system
try:
    from ..vector_store.embedder import get_embedder
    from ..vector_store.chroma_client import get_vector_store
    from ..utils.template_loader import TemplateLoader
    EMBEDDING_AVAILABLE = True
except ImportError:
    EMBEDDING_AVAILABLE = False
    logging.warning("Vector store not available, using fallback generation")


class AIWriter:
    """AI-powered content generation using local embeddings"""
    
    def __init__(self, templates_path: str = None):
        self.logger = logging.getLogger(__name__)
        self.templates_path = templates_path or "C:/Users/User/Downloads/Lukens-AI_RiskGate/risk_gate/Templates"
        
        if EMBEDDING_AVAILABLE:
            try:
                self.embedder = get_embedder()
                self.vector_store = get_vector_store("proposal_templates")
                self.template_loader = TemplateLoader(self.templates_path)
                self.logger.info("AI Writer initialized with local embeddings")
            except Exception as e:
                self.logger.warning(f"Failed to initialize AI Writer: {str(e)}")
                self.embedder = None
                self.vector_store = None
                self.template_loader = None
        else:
            self.embedder = None
            self.vector_store = None
            self.template_loader = None
    
    def generate_missing_section(self, section_name: str, proposal_text: str, template_examples: List[str] = None) -> Dict[str, Any]:
        """
        Generate a missing section using template context and embeddings
        
        Args:
            section_name: Name of the section to generate
            proposal_text: Current proposal text for context
            template_examples: Optional list of template examples
            
        Returns:
            Dict with generated content and metadata
        """
        try:
            if not EMBEDDING_AVAILABLE or not self.embedder:
                return self._fallback_section_generation(section_name, proposal_text)
            
            # Get template examples for this section
            if not template_examples:
                template_examples = self._get_template_section_examples(section_name)
            
            if not template_examples:
                return self._fallback_section_generation(section_name, proposal_text)
            
            # Generate content using template patterns and context
            generated_content = self._generate_section_from_templates(
                section_name, proposal_text, template_examples
            )
            
            # Calculate confidence based on template similarity
            confidence = self._calculate_generation_confidence(
                generated_content, template_examples
            )
            
            reasoning = f"Generated {section_name} section using {len(template_examples)} template examples with {confidence:.1%} confidence"
            
            return {
                'success': True,
                'generated_text': generated_content,
                'reasoning': reasoning,
                'confidence': confidence
            }
            
        except Exception as e:
            self.logger.error(f"Error generating section {section_name}: {str(e)}")
            return {
                'success': False,
                'generated_text': '',
                'reasoning': f"Error: {str(e)}",
                'confidence': 0.0
            }
    
    def improve_weak_area(self, area_name: str, proposal_text: str) -> Dict[str, Any]:
        """
        Improve a weak area in the proposal
        
        Args:
            area_name: Name of the weak area to improve
            proposal_text: Current proposal text
            
        Returns:
            Dict with improved content and metadata
        """
        try:
            if not EMBEDDING_AVAILABLE or not self.embedder:
                return self._fallback_area_improvement(area_name, proposal_text)
            
            # Extract current content for the weak area
            current_content = self._extract_area_content(area_name, proposal_text)
            
            # Get strong examples from templates
            strong_examples = self._get_strong_examples(area_name)
            
            if not strong_examples:
                return self._fallback_area_improvement(area_name, proposal_text)
            
            # Generate improved content
            improved_content = self._improve_content_with_templates(
                current_content, strong_examples, area_name
            )
            
            # Calculate confidence
            confidence = self._calculate_improvement_confidence(
                current_content, improved_content, strong_examples
            )
            
            reasoning = f"Improved {area_name} using {len(strong_examples)} strong examples with {confidence:.1%} confidence"
            
            return {
                'success': True,
                'generated_text': improved_content,
                'reasoning': reasoning,
                'confidence': confidence
            }
            
        except Exception as e:
            self.logger.error(f"Error improving area {area_name}: {str(e)}")
            return {
                'success': False,
                'generated_text': '',
                'reasoning': f"Error: {str(e)}",
                'confidence': 0.0
            }
    
    def correct_clause(self, clause_name: str, proposal_text: str, template_clause: str = None) -> Dict[str, Any]:
        """
        Correct an incorrect clause to match standard template wording
        
        Args:
            clause_name: Name of the clause to correct
            proposal_text: Current proposal text
            template_clause: Optional template clause to match
            
        Returns:
            Dict with corrected clause and metadata
        """
        try:
            if not EMBEDDING_AVAILABLE or not self.embedder:
                return self._fallback_clause_correction(clause_name, proposal_text, template_clause)
            
            # Extract current clause content
            current_clause = self._extract_clause_content(clause_name, proposal_text)
            
            # Get standard template clauses
            if not template_clause:
                template_clauses = self._get_template_clauses(clause_name)
                if template_clauses:
                    template_clause = template_clauses[0]  # Use the best match
            
            if not template_clause:
                return self._fallback_clause_correction(clause_name, proposal_text, template_clause)
            
            # Generate corrected clause
            corrected_clause = self._correct_clause_with_template(
                current_clause, template_clause, clause_name
            )
            
            # Calculate confidence
            confidence = self._calculate_clause_confidence(
                corrected_clause, template_clause
            )
            
            reasoning = f"Corrected {clause_name} clause to match template standards with {confidence:.1%} confidence"
            
            return {
                'success': True,
                'generated_text': corrected_clause,
                'reasoning': reasoning,
                'confidence': confidence
            }
            
        except Exception as e:
            self.logger.error(f"Error correcting clause {clause_name}: {str(e)}")
            return {
                'success': False,
                'generated_text': '',
                'reasoning': f"Error: {str(e)}",
                'confidence': 0.0
            }
    
    def _get_template_section_examples(self, section_name: str) -> List[str]:
        """Get template examples for a specific section"""
        if not self.template_loader:
            return []
        
        # Map section names to template sections
        section_mapping = {
            'executive_summary': 'executive_summary',
            'scope': 'scope',
            'deliverables': 'deliverables',
            'timeline': 'timeline',
            'budget': 'budget',
            'team': 'team',
            'assumptions': 'assumptions',
            'ip_clause': 'ip_clause',
            'payment_terms': 'payment_terms',
            'termination': 'termination'
        }
        
        template_section = section_mapping.get(section_name.lower(), section_name.lower())
        return self.template_loader.get_template_sections(template_section)
    
    def _generate_section_from_templates(self, section_name: str, proposal_text: str, examples: List[str]) -> str:
        """Generate section content from template examples"""
        if not examples:
            return self._create_basic_section(section_name, proposal_text)
        
        # Extract key information from proposal text for context
        context_keywords = self._extract_context_keywords(proposal_text)
        
        # Use the best template example as base
        best_example = self._select_best_template(examples, context_keywords)
        
        # Customize the template based on proposal context
        customized_content = self._customize_template_content(
            best_example, context_keywords, section_name
        )
        
        return customized_content
    
    def _select_best_template(self, examples: List[str], context_keywords: List[str]) -> str:
        """Select the best template example based on context"""
        if not examples:
            return ""
        
        if len(examples) == 1:
            return examples[0]
        
        # Score each example based on keyword overlap
        best_score = 0
        best_example = examples[0]
        
        for example in examples:
            score = 0
            example_words = set(example.lower().split())
            
            for keyword in context_keywords:
                if keyword.lower() in example_words:
                    score += 1
            
            if score > best_score:
                best_score = score
                best_example = example
        
        return best_example
    
    def _customize_template_content(self, template: str, context_keywords: List[str], section_name: str) -> str:
        """Customize template content based on proposal context"""
        # Basic customization - in a real implementation, this would be more sophisticated
        customized = template
        
        # Add context-specific modifications
        if section_name == 'executive_summary':
            if any(keyword in context_keywords for keyword in ['software', 'development', 'application']):
                customized = self._add_software_context(customized)
            elif any(keyword in context_keywords for keyword in ['consulting', 'services', 'advisory']):
                customized = self._add_consulting_context(customized)
        
        elif section_name == 'timeline':
            # Add realistic timeline based on project complexity
            if 'complex' in context_keywords or 'comprehensive' in context_keywords:
                customized = self._adjust_timeline_complexity(customized, increase=True)
            else:
                customized = self._adjust_timeline_complexity(customized, increase=False)
        
        elif section_name == 'budget':
            # Add budget breakdown structure
            customized = self._add_budget_structure(customized)
        
        return customized
    
    def _add_software_context(self, content: str) -> str:
        """Add software development context to content"""
        software_phrases = [
            "software development",
            "technical implementation",
            "code quality",
            "testing and deployment",
            "maintenance and support"
        ]
        
        # Simple insertion of software-specific terms
        if "development" not in content.lower():
            content = content.replace("project", "software development project")
        
        return content
    
    def _add_consulting_context(self, content: str) -> str:
        """Add consulting services context to content"""
        consulting_phrases = [
            "consulting services",
            "professional expertise",
            "strategic guidance",
            "best practices",
            "client collaboration"
        ]
        
        if "services" not in content.lower():
            content = content.replace("project", "consulting services project")
        
        return content
    
    def _adjust_timeline_complexity(self, content: str, increase: bool = True) -> str:
        """Adjust timeline based on project complexity"""
        if increase:
            # Add more phases and longer duration
            if "weeks" in content.lower():
                content = re.sub(r'(\d+)\s*weeks?', lambda m: str(int(m.group(1)) * 1.5) + " weeks", content)
        else:
            # Reduce timeline for simpler projects
            if "weeks" in content.lower():
                content = re.sub(r'(\d+)\s*weeks?', lambda m: str(max(4, int(m.group(1)) * 0.8)) + " weeks", content)
        
        return content
    
    def _add_budget_structure(self, content: str) -> str:
        """Add structured budget breakdown"""
        if "breakdown" not in content.lower() and "$" in content:
            content += "\n\nBudget Breakdown:\n- Phase 1: Planning and Design\n- Phase 2: Development/Implementation\n- Phase 3: Testing and Quality Assurance\n- Phase 4: Deployment and Training\n- Contingency: 10%"
        
        return content
    
    def _create_basic_section(self, section_name: str, proposal_text: str) -> str:
        """Create a basic section when no templates are available"""
        section_templates = {
            'executive_summary': f"""
EXECUTIVE SUMMARY

This proposal outlines our comprehensive approach to delivering exceptional value for your project. Our solution addresses your key requirements while ensuring quality, efficiency, and successful outcomes.

Key Highlights:
- Professional expertise and experience
- Proven methodology and approach
- Commitment to quality and timelines
- Competitive pricing structure

We look forward to partnering with you to achieve your project goals.
            """.strip(),
            
            'scope': f"""
SCOPE OF WORK

Our comprehensive scope includes all necessary activities to ensure project success:

Primary Deliverables:
- Complete project implementation
- Quality assurance and testing
- Documentation and training
- Ongoing support and maintenance

Project Boundaries:
- All specified requirements will be fulfilled
- Clear definition of responsibilities
- Regular progress reporting
- Change management process

Exclusions:
- Out-of-scope modifications will be addressed separately
- Additional requirements will be quoted separately
            """.strip(),
            
            'deliverables': f"""
DELIVERABLES

We will deliver the following items as part of this project:

1. Project Documentation
   - Requirements specification
   - Design documentation
   - User manuals and guides

2. Implementation Results
   - Fully functional solution
   - Tested and validated outputs
   - Deployment-ready components

3. Support Materials
   - Training documentation
   - Maintenance guides
   - Technical specifications

All deliverables will be provided in the agreed formats and within specified timelines.
            """.strip(),
            
            'timeline': f"""
PROJECT TIMELINE

The project will be executed in the following phases:

Phase 1: Planning and Design (2-3 weeks)
- Requirements gathering and analysis
- Solution design and architecture
- Resource allocation and planning

Phase 2: Implementation (4-6 weeks)
- Development and configuration
- Regular progress reviews
- Quality assurance activities

Phase 3: Testing and Deployment (2-3 weeks)
- Comprehensive testing
- User acceptance testing
- Final deployment and handover

Phase 4: Support and Training (1-2 weeks)
- User training sessions
- Documentation handover
- Post-deployment support

Total estimated duration: 8-12 weeks
            """.strip(),
            
            'budget': f"""
BUDGET PROPOSAL

Total Project Investment: $50,000

Cost Breakdown:
- Phase 1 (Planning): $10,000 (20%)
- Phase 2 (Implementation): $25,000 (50%)
- Phase 3 (Testing): $10,000 (20%)
- Phase 4 (Support): $5,000 (10%)

Payment Terms:
- 30% upon project commencement
- 40% upon milestone completion
- 30% upon final delivery and acceptance

Includes:
- All specified deliverables
- Documentation and training
- 3 months post-launch support
- Travel and expenses (if applicable)

Excludes:
- Scope changes beyond original requirements
- Additional features not specified
- Third-party software licenses
            """.strip(),
            
            'team': f"""
PROJECT TEAM

Our experienced team brings extensive expertise to ensure project success:

Project Leadership:
- Project Manager with 10+ years experience
- Certified in project management methodologies
- Proven track record of successful deliveries

Technical Team:
- Senior Technical Lead with 8+ years experience
- Specialized expertise in relevant technologies
- Strong problem-solving capabilities

Support Team:
- Quality Assurance Specialist
- Documentation and Training Expert
- Customer Success Manager

All team members undergo regular training and certification to maintain current industry knowledge and best practices.
            """.strip(),
            
            'assumptions': f"""
PROJECT ASSUMPTIONS

This proposal is based on the following key assumptions:

Client Responsibilities:
- Timely provision of required information and resources
- Availability of key stakeholders for reviews and approvals
- Provision of necessary access to systems and facilities
- Clear and timely decision-making

Technical Assumptions:
- Existing infrastructure will support proposed solution
- Required software licenses and tools will be available
- Integration points will be accessible as specified
- Security and compliance requirements will be maintained

Timeline Assumptions:
- No significant delays in requirement changes
- Resource availability as planned
- Third-party dependencies will be delivered on schedule
- Testing environments will be available when needed

Any changes to these assumptions may impact project timeline and cost, which will be addressed through the change management process.
            """.strip()
        }
        
        return section_templates.get(section_name.lower(), f"{section_name.upper()}\n\nThis section contains important information related to {section_name}. Content will be customized based on your specific project requirements and our proven methodologies.")
    
    def _extract_context_keywords(self, proposal_text: str) -> List[str]:
        """Extract relevant keywords from proposal text for context"""
        # Common business and technical keywords
        business_keywords = [
            'software', 'development', 'application', 'system', 'platform',
            'consulting', 'services', 'solution', 'project', 'implementation',
            'integration', 'deployment', 'testing', 'quality', 'maintenance',
            'support', 'training', 'documentation', 'management', 'strategy'
        ]
        
        # Find keywords present in the text
        found_keywords = []
        text_lower = proposal_text.lower()
        
        for keyword in business_keywords:
            if keyword in text_lower:
                found_keywords.append(keyword)
        
        return found_keywords[:10]  # Limit to top 10 keywords
    
    def _get_strong_examples(self, area_name: str) -> List[str]:
        """Get strong examples for improving weak areas"""
        if not self.template_loader:
            return []
        
        # Map weak areas to template sections
        area_mapping = {
            'weak_bios': 'team',
            'weak_timeline': 'timeline',
            'weak_budget': 'budget',
            'weak_scope': 'scope',
            'weak_deliverables': 'deliverables'
        }
        
        template_section = area_mapping.get(area_name.lower(), area_name.lower().replace('weak_', ''))
        examples = self.template_loader.get_template_sections(template_section)
        
        # Filter for strong examples (longer, more detailed)
        strong_examples = []
        for example in examples:
            if len(example.split()) > 50:  # Only include substantial examples
                strong_examples.append(example)
        
        return strong_examples[:3]  # Return top 3 strong examples
    
    def _extract_area_content(self, area_name: str, proposal_text: str) -> str:
        """Extract current content for a specific area"""
        # Map area names to section patterns
        area_patterns = {
            'weak_bios': [r'(?i)(team|personnel|staff|bios|about\s+us)(.{0,500})'],
            'weak_timeline': [r'(?i)(timeline|schedule|project\s+schedule|milestones)(.{0,500})'],
            'weak_budget': [r'(?i)(budget|cost|pricing|fees|investment)(.{0,500})'],
            'weak_scope': [r'(?i)(scope\s+of\s+work|project\s+scope|statement\s+of\s+work)(.{0,500})'],
            'weak_deliverables': [r'(?i)(deliverables|outputs|results)(.{0,500})']
        }
        
        patterns = area_patterns.get(area_name.lower(), [])
        
        for pattern in patterns:
            match = re.search(pattern, proposal_text)
            if match:
                return match.group(0).strip()
        
        return ""
    
    def _improve_content_with_templates(self, current_content: str, strong_examples: List[str], area_name: str) -> str:
        """Improve content using strong template examples"""
        if not strong_examples:
            return current_content
        
        # Select the best example based on similarity to current content
        best_example = self._select_best_improvement_example(current_content, strong_examples)
        
        # Merge current content with best practices from template
        improved_content = self._merge_content_with_best_practices(
            current_content, best_example, area_name
        )
        
        return improved_content
    
    def _select_best_improvement_example(self, current_content: str, examples: List[str]) -> str:
        """Select the best template example for improvement"""
        if not examples:
            return ""
        
        # Simple selection based on length and keyword overlap
        current_words = set(current_content.lower().split())
        
        best_score = 0
        best_example = examples[0]
        
        for example in examples:
            example_words = set(example.lower().split())
            
            # Score based on word overlap and length
            overlap = len(current_words.intersection(example_words))
            length_score = min(1.0, len(example.split()) / 100)  # Prefer longer examples
            
            combined_score = overlap + (length_score * 10)
            
            if combined_score > best_score:
                best_score = combined_score
                best_example = example
        
        return best_example
    
    def _merge_content_with_best_practices(self, current: str, template: str, area_name: str) -> str:
        """Merge current content with best practices from template"""
        # Simple merge strategy - in a real implementation, this would be more sophisticated
        if len(current) < 100:  # If current content is very short, use template
            return template
        
        # If current content has some substance, enhance it
        enhanced = current
        
        # Add missing structural elements based on area type
        if area_name == 'weak_timeline' and 'phase' not in enhanced.lower():
            enhanced += "\n\nPhases:\n- Phase 1: Planning and preparation\n- Phase 2: Implementation\n- Phase 3: Testing and validation\n- Phase 4: Delivery and handover"
        
        elif area_name == 'weak_budget' and 'breakdown' not in enhanced.lower():
            enhanced += "\n\nBudget Breakdown:\n- Personnel costs\n- Technology and tools\n- Project management\n- Quality assurance\n- Contingency planning"
        
        elif area_name == 'weak_bios' and 'experience' not in enhanced.lower():
            enhanced += "\n\nOur team brings extensive experience with proven track records in delivering successful projects."
        
        return enhanced
    
    def _get_template_clauses(self, clause_name: str) -> List[str]:
        """Get template clauses for a specific clause type"""
        if not self.template_loader:
            return []
        
        # Map clause names to template sections
        clause_mapping = {
            'ip_clause': 'ip_clause',
            'payment_terms': 'payment_terms',
            'termination': 'termination',
            'liability': 'liability',
            'confidentiality': 'confidentiality',
            'warranty': 'warranty'
        }
        
        template_section = clause_mapping.get(clause_name.lower(), clause_name.lower())
        return self.template_loader.get_template_sections(template_section)
    
    def _extract_clause_content(self, clause_name: str, proposal_text: str) -> str:
        """Extract current clause content"""
        # Clause patterns
        clause_patterns = {
            'ip_clause': [r'(?i)(intellectual\s+property|ip\s+rights|ownership)(.{0,300})'],
            'payment_terms': [r'(?i)(payment\s+terms|payment\s+schedule|billing)(.{0,300})'],
            'termination': [r'(?i)(termination|cancellation|exit\s+clause)(.{0,300})'],
            'liability': [r'(?i)(liability|limitation\s+of\s+liability)(.{0,300})'],
            'confidentiality': [r'(?i)(confidential\s+information|non-disclosure)(.{0,300})'],
            'warranty': [r'(?i)(warranty|guarantee|assurance)(.{0,300})']
        }
        
        patterns = clause_patterns.get(clause_name.lower(), [])
        
        for pattern in patterns:
            match = re.search(pattern, proposal_text)
            if match:
                return match.group(0).strip()
        
        return ""
    
    def _correct_clause_with_template(self, current_clause: str, template_clause: str, clause_name: str) -> str:
        """Correct clause using template as reference"""
        # If current clause is very short or missing, use template
        if len(current_clause) < 50:
            return template_clause
        
        # For substantial clauses, enhance with template language
        corrected = current_clause
        
        # Add missing standard elements based on clause type
        if clause_name == 'ip_clause':
            if 'work for hire' not in corrected.lower():
                corrected += "\nAll work performed shall be considered 'work for hire' and all rights shall transfer to the client upon full payment."
            if 'proprietary' not in corrected.lower():
                corrected += "\nEach party shall retain rights to their pre-existing proprietary materials."
        
        elif clause_name == 'payment_terms':
            if 'net' not in corrected.lower():
                corrected += "\nPayments are due Net 30 days from invoice date."
            if 'late' not in corrected.lower():
                corrected += "\nLate payments shall incur interest at 1.5% per month."
        
        elif clause_name == 'termination':
            if 'notice' not in corrected.lower():
                corrected += "\nEither party may terminate with 30 days written notice."
            if 'payment' not in corrected.lower():
                corrected += "\nClient shall pay for all work completed up to termination date."
        
        return corrected
    
    def _calculate_generation_confidence(self, generated: str, examples: List[str]) -> float:
        """Calculate confidence score for generated content"""
        if not examples:
            return 0.5  # Default confidence for fallback generation
        
        # Calculate similarity to examples
        total_similarity = 0
        for example in examples:
            similarity = self._calculate_text_similarity(generated, example)
            total_similarity += similarity
        
        average_similarity = total_similarity / len(examples)
        
        # Adjust confidence based on content length and structure
        length_score = min(1.0, len(generated.split()) / 100)  # Prefer substantial content
        structure_score = 1.0 if len(generated.split('\n')) > 3 else 0.8  # Prefer structured content
        
        confidence = (average_similarity * 0.6) + (length_score * 0.2) + (structure_score * 0.2)
        
        return min(1.0, confidence)
    
    def _calculate_improvement_confidence(self, original: str, improved: str, examples: List[str]) -> float:
        """Calculate confidence score for improvement"""
        if not examples:
            return 0.5
        
        # Calculate how much the improvement aligns with good examples
        example_alignment = 0
        for example in examples:
            similarity = self._calculate_text_similarity(improved, example)
            example_alignment += similarity
        
        average_alignment = example_alignment / len(examples)
        
        # Check if improvement actually adds value
        improvement_ratio = len(improved) / max(1, len(original))
        length_improvement = min(1.0, improvement_ratio / 2.0)  # Prefer reasonable expansion
        
        confidence = (average_alignment * 0.7) + (length_improvement * 0.3)
        
        return min(1.0, confidence)
    
    def _calculate_clause_confidence(self, corrected: str, template: str) -> float:
        """Calculate confidence score for clause correction"""
        similarity = self._calculate_text_similarity(corrected, template)
        
        # Check for standard clause elements
        standard_elements = 0
        if 'shall' in corrected.lower():
            standard_elements += 0.2
        if 'party' in corrected.lower():
            standard_elements += 0.2
        if len(corrected.split()) > 30:  # Substantial clause
            standard_elements += 0.3
        if corrected.count('.') >= 2:  # Multiple sentences
            standard_elements += 0.3
        
        confidence = (similarity * 0.6) + standard_elements
        
        return min(1.0, confidence)
    
    def _calculate_text_similarity(self, text1: str, text2: str) -> float:
        """Calculate similarity between two texts"""
        if not self.embedder:
            # Fallback to simple word overlap
            words1 = set(text1.lower().split())
            words2 = set(text2.lower().split())
            
            if not words1 or not words2:
                return 0.0
            
            intersection = words1.intersection(words2)
            union = words1.union(words2)
            
            return len(intersection) / len(union)
        
        try:
            # Use embeddings for better similarity
            embeddings = self.embedder.embed([text1, text2])
            
            # Calculate cosine similarity
            vec1, vec2 = embeddings[0], embeddings[1]
            
            dot_product = np.dot(vec1, vec2)
            norm1 = np.linalg.norm(vec1)
            norm2 = np.linalg.norm(vec2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            similarity = dot_product / (norm1 * norm2)
            return max(0.0, similarity)  # Ensure non-negative
            
        except Exception as e:
            self.logger.warning(f"Embedding similarity calculation failed: {str(e)}")
            # Fallback to word overlap
            words1 = set(text1.lower().split())
            words2 = set(text2.lower().split())
            
            if not words1 or not words2:
                return 0.0
            
            intersection = words1.intersection(words2)
            union = words1.union(words2)
            
            return len(intersection) / len(union)
    
    def _fallback_section_generation(self, section_name: str, proposal_text: str) -> Dict[str, Any]:
        """Fallback generation when embeddings are not available"""
        basic_content = self._create_basic_section(section_name, proposal_text)
        
        return {
            'success': True,
            'generated_text': basic_content,
            'reasoning': f"Generated {section_name} section using standard template (embeddings unavailable)",
            'confidence': 0.6
        }
    
    def _fallback_area_improvement(self, area_name: str, proposal_text: str) -> Dict[str, Any]:
        """Fallback improvement when embeddings are not available"""
        current_content = self._extract_area_content(area_name, proposal_text)
        
        # Basic improvement suggestions
        improvements = {
            'weak_bios': f"{current_content}\n\nOur team consists of experienced professionals with proven track records in delivering successful projects. Each team member brings specialized expertise and commitment to quality.",
            'weak_timeline': f"{current_content}\n\nThe project timeline includes key milestones and deliverables with regular progress reviews to ensure on-time completion.",
            'weak_budget': f"{current_content}\n\nThe budget is structured to provide transparency and value, with clear breakdown of costs and deliverables.",
            'weak_scope': f"{current_content}\n\nThe scope is clearly defined with specific deliverables, timelines, and acceptance criteria to ensure project success.",
            'weak_deliverables': f"{current_content}\n\nDeliverables are clearly specified with measurable outcomes and quality standards to meet your requirements."
        }
        
        improved_content = improvements.get(area_name.lower(), current_content + "\n\nThis section has been enhanced with additional detail and clarity.")
        
        return {
            'success': True,
            'generated_text': improved_content,
            'reasoning': f"Improved {area_name} using standard best practices (embeddings unavailable)",
            'confidence': 0.5
        }
    
    def _fallback_clause_correction(self, clause_name: str, proposal_text: str, template_clause: str = None) -> Dict[str, Any]:
        """Fallback clause correction when embeddings are not available"""
        current_clause = self._extract_clause_content(clause_name, proposal_text)
        
        # Standard clause templates
        standard_clauses = {
            'ip_clause': "All work product developed under this agreement shall become the exclusive property of the client upon full payment. Each party retains rights to their pre-existing intellectual property.",
            'payment_terms': "Payments shall be made within 30 days of invoice date. Late payments shall incur interest at 1.5% per month. All payments are non-refundable.",
            'termination': "Either party may terminate this agreement with 30 days written notice. Client shall pay for all work completed up to termination date.",
            'liability': "Liability shall be limited to the total contract value. Neither party shall be liable for consequential damages.",
            'confidentiality': "Both parties shall maintain confidentiality of all proprietary information shared during the course of this agreement.",
            'warranty': "All work shall be performed in a professional manner and conform to industry standards. Warranty period is 90 days from delivery."
        }
        
        corrected_clause = template_clause or standard_clauses.get(clause_name.lower(), current_clause)
        
        return {
            'success': True,
            'generated_text': corrected_clause,
            'reasoning': f"Corrected {clause_name} clause using standard template (embeddings unavailable)",
            'confidence': 0.6
        }
