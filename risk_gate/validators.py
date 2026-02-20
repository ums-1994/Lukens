"""
Risk Gate Validators
Custom validation logic for different risk domains
"""

import re
import json
from typing import Dict, List, Any, Tuple
from abc import ABC, abstractmethod


class BaseValidator(ABC):
    """Base class for all validators"""
    
    @abstractmethod
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        """
        Validate input text
        
        Args:
            input_text: Text to validate
            metadata: Additional context
            sensitivity: Sensitivity level (low, medium, high)
            
        Returns:
            Dict with 'passed', 'violations', 'details'
        """
        pass


class SecurityValidator(BaseValidator):
    """Security-focused validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for injection attempts
        if self._check_injection_attempts(input_text):
            violations.append("Potential injection attack detected")
        
        # Check for malicious code patterns
        if self._check_malicious_code(input_text):
            violations.append("Suspicious code patterns detected")
        
        # Check for data exfiltration attempts
        if self._check_data_exfiltration(input_text):
            violations.append("Potential data exfiltration attempt")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'security_checks': 'completed'}
        }
    
    def _check_injection_attempts(self, text: str) -> bool:
        """Check for SQL injection, XSS, command injection patterns"""
        injection_patterns = [
            r'(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)\b)',
            r'(<script|javascript:|on\w+\s*=)',
            r'(\|\||&&|;|\$\(|\`|\\\\)',
            r'(\b(exec|eval|system)\s*\()',
            r'(\b(base64_decode|shell_exec|passthru)\s*\()'
        ]
        
        for pattern in injection_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_malicious_code(self, text: str) -> bool:
        """Check for suspicious code patterns"""
        malicious_patterns = [
            r'(\b(virus|malware|trojan|backdoor|rootkit)\b)',
            r'(\b(keylogger|spyware|ransomware)\b)',
            r'(curl.*\|.*sh|wget.*\|.*bash)',
            r'(rm\s+-rf\s+/|dd\s+if=.*of=/dev/sd)',
            r'(\b(reverse.*shell|bind.*shell)\b)'
        ]
        
        for pattern in malicious_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_data_exfiltration(self, text: str) -> bool:
        """Check for potential data exfiltration"""
        exfil_patterns = [
            r'(\b(exfiltrate|leak|dump|extract)\b.*\b(data|database|credentials)\b)',
            r'(\b(send|transmit|upload)\b.*\b(to|external|remote)\b)',
            r'(\b(ftp|sftp|scp|rsync)\s+\w+)'
        ]
        
        for pattern in exfil_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class SafetyValidator(BaseValidator):
    """Safety-focused validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for harmful content
        if self._check_harmful_content(input_text):
            violations.append("Harmful content detected")
        
        # Check for self-harm indicators
        if self._check_self_harm(input_text):
            violations.append("Self-harm indicators detected")
        
        # Check for violence
        if self._check_violence(input_text):
            violations.append("Violent content detected")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'safety_checks': 'completed'}
        }
    
    def _check_harmful_content(self, text: str) -> bool:
        """Check for harmful or dangerous instructions"""
        harmful_patterns = [
            r'(\b(how to|instructions|steps)\b.*\b(make|create|build)\b.*\b(bomb|weapon|poison)\b)',
            r'(\b(harm|kill|hurt|injure)\b.*\b(someone|person|people)\b)',
            r'(\b(dangerous|harmful|lethal|deadly)\b.*\b(substance|chemical|material)\b)'
        ]
        
        for pattern in harmful_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_self_harm(self, text: str) -> bool:
        """Check for self-harm or suicide indicators"""
        self_harm_patterns = [
            r'(\b(suicide|kill myself|end my life|self-harm)\b)',
            r'(\b(want to die|don\'t want to live|better off dead)\b)',
            r'(\b(hurt myself|harm myself|injure myself)\b)'
        ]
        
        for pattern in self_harm_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_violence(self, text: str) -> bool:
        """Check for violent content"""
        violence_patterns = [
            r'(\b(violent|violence|attack|assault)\b)',
            r'(\b(shoot|stab|beat|hit|punch)\b.*\b(someone|person)\b)',
            r'(\b(threaten|threat)\b.*\b(harm|kill|hurt)\b)'
        ]
        
        for pattern in violence_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class LegalValidator(BaseValidator):
    """Legal compliance validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for illegal activities
        if self._check_illegal_activities(input_text):
            violations.append("Illegal activity discussion detected")
        
        # Check for copyright infringement
        if self._check_copyright_infringement(input_text):
            violations.append("Copyright infringement potential")
        
        # Check for regulated advice
        if self._check_regulated_advice(input_text):
            violations.append("Regulated advice detected")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'legal_checks': 'completed'}
        }
    
    def _check_illegal_activities(self, text: str) -> bool:
        """Check for illegal activity discussions"""
        illegal_patterns = [
            r'(\b(hack|crack|break into)\b.*\b(system|account|database)\b)',
            r'(\b(steal|theft|robbery|burglary)\b)',
            r'(\b(drug|narcotic|substance)\b.*\b(deal|sell|distribute)\b)',
            r'(\b(money laundering|fraud|scam)\b)'
        ]
        
        for pattern in illegal_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_copyright_infringement(self, text: str) -> bool:
        """Check for copyright infringement requests"""
        copyright_patterns = [
            r'(\b(copyright|pirated|illegal download)\b.*\b(movie|music|software)\b)',
            r'(\b(bypass|remove|crack)\b.*\b(drm|protection|copyright)\b)',
            r'(\b(torrent|pirate bay|illegal copy)\b)'
        ]
        
        for pattern in copyright_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_regulated_advice(self, text: str) -> bool:
        """Check for regulated professional advice"""
        regulated_patterns = [
            r'(\b(medical|legal|financial)\b.*\b(advice|recommendation|guidance)\b)',
            r'(\b(diagnose|prescribe|treat)\b.*\b(condition|illness|disease)\b)',
            r'(\b(invest|trade|buy|sell)\b.*\b(stock|crypto|currency)\b)'
        ]
        
        for pattern in regulated_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class EthicsValidator(BaseValidator):
    """Ethics-focused validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for bias
        if self._check_bias(input_text):
            violations.append("Potential bias detected")
        
        # Check for fairness
        if self._check_fairness(input_text):
            violations.append("Fairness concerns detected")
        
        # Check for transparency
        if self._check_transparency(input_text):
            violations.append("Transparency issues detected")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'ethics_checks': 'completed'}
        }
    
    def _check_bias(self, text: str) -> bool:
        """Check for biased language"""
        bias_patterns = [
            r'(\b(all|every|always)\s+\w+\s+(are|is)\s+\w+)',  # Stereotyping
            r'(\b(because|since)\s+(they|he|she)\s+(are|is)\s+\w+)',  # Attribution bias
            r'(\b(obviously|clearly|naturally)\s+\w+\s+(are|is)\s+\w+)'  # Naturalizing bias
        ]
        
        for pattern in bias_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_fairness(self, text: str) -> bool:
        """Check for fairness concerns"""
        fairness_patterns = [
            r'(\b(discriminate|exclude|deny)\b.*\b(based on|due to)\b)',
            r'(\b(unfair|unjust|unequal)\s+(treatment|opportunity)\b)',
            r'(\b(prefer|favor)\s+\w+\s+(over|instead of)\s+\w+\s+(because|due to)\b)'
        ]
        
        for pattern in fairness_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_transparency(self, text: str) -> bool:
        """Check for transparency issues"""
        transparency_patterns = [
            r'(\b(hide|conceal|secret|private)\b.*\b(information|data|method)\b)',
            r'(\b(deceive|mislead|trick)\b)',
            r'(\b(don\'t tell|keep quiet|secret)\b.*\b(from|about)\b)'
        ]
        
        for pattern in transparency_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class DataValidator(BaseValidator):
    """Data protection validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for PII
        if self._check_pii(input_text):
            violations.append("PII detected")
        
        # Check for sensitive data
        if self._check_sensitive_data(input_text):
            violations.append("Sensitive data detected")
        
        # Check for data classification
        if self._check_data_classification(input_text):
            violations.append("Data classification issues detected")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'data_checks': 'completed'}
        }
    
    def _check_pii(self, text: str) -> bool:
        """Check for personally identifiable information"""
        pii_patterns = [
            r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
            r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',  # Credit card
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',  # Email
            r'\b\d{3}[-\s]?\d{3}[-\s]?\d{4}\b',  # Phone number
            r'\b\d{1,2}\s+\w+\s+\d{4}\b'  # Address pattern
        ]
        
        for pattern in pii_patterns:
            if re.search(pattern, text):
                return True
        return False
    
    def _check_sensitive_data(self, text: str) -> bool:
        """Check for sensitive data types"""
        sensitive_patterns = [
            r'\b(password|passwd|pwd)\s*[:=]\s*\S+',
            r'\b(api[_-]?key|secret[_-]?key|access[_-]?token)\s*[:=]\s*\S+',
            r'\b(medical|health|patient)\s+(record|information|data)\b',
            r'\b(financial|bank|credit)\s+(information|data|record)\b'
        ]
        
        for pattern in sensitive_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_data_classification(self, text: str) -> bool:
        """Check for data classification issues"""
        classification_patterns = [
            r'\b(confidential|secret|top secret|classified)\b',
            r'\b(internal only|proprietary|trade secret)\b',
            r'\b(restricted|limited distribution)\b'
        ]
        
        for pattern in classification_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class PrivacyValidator(BaseValidator):
    """Privacy-focused validators"""
    
    def validate(self, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        violations = []
        
        # Check for consent
        if self._check_consent(input_text):
            violations.append("Consent issues detected")
        
        # Check for data minimization
        if self._check_data_minimization(input_text):
            violations.append("Data minimization violation")
        
        # Check for purpose limitation
        if self._check_purpose_limitation(input_text):
            violations.append("Purpose limitation violation")
        
        return {
            'passed': len(violations) == 0,
            'violations': violations,
            'details': {'privacy_checks': 'completed'}
        }
    
    def _check_consent(self, text: str) -> bool:
        """Check for consent issues"""
        consent_patterns = [
            r'(\b(without|no)\s+(consent|permission|authorization)\b)',
            r'(\b(collect|use|share)\b.*\b(data|information)\b.*\b(without|no)\s+(consent|permission)\b)',
            r'(\b(ignore|disregard)\b.*\b(consent|preference)\b)'
        ]
        
        for pattern in consent_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_data_minimization(self, text: str) -> bool:
        """Check for data minimization violations"""
        minimization_patterns = [
            r'(\b(collect|gather|obtain)\b.*\b(all|every|everything)\s+(available|possible)\s+(data|information)\b)',
            r'(\b(more|additional|extra)\s+(data|information)\s+(than|then)\s+(necessary|needed)\b)',
            r'(\b(unnecessary|excessive|extra)\s+(data|information)\b)'
        ]
        
        for pattern in minimization_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False
    
    def _check_purpose_limitation(self, text: str) -> bool:
        """Check for purpose limitation violations"""
        purpose_patterns = [
            r'(\b(use|utilize|employ)\b.*\b(data|information)\b.*\b(for|to)\s+(\w+\s+){0,3}(other|different)\s+(purpose|reason)\b)',
            r'(\b(sell|share|distribute)\b.*\b(data|information)\b.*\b(to|with)\s+(\w+\s+){0,3}(third|other)\s+(party|parties)\b)',
            r'(\b(repurpose|reuse|reutilize)\b.*\b(data|information)\b)'
        ]
        
        for pattern in purpose_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True
        return False


class ValidatorRegistry:
    """Registry for all validators"""
    
    def __init__(self):
        self.validators = {
            # Security validators
            'injection_attempts': SecurityValidator(),
            'malicious_code': SecurityValidator(),
            'data_exfiltration': SecurityValidator(),
            
            # Safety validators
            'harmful_content': SafetyValidator(),
            'self_harm': SafetyValidator(),
            'violence': SafetyValidator(),
            
            # Legal validators
            'illegal_activities': LegalValidator(),
            'copyright_infringement': LegalValidator(),
            'regulated_advice': LegalValidator(),
            
            # Ethics validators
            'bias_detection': EthicsValidator(),
            'fairness_check': EthicsValidator(),
            'transparency': EthicsValidator(),
            
            # Data validators
            'pii_detection': DataValidator(),
            'sensitive_data': DataValidator(),
            'data_classification': DataValidator(),
            
            # Privacy validators
            'consent_check': PrivacyValidator(),
            'data_minimization': PrivacyValidator(),
            'purpose_limitation': PrivacyValidator()
        }
    
    def validate(self, validator_name: str, input_text: str, metadata: Dict[str, Any], sensitivity: str) -> Dict[str, Any]:
        """Run a specific validator"""
        if validator_name not in self.validators:
            raise ValueError(f"Unknown validator: {validator_name}")
        
        validator = self.validators[validator_name]
        return validator.validate(input_text, metadata, sensitivity)
    
    def list_validators(self) -> List[str]:
        """List all available validators"""
        return list(self.validators.keys())
    
    def add_validator(self, name: str, validator: BaseValidator):
        """Add a custom validator"""
        self.validators[name] = validator
    
    def remove_validator(self, name: str):
        """Remove a validator"""
        if name in self.validators:
            del self.validators[name]
