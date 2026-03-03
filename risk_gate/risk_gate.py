"""
Risk Gate System - Main Controller
Runs pre-response checks across multiple risk domains
"""

import yaml
import time
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass

from .validators import ValidatorRegistry
from .mitigations import MitigationEngine
from .logger import RiskLogger


@dataclass
class RiskResult:
    gate: str
    risk_score: float
    passed: bool
    violations: List[str]
    mitigations_applied: List[str]
    execution_time: float


@dataclass
class GateResult:
    overall_passed: bool
    risk_score: float
    gate_results: List[RiskResult]
    total_execution_time: float
    blocked: bool


class RiskGate:
    def __init__(self, config_path: str = "risk_gate/risk_config.yaml"):
        """Initialize Risk Gate with configuration"""
        self.config = self._load_config(config_path)
        self.validator_registry = ValidatorRegistry()
        self.mitigation_engine = MitigationEngine()
        self.logger = RiskLogger(self.config.get('global_settings', {}))
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            raise FileNotFoundError(f"Risk gate config not found: {config_path}")
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML config: {e}")
    
    def run_risk_gate(self, input_text: str, metadata: Dict[str, Any] = None) -> GateResult:
        """
        Main entry point - Run all enabled risk gates on input
        
        Args:
            input_text: The input text to validate
            metadata: Additional context information
            
        Returns:
            GateResult with overall assessment and details
        """
        start_time = time.time()
        metadata = metadata or {}
        
        self.logger.log_event("risk_gate_started", {
            "input_length": len(input_text),
            "metadata": metadata
        })
        
        gate_results = []
        overall_risk_score = 0.0
        gates_executed = 0
        
        # Run each enabled gate
        for gate_name, gate_config in self.config.get('gates', {}).items():
            if not gate_config.get('enabled', False):
                continue
                
            gate_result = self._run_single_gate(gate_name, gate_config, input_text, metadata)
            gate_results.append(gate_result)
            
            if gate_result.risk_score > 0:
                overall_risk_score = max(overall_risk_score, gate_result.risk_score)
                gates_executed += 1
            
            self.logger.log_event(f"gate_completed_{gate_name}", {
                "risk_score": gate_result.risk_score,
                "passed": gate_result.passed,
                "violations": gate_result.violations
            })
        
        # Calculate overall result
        total_time = time.time() - start_time
        thresholds = self.config.get('thresholds', {})
        
        # Determine if blocked based on thresholds
        risk_threshold = thresholds.get('risk_score_threshold', 0.7)
        critical_threshold = thresholds.get('critical_risk_threshold', 0.9)
        
        blocked = False
        overall_passed = True
        
        if overall_risk_score >= critical_threshold:
            blocked = True
            overall_passed = False
        elif overall_risk_score >= risk_threshold:
            overall_passed = False
        elif any(not result.passed for result in gate_results):
            overall_passed = False
        
        result = GateResult(
            overall_passed=overall_passed,
            risk_score=overall_risk_score,
            gate_results=gate_results,
            total_execution_time=total_time,
            blocked=blocked
        )
        
        self.logger.log_event("risk_gate_completed", {
            "overall_passed": overall_passed,
            "risk_score": overall_risk_score,
            "blocked": blocked,
            "execution_time": total_time,
            "gates_executed": gates_executed
        })
        
        return result
    
    def _run_single_gate(self, gate_name: str, gate_config: Dict[str, Any], 
                        input_text: str, metadata: Dict[str, Any]) -> RiskResult:
        """Run a single risk gate"""
        start_time = time.time()
        sensitivity = gate_config.get('sensitivity', 'medium')
        validator_names = gate_config.get('validators', [])
        mitigation_names = gate_config.get('mitigations', [])
        
        violations = []
        mitigations_applied = []
        
        # Run validators
        for validator_name in validator_names:
            try:
                validator_result = self.validator_registry.validate(
                    validator_name, input_text, metadata, sensitivity
                )
                
                if not validator_result['passed']:
                    violations.extend(validator_result['violations'])
                    
                    # Apply mitigations
                    for mitigation_name in mitigation_names:
                        mitigation_result = self.mitigation_engine.apply_mitigation(
                            mitigation_name, validator_result, gate_name
                        )
                        if mitigation_result['applied']:
                            mitigations_applied.append(mitigation_name)
                            
            except Exception as e:
                self.logger.log_event("validator_error", {
                    "gate": gate_name,
                    "validator": validator_name,
                    "error": str(e)
                })
                violations.append(f"Validator error: {validator_name}")
        
        # Calculate gate risk score
        gate_risk_score = self._calculate_gate_risk_score(violations, sensitivity)
        passed = gate_risk_score < self._get_sensitivity_threshold(sensitivity)
        
        execution_time = time.time() - start_time
        
        return RiskResult(
            gate=gate_name,
            risk_score=gate_risk_score,
            passed=passed,
            violations=violations,
            mitigations_applied=mitigations_applied,
            execution_time=execution_time
        )
    
    def _calculate_gate_risk_score(self, violations: List[str], sensitivity: str) -> float:
        """Calculate risk score based on violations and sensitivity"""
        if not violations:
            return 0.0
        
        base_score = min(len(violations) * 0.2, 1.0)
        
        # Adjust based on sensitivity
        sensitivity_multipliers = {
            'low': 0.5,
            'medium': 1.0,
            'high': 1.5
        }
        
        multiplier = sensitivity_multipliers.get(sensitivity, 1.0)
        return min(base_score * multiplier, 1.0)
    
    def _get_sensitivity_threshold(self, sensitivity: str) -> float:
        """Get risk threshold based on sensitivity level"""
        thresholds = {
            'low': 0.8,
            'medium': 0.6,
            'high': 0.4
        }
        return thresholds.get(sensitivity, 0.6)
    
    def get_gate_summary(self) -> Dict[str, Any]:
        """Get summary of all available gates and their status"""
        return {
            'enabled_gates': [
                name for name, config in self.config.get('gates', {}).items()
                if config.get('enabled', False)
            ],
            'total_gates': len(self.config.get('gates', {})),
            'available_validators': self.validator_registry.list_validators(),
            'available_mitigations': self.mitigation_engine.list_mitigations(),
            'config_loaded': bool(self.config)
        }


# Global instance for easy access
_risk_gate_instance = None

def get_risk_gate() -> RiskGate:
    """Get or create global RiskGate instance"""
    global _risk_gate_instance
    if _risk_gate_instance is None:
        _risk_gate_instance = RiskGate()
    return _risk_gate_instance

def run_risk_gate(input_text: str, metadata: Dict[str, Any] = None) -> GateResult:
    """
    Convenience function - Run risk gate assessment
    
    Args:
        input_text: Text to validate
        metadata: Additional context
        
    Returns:
        GateResult with assessment details
    """
    risk_gate = get_risk_gate()
    return risk_gate.run_risk_gate(input_text, metadata)
