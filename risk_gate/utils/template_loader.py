"""
Template Loader Module
Loads and manages template files for comparison
"""

import os
import glob
from typing import Dict, List, Any, Optional
import logging
from pathlib import Path


class TemplateLoader:
    """Handles loading and management of template files"""
    
    def __init__(self, templates_path: str = None):
        self.logger = logging.getLogger(__name__)
        self.templates_path = templates_path or "C:/Users/User/Downloads/Lukens-AI_RiskGate/risk_gate/Templates"
        self.templates: Dict[str, Dict[str, Any]] = {}
        self._load_templates()
    
    def _load_templates(self):
        """Load all template files from the templates directory"""
        try:
            if not os.path.exists(self.templates_path):
                self.logger.error(f"Templates directory not found: {self.templates_path}")
                return
            
            # Support multiple file types
            file_patterns = ['*.txt', '*.docx', '*.pdf', '*.md']
            all_files = []
            
            for pattern in file_patterns:
                files = glob.glob(os.path.join(self.templates_path, pattern))
                all_files.extend(files)
            
            for file_path in all_files:
                template_data = self._load_single_template(file_path)
                if template_data:
                    self.templates[template_data['id']] = template_data
            
            self.logger.info(f"Loaded {len(self.templates)} templates from {self.templates_path}")
            
        except Exception as e:
            self.logger.error(f"Error loading templates: {str(e)}")
    
    def _load_single_template(self, file_path: str) -> Optional[Dict[str, Any]]:
        """Load a single template file"""
        try:
            file_name = os.path.basename(file_path)
            template_id = Path(file_name).stem
            
            # For now, handle text files. Extend for DOCX/PDF as needed
            if file_path.endswith('.txt') or file_path.endswith('.md'):
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
            elif file_path.endswith('.docx'):
                # Basic DOCX text extraction (simplified)
                try:
                    import docx
                    doc = docx.Document(file_path)
                    content = '\n'.join([para.text for para in doc.paragraphs])
                except ImportError:
                    self.logger.warning(f"python-docx not installed, skipping {file_path}")
                    return None
                except Exception as e:
                    self.logger.warning(f"Error reading DOCX file {file_path}: {str(e)}")
                    return None
            elif file_path.endswith('.pdf'):
                # Basic PDF text extraction (simplified)
                try:
                    import PyPDF2
                    with open(file_path, 'rb') as f:
                        reader = PyPDF2.PdfReader(f)
                        content = ''
                        for page in reader.pages:
                            content += page.extract_text()
                except ImportError:
                    self.logger.warning(f"PyPDF2 not installed, skipping {file_path}")
                    return None
                except Exception as e:
                    self.logger.warning(f"Error reading PDF file {file_path}: {str(e)}")
                    return None
            else:
                self.logger.warning(f"Unsupported file type: {file_path}")
                return None
            
            # Extract sections (simplified)
            sections = self._extract_sections(content)
            
            return {
                'id': template_id,
                'file_path': file_path,
                'content': content,
                'sections': sections,
                'word_count': len(content.split()),
                'file_type': os.path.splitext(file_path)[1]
            }
            
        except Exception as e:
            self.logger.error(f"Error loading template {file_path}: {str(e)}")
            return None
    
    def _extract_sections(self, content: str) -> Dict[str, str]:
        """Extract common proposal sections"""
        sections = {}
        
        # Common section headers
        section_patterns = {
            'executive_summary': r'(?i)(executive\s+summary|overview|introduction)',
            'scope': r'(?i)(scope\s+of\s+work|project\s+scope|statement\s+of\s+work)',
            'deliverables': r'(?i)(deliverables|outputs|results)',
            'timeline': r'(?i)(timeline|schedule|project\s+schedule|milestones)',
            'budget': r'(?i)(budget|cost|pricing|fees|investment)',
            'team': r'(?i)(team|personnel|staff|bios|about\s+us)',
            'assumptions': r'(?i)(assumptions|preconditions|requirements)',
            'ip_clause': r'(?i)(intellectual\s+property|ip\s+rights|ownership)',
            'payment_terms': r'(?i)(payment\s+terms|billing|invoicing)',
            'termination': r'(?i)(termination|cancellation|exit\s+clause)'
        }
        
        import re
        
        for section_name, pattern in section_patterns.items():
            matches = re.finditer(pattern, content)
            for match in matches:
                start_pos = match.start()
                # Find next section header or end of content
                remaining_content = content[start_pos:]
                next_section_match = re.search(r'(?i)(executive\s+summary|scope\s+of\s+work|deliverables|timeline|budget|team|assumptions|intellectual\s+property|payment\s+terms|termination)', remaining_content[50:])
                
                if next_section_match:
                    section_content = remaining_content[:50 + next_section_match.start()]
                else:
                    section_content = remaining_content
                
                sections[section_name] = section_content.strip()
                break
        
        return sections
    
    def get_template_by_id(self, template_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific template by ID"""
        return self.templates.get(template_id)
    
    def get_all_templates(self) -> Dict[str, Dict[str, Any]]:
        """Get all loaded templates"""
        return self.templates
    
    def get_template_sections(self, section_name: str) -> List[str]:
        """Get all content for a specific section across all templates"""
        sections = []
        for template in self.templates.values():
            if section_name in template['sections']:
                sections.append(template['sections'][section_name])
        return sections
    
    def search_templates(self, query: str) -> List[Dict[str, Any]]:
        """Search templates by content"""
        results = []
        query_lower = query.lower()
        
        for template_id, template in self.templates.items():
            if query_lower in template['content'].lower():
                results.append({
                    'template_id': template_id,
                    'file_path': template['file_path'],
                    'snippet': self._get_snippet(template['content'], query)
                })
        
        return results
    
    def _get_snippet(self, content: str, query: str, context: int = 100) -> str:
        """Get a snippet around the query match"""
        query_lower = query.lower()
        content_lower = content.lower()
        
        match_pos = content_lower.find(query_lower)
        if match_pos == -1:
            return content[:200] + "..." if len(content) > 200 else content
        
        start = max(0, match_pos - context)
        end = min(len(content), match_pos + len(query) + context)
        
        snippet = content[start:end]
        if start > 0:
            snippet = "..." + snippet
        if end < len(content):
            snippet = snippet + "..."
        
        return snippet
    
    def reload_templates(self):
        """Reload all templates"""
        self.templates.clear()
        self._load_templates()
