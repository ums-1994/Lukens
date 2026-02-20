"""
AI Writer Global Summary Helper
Generates comprehensive fixes for compound risk scenarios
"""

from typing import List, Dict, Any, Optional
import logging

from ..ai_writer import AIWriter


class AIWriterGlobalHelper:
    """Helper class for AI Writer global operations"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.ai_writer = AIWriter()
    
    def write_global_summary(self, issues: List[Dict[str, Any]], proposal_text: str) -> Dict[str, Any]:
        """
        Generate a comprehensive global fix for all identified issues
        
        Args:
            issues: List of identified issues
            proposal_text: Current proposal text
            
        Returns:
            Global summary and fixes
        """
        try:
            # Categorize issues by type
            categorized_issues = self._categorize_issues(issues)
            
            # Generate fixes for each category
            fixes = {}
            
            # Fix missing sections
            if 'missing_sections' in categorized_issues:
                fixes['missing_sections'] = self._fix_missing_sections(
                    categorized_issues['missing_sections'], proposal_text
                )
            
            # Fix weak areas
            if 'weak_areas' in categorized_issues:
                fixes['weak_areas'] = self._fix_weak_areas(
                    categorized_issues['weak_areas'], proposal_text
                )
            
            # Fix incorrect clauses
            if 'incorrect_clauses' in categorized_issues:
                fixes['incorrect_clauses'] = self._fix_incorrect_clauses(
                    categorized_issues['incorrect_clauses'], proposal_text
                )
            
            # Generate overall summary
            global_summary = self._generate_global_summary(fixes, issues)
            
            # Create action plan
            action_plan = self._create_action_plan(fixes, issues)
            
            return {
                'success': True,
                'global_summary': global_summary,
                'fixes': fixes,
                'action_plan': action_plan,
                'total_issues_fixed': len(issues),
                'confidence': self._calculate_overall_confidence(fixes)
            }
            
        except Exception as e:
            self.logger.error(f"Error generating global summary: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'global_summary': '',
                'fixes': {},
                'action_plan': '',
                'total_issues_fixed': 0,
                'confidence': 0.0
            }
    
    def _categorize_issues(self, issues: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
        """Categorize issues by type for targeted fixes"""
        categorized = {
            'missing_sections': [],
            'weak_areas': [],
            'incorrect_clauses': [],
            'other': []
        }
        
        for issue in issues:
            issue_type = issue.get('type', '').lower()
            theme = issue.get('theme', '').lower()
            
            if 'structural' in issue_type or 'missing' in theme:
                categorized['missing_sections'].append(issue)
            elif 'weakness' in issue_type or 'weak' in theme:
                categorized['weak_areas'].append(issue)
            elif 'clause' in issue_type or 'legal' in theme:
                categorized['incorrect_clauses'].append(issue)
            else:
                categorized['other'].append(issue)
        
        return categorized
    
    def _fix_missing_sections(self, missing_sections: List[Dict[str, Any]], proposal_text: str) -> List[Dict[str, Any]]:
        """Generate fixes for missing sections"""
        fixes = []
        
        for issue in missing_sections:
            section_name = self._extract_section_name(issue)
            
            if section_name:
                result = self.ai_writer.generate_missing_section(
                    section_name=section_name,
                    proposal_text=proposal_text
                )
                
                if result['success']:
                    fixes.append({
                        'issue': issue,
                        'section_name': section_name,
                        'generated_content': result['generated_text'],
                        'confidence': result['confidence'],
                        'reasoning': result['reasoning']
                    })
        
        return fixes
    
    def _fix_weak_areas(self, weak_areas: List[Dict[str, Any]], proposal_text: str) -> List[Dict[str, Any]]:
        """Generate fixes for weak areas"""
        fixes = []
        
        for issue in weak_areas:
            area_name = self._extract_area_name(issue)
            
            if area_name:
                result = self.ai_writer.improve_weak_area(
                    area_name=area_name,
                    proposal_text=proposal_text
                )
                
                if result['success']:
                    fixes.append({
                        'issue': issue,
                        'area_name': area_name,
                        'improved_content': result['generated_text'],
                        'confidence': result['confidence'],
                        'reasoning': result['reasoning']
                    })
        
        return fixes
    
    def _fix_incorrect_clauses(self, incorrect_clauses: List[Dict[str, Any]], proposal_text: str) -> List[Dict[str, Any]]:
        """Generate fixes for incorrect clauses"""
        fixes = []
        
        for issue in incorrect_clauses:
            clause_name = self._extract_clause_name(issue)
            
            if clause_name:
                result = self.ai_writer.correct_clause(
                    clause_name=clause_name,
                    proposal_text=proposal_text
                )
                
                if result['success']:
                    fixes.append({
                        'issue': issue,
                        'clause_name': clause_name,
                        'corrected_content': result['generated_text'],
                        'confidence': result['confidence'],
                        'reasoning': result['reasoning']
                    })
        
        return fixes
    
    def _extract_section_name(self, issue: Dict[str, Any]) -> Optional[str]:
        """Extract section name from issue"""
        description = issue.get('description', '').lower()
        
        # Common section mappings
        section_mappings = {
            'executive summary': 'executive_summary',
            'scope': 'scope',
            'deliverables': 'deliverables',
            'timeline': 'timeline',
            'budget': 'budget',
            'team': 'team',
            'assumptions': 'assumptions'
        }
        
        for key, section in section_mappings.items():
            if key in description:
                return section
        
        return None
    
    def _extract_area_name(self, issue: Dict[str, Any]) -> Optional[str]:
        """Extract area name from issue"""
        description = issue.get('description', '').lower()
        
        # Common area mappings
        area_mappings = {
            'timeline': 'weak_timeline',
            'schedule': 'weak_timeline',
            'budget': 'weak_budget',
            'cost': 'weak_budget',
            'team': 'weak_bios',
            'bio': 'weak_bios',
            'scope': 'weak_scope',
            'deliverable': 'weak_deliverables'
        }
        
        for key, area in area_mappings.items():
            if key in description:
                return area
        
        return None
    
    def _extract_clause_name(self, issue: Dict[str, Any]) -> Optional[str]:
        """Extract clause name from issue"""
        description = issue.get('description', '').lower()
        
        # Common clause mappings
        clause_mappings = {
            'intellectual property': 'ip_clause',
            'payment': 'payment_terms',
            'termination': 'termination',
            'liability': 'liability',
            'confidential': 'confidentiality',
            'warranty': 'warranty'
        }
        
        for key, clause in clause_mappings.items():
            if key in description:
                return clause
        
        return None
    
    def _generate_global_summary(self, fixes: Dict[str, List[Dict[str, Any]]], issues: List[Dict[str, Any]]) -> str:
        """Generate a comprehensive global summary"""
        summary_parts = []
        
        # Total fixes
        total_fixes = sum(len(fix_list) for fix_list in fixes.values())
        summary_parts.append(f"Generated {total_fixes} automated fixes for {len(issues)} identified issues.")
        
        # Fix breakdown
        fix_types = []
        for fix_type, fix_list in fixes.items():
            if fix_list:
                if fix_type == 'missing_sections':
                    fix_types.append(f"{len(fix_list)} missing sections")
                elif fix_type == 'weak_areas':
                    fix_types.append(f"{len(fix_list)} weak areas")
                elif fix_type == 'incorrect_clauses':
                    fix_types.append(f"{len(fix_list)} incorrect clauses")
        
        if fix_types:
            summary_parts.append(f"Fixes include: {', '.join(fix_types)}.")
        
        # Quality improvement
        summary_parts.append("All generated content uses local templates and maintains professional standards.")
        
        return " ".join(summary_parts)
    
    def _create_action_plan(self, fixes: Dict[str, List[Dict[str, Any]]], issues: List[Dict[str, Any]]) -> str:
        """Create an action plan for implementing fixes"""
        action_steps = []
        
        step_number = 1
        
        # Missing sections
        if fixes.get('missing_sections'):
            action_steps.append(f"{step_number}. Add missing sections: {', '.join([fix['section_name'] for fix in fixes['missing_sections']])}")
            step_number += 1
        
        # Weak areas
        if fixes.get('weak_areas'):
            action_steps.append(f"{step_number}. Improve weak areas: {', '.join([fix['area_name'] for fix in fixes['weak_areas']])}")
            step_number += 1
        
        # Incorrect clauses
        if fixes.get('incorrect_clauses'):
            action_steps.append(f"{step_number}. Correct clauses: {', '.join([fix['clause_name'] for fix in fixes['incorrect_clauses']])}")
            step_number += 1
        
        # Review step
        action_steps.append(f"{step_number}. Review all generated content for accuracy and completeness")
        step_number += 1
        
        # Final step
        action_steps.append(f"{step_number}. Re-run risk assessment to verify all issues are resolved")
        
        return " | ".join(action_steps)
    
    def _calculate_overall_confidence(self, fixes: Dict[str, List[Dict[str, Any]]]) -> float:
        """Calculate overall confidence for all fixes"""
        if not fixes:
            return 0.0
        
        total_confidence = 0.0
        total_fixes = 0
        
        for fix_list in fixes.values():
            for fix in fix_list:
                total_confidence += fix.get('confidence', 0.0)
                total_fixes += 1
        
        if total_fixes == 0:
            return 0.0
        
        return total_confidence / total_fixes
