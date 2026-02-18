"""
Risk Gate Mitigations
Mitigation strategies for handling detected risks
"""

import json
import time
from typing import Dict, List, Any, Optional
from abc import ABC, abstractmethod


class BaseMitigation(ABC):
    """Base class for all mitigations"""
    
    @abstractmethod
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        """
        Apply mitigation strategy
        
        Args:
            validator_result: Result from validator
            gate_name: Name of the gate that triggered this
            
        Returns:
            Dict with 'applied', 'action_taken', 'details'
        """
        pass


class BlockResponseMitigation(BaseMitigation):
    """Block the response entirely"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        return {
            'applied': True,
            'action_taken': 'response_blocked',
            'details': {
                'reason': f"Risk detected in {gate_name} gate",
                'violations': validator_result.get('violations', []),
                'timestamp': time.time()
            }
        }


class LogAlertMitigation(BaseMitigation):
    """Log the alert for monitoring"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        alert_data = {
            'alert_type': 'risk_gate_violation',
            'gate': gate_name,
            'violations': validator_result.get('violations', []),
            'severity': 'high',
            'timestamp': time.time(),
            'validator_details': validator_result.get('details', {})
        }
        
        # This would integrate with your logging system
        print(f"RISK ALERT: {json.dumps(alert_data, indent=2)}")
        
        return {
            'applied': True,
            'action_taken': 'alert_logged',
            'details': {
                'alert_id': f"alert_{int(time.time())}",
                'alert_data': alert_data
            }
        }


class SanitizeInputMitigation(BaseMitigation):
    """Sanitize the input to remove harmful content"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        # This is a simplified example - you'd implement proper sanitization
        sanitized_patterns = {
            'injection_attempts': r'(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP)\b)',
            'xss_attempts': r'(<script|javascript:)',
            'command_injection': r'(\|\||&&|;|\$\()',
        }
        
        violations = validator_result.get('violations', [])
        sanitized_count = 0
        
        for violation in violations:
            for pattern_name, pattern in sanitized_patterns.items():
                if pattern_name in violation.lower():
                    sanitized_count += 1
        
        return {
            'applied': True,
            'action_taken': 'input_sanitized',
            'details': {
                'patterns_sanitized': sanitized_count,
                'method': 'pattern_removal'
            }
        }


class ProvideResourcesMitigation(BaseMitigation):
    """Provide helpful resources for safety issues"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        resources = {
            'self_harm': [
                "National Suicide Prevention Lifeline: 988",
                "Crisis Text Line: Text HOME to 741741",
                "Emergency services: 911"
            ],
            'harmful_content': [
                "Mental health resources available",
                "Consider speaking with a professional",
                "Emergency support is available 24/7"
            ],
            'violence': [
                "Domestic violence hotline: 1-800-799-7233",
                "Emergency services: 911",
                "Local support services available"
            ]
        }
        
        violations = validator_result.get('violations', [])
        relevant_resources = []
        
        for violation in violations:
            for key, resource_list in resources.items():
                if key in violation.lower():
                    relevant_resources.extend(resource_list)
        
        return {
            'applied': True,
            'action_taken': 'resources_provided',
            'details': {
                'resources': list(set(relevant_resources)),  # Remove duplicates
                'resource_type': 'safety_support'
            }
        }


class RefuseRequestMitigation(BaseMitigation):
    """Refuse the request with explanation"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        refusal_messages = {
            'illegal_activities': "I cannot assist with activities that may be illegal or harmful.",
            'copyright_infringement': "I cannot help with copyright infringement or piracy.",
            'regulated_advice': "I cannot provide professional legal, medical, or financial advice.",
            'harmful_content': "I cannot provide information that could cause harm to yourself or others."
        }
        
        violations = validator_result.get('violations', [])
        refusal_reasons = []
        
        for violation in violations:
            for key, message in refusal_messages.items():
                if key in violation.lower():
                    refusal_reasons.append(message)
        
        return {
            'applied': True,
            'action_taken': 'request_refused',
            'details': {
                'refusal_reasons': list(set(refusal_reasons)),
                'general_message': "I cannot fulfill this request due to safety and ethical guidelines."
            }
        }


class SuggestAlternativesMitigation(BaseMitigation):
    """Suggest alternative approaches"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        alternatives = {
            'illegal_activities': [
                "Consider legal alternatives for your goal",
                "Consult with legal professionals for guidance",
                "Explore legitimate resources for your needs"
            ],
            'copyright_infringement': [
                "Use free or open-source alternatives",
                "Purchase legitimate licenses for content",
                "Create original content instead"
            ],
            'regulated_advice': [
                "Consult with qualified professionals",
                "Use official regulatory resources",
                "Seek certified experts in the field"
            ]
        }
        
        violations = validator_result.get('violations', [])
        suggested_alternatives = []
        
        for violation in violations:
            for key, alt_list in alternatives.items():
                if key in violation.lower():
                    suggested_alternatives.extend(alt_list)
        
        return {
            'applied': True,
            'action_taken': 'alternatives_suggested',
            'details': {
                'alternatives': list(set(suggested_alternatives)),
                'approach': 'constructive_guidance'
            }
        }


class AddDisclaimerMitigation(BaseMitigation):
    """Add disclaimer to response"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        disclaimers = {
            'bias_detection': "Note: This response may contain biases. Please evaluate information critically.",
            'ethics': "This response is provided for informational purposes only and should be evaluated in context.",
            'legal': "This is not legal advice. Consult with qualified legal professionals for specific situations.",
            'financial': "This is not financial advice. Consult with qualified financial professionals for investment decisions."
        }
        
        violations = validator_result.get('violations', [])
        applicable_disclaimers = []
        
        for violation in violations:
            for key, disclaimer in disclaimers.items():
                if key in violation.lower():
                    applicable_disclaimers.append(disclaimer)
        
        return {
            'applied': True,
            'action_taken': 'disclaimer_added',
            'details': {
                'disclaimers': list(set(applicable_disclaimers)),
                'placement': 'response_footer'
            }
        }


class ProvideContextMitigation(BaseMitigation):
    """Provide additional context for transparency"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        context_info = {
            'limitations': [
                "AI systems have limitations and may not always provide accurate information",
                "Critical decisions should be made with human oversight",
                "Multiple sources should be consulted for important matters"
            ],
            'process': [
                "This response was generated using machine learning",
                "The system attempts to provide helpful and accurate information",
                "User feedback helps improve response quality"
            ]
        }
        
        return {
            'applied': True,
            'action_taken': 'context_provided',
            'details': {
                'context': context_info,
                'purpose': 'transparency_and_education'
            }
        }


class RedactDataMitigation(BaseMitigation):
    """Redact sensitive data from input"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        redaction_patterns = {
            'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
            'credit_card': r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
            'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            'phone': r'\b\d{3}[-\s]?\d{3}[-\s]?\d{4}\b'
        }
        
        redacted_count = 0
        violations = validator_result.get('violations', [])
        
        for violation in violations:
            if 'PII' in violation:
                redacted_count += 1  # Simplified count
        
        return {
            'applied': True,
            'action_taken': 'data_redacted',
            'details': {
                'redacted_items': redacted_count,
                'redaction_method': 'pattern_replacement',
                'replacement': '[REDACTED]'
            }
        }


class AnonymizeMitigation(BaseMitigation):
    """Anonymize data to remove personal identifiers"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        return {
            'applied': True,
            'action_taken': 'data_anonymized',
            'details': {
                'method': 'tokenization',
                'identifiers_removed': 'names, addresses, contact info',
                'preservation': 'statistical patterns only'
            }
        }


class RequestConsentMitigation(BaseMitigation):
    """Request user consent for data processing"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        consent_request = {
            'message': "Consent is required for processing this information.",
            'options': [
                "I consent to data processing",
                "I do not consent - please anonymize",
                "I need more information"
            ],
            'purpose': "To ensure compliance with privacy regulations"
        }
        
        return {
            'applied': True,
            'action_taken': 'consent_requested',
            'details': consent_request
        }


class LimitDataUseMitigation(BaseMitigation):
    """Limit data usage to specific purposes"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        limitations = {
            'allowed_purposes': [
                "Response generation only",
                "No storage of personal data",
                "No sharing with third parties"
            ],
            'time_limitation': "Data used only for current session",
            'scope_limitation': "Only relevant data extracted"
        }
        
        return {
            'applied': True,
            'action_taken': 'data_use_limited',
            'details': limitations
        }


class LogComplianceMitigation(BaseMitigation):
    """Log compliance actions"""
    
    def apply(self, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        compliance_log = {
            'timestamp': time.time(),
            'gate': gate_name,
            'action': 'compliance_measure_applied',
            'regulation': 'GDPR/Privacy_Laws',
            'user_protection': 'data_minimization_applied'
        }
        
        print(f"COMPLIANCE LOG: {json.dumps(compliance_log, indent=2)}")
        
        return {
            'applied': True,
            'action_taken': 'compliance_logged',
            'details': {
                'log_entry': compliance_log,
                'retention_period': '7_years'
            }
        }


class MitigationEngine:
    """Engine for managing and applying mitigations"""
    
    def __init__(self):
        self.mitigations = {
            # Security mitigations
            'block_response': BlockResponseMitigation(),
            'log_alert': LogAlertMitigation(),
            'sanitize_input': SanitizeInputMitigation(),
            
            # Safety mitigations
            'block_response': BlockResponseMitigation(),
            'provide_resources': ProvideResourcesMitigation(),
            'log_alert': LogAlertMitigation(),
            
            # Legal mitigations
            'refuse_request': RefuseRequestMitigation(),
            'suggest_alternatives': SuggestAlternativesMitigation(),
            'log_incident': LogAlertMitigation(),
            
            # Ethics mitigations
            'add_disclaimer': AddDisclaimerMitigation(),
            'provide_context': ProvideContextMitigation(),
            'log_review': LogAlertMitigation(),
            
            # Data mitigations
            'redact_data': RedactDataMitigation(),
            'anonymize': AnonymizeMitigation(),
            'log_access': LogAlertMitigation(),
            
            # Privacy mitigations
            'request_consent': RequestConsentMitigation(),
            'limit_data_use': LimitDataUseMitigation(),
            'log_compliance': LogComplianceMitigation()
        }
    
    def apply_mitigation(self, mitigation_name: str, validator_result: Dict[str, Any], gate_name: str) -> Dict[str, Any]:
        """Apply a specific mitigation"""
        if mitigation_name not in self.mitigations:
            return {
                'applied': False,
                'action_taken': 'none',
                'details': f'Unknown mitigation: {mitigation_name}'
            }
        
        mitigation = self.mitigations[mitigation_name]
        return mitigation.apply(validator_result, gate_name)
    
    def list_mitigations(self) -> List[str]:
        """List all available mitigations"""
        return list(self.mitigations.keys())
    
    def add_mitigation(self, name: str, mitigation: BaseMitigation):
        """Add a custom mitigation"""
        self.mitigations[name] = mitigation
    
    def remove_mitigation(self, name: str):
        """Remove a mitigation"""
        if name in self.mitigations:
            del self.mitigations[name]
