"""
Risk Gate Logger
Centralized logging for all risk gate events
"""

import json
import time
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime
from pathlib import Path


class RiskLogger:
    """Enhanced logger for risk gate events"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.log_level = config.get('log_level', 'INFO')
        self.notification_channels = config.get('notification_channels', ['console'])
        
        # Setup logging
        self.logger = self._setup_logger()
        
        # Log file path
        self.log_file = Path("risk_gate_logs.json")
        self.log_file.parent.mkdir(exist_ok=True)
    
    def _setup_logger(self) -> logging.Logger:
        """Setup Python logger with appropriate configuration"""
        logger = logging.getLogger('risk_gate')
        logger.setLevel(getattr(logging, self.log_level))
        
        # Clear existing handlers
        logger.handlers.clear()
        
        # Console handler
        if 'console' in self.notification_channels:
            console_handler = logging.StreamHandler()
            console_handler.setLevel(getattr(logging, self.log_level))
            
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            console_handler.setFormatter(formatter)
            logger.addHandler(console_handler)
        
        # File handler
        if 'file' in self.notification_channels:
            file_handler = logging.FileHandler('risk_gate.log')
            file_handler.setLevel(getattr(logging, self.log_level))
            
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        
        return logger
    
    def log_event(self, event_type: str, data: Dict[str, Any], severity: str = 'INFO'):
        """Log a risk gate event"""
        timestamp = datetime.now().isoformat()
        
        log_entry = {
            'timestamp': timestamp,
            'event_type': event_type,
            'severity': severity,
            'data': data,
            'unix_timestamp': time.time()
        }
        
        # Log to Python logger
        log_message = f"{event_type}: {json.dumps(data, indent=2)}"
        
        if severity == 'CRITICAL':
            self.logger.critical(log_message)
        elif severity == 'ERROR':
            self.logger.error(log_message)
        elif severity == 'WARNING':
            self.logger.warning(log_message)
        elif severity == 'DEBUG':
            self.logger.debug(log_message)
        else:
            self.logger.info(log_message)
        
        # Log to JSON file for structured analysis
        self._log_to_file(log_entry)
        
        # Send webhook notification if configured
        if 'webhook' in self.notification_channels:
            self._send_webhook_notification(log_entry)
    
    def _log_to_file(self, log_entry: Dict[str, Any]):
        """Log entry to JSON file"""
        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            self.logger.error(f"Failed to write to log file: {e}")
    
    def _send_webhook_notification(self, log_entry: Dict[str, Any]):
        """Send webhook notification for critical events"""
        # This is a placeholder - implement actual webhook logic
        if log_entry['severity'] in ['CRITICAL', 'ERROR']:
            webhook_url = self.config.get('webhook_url')
            if webhook_url:
                # TODO: Implement actual webhook sending
                self.logger.info(f"Webhook notification sent for {log_entry['event_type']}")
    
    def log_gate_start(self, gate_name: str, input_text: str, metadata: Dict[str, Any]):
        """Log when a gate starts processing"""
        self.log_event(f"gate_start_{gate_name}", {
            'gate_name': gate_name,
            'input_length': len(input_text),
            'input_preview': input_text[:100] + "..." if len(input_text) > 100 else input_text,
            'metadata': metadata
        })
    
    def log_gate_complete(self, gate_name: str, result: Dict[str, Any], execution_time: float):
        """Log when a gate completes processing"""
        self.log_event(f"gate_complete_{gate_name}", {
            'gate_name': gate_name,
            'result': result,
            'execution_time': execution_time
        })
    
    def log_violation(self, gate_name: str, validator_name: str, violations: List[str]):
        """Log when violations are detected"""
        self.log_event("violation_detected", {
            'gate_name': gate_name,
            'validator': validator_name,
            'violations': violations,
            'violation_count': len(violations)
        }, severity='WARNING')
    
    def log_mitigation_applied(self, gate_name: str, mitigation_name: str, result: Dict[str, Any]):
        """Log when a mitigation is applied"""
        self.log_event("mitigation_applied", {
            'gate_name': gate_name,
            'mitigation': mitigation_name,
            'result': result
        })
    
    def log_critical_event(self, event_type: str, data: Dict[str, Any]):
        """Log critical events that require immediate attention"""
        self.log_event(event_type, data, severity='CRITICAL')
    
    def log_error(self, event_type: str, error: Exception, context: Dict[str, Any] = None):
        """Log errors with context"""
        self.log_event(f"error_{event_type}", {
            'error_type': type(error).__name__,
            'error_message': str(error),
            'context': context or {},
            'stack_trace': str(error.__traceback__) if error.__traceback__ else None
        }, severity='ERROR')
    
    def get_recent_logs(self, count: int = 100) -> List[Dict[str, Any]]:
        """Get recent log entries"""
        try:
            logs = []
            with open(self.log_file, 'r') as f:
                lines = f.readlines()
                for line in lines[-count:]:
                    if line.strip():
                        logs.append(json.loads(line.strip()))
            return logs
        except FileNotFoundError:
            return []
        except Exception as e:
            self.logger.error(f"Failed to read log file: {e}")
            return []
    
    def get_logs_by_event_type(self, event_type: str, count: int = 50) -> List[Dict[str, Any]]:
        """Get logs filtered by event type"""
        all_logs = self.get_recent_logs(1000)  # Get more logs to filter
        filtered_logs = [
            log for log in all_logs 
            if log.get('event_type') == event_type
        ]
        return filtered_logs[-count:] if len(filtered_logs) > count else filtered_logs
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get logging statistics"""
        try:
            logs = self.get_recent_logs(1000)
            
            stats = {
                'total_logs': len(logs),
                'event_types': {},
                'severity_distribution': {},
                'recent_activity': []
            }
            
            for log in logs:
                # Count event types
                event_type = log.get('event_type', 'unknown')
                stats['event_types'][event_type] = stats['event_types'].get(event_type, 0) + 1
                
                # Count severity levels
                severity = log.get('severity', 'INFO')
                stats['severity_distribution'][severity] = stats['severity_distribution'].get(severity, 0) + 1
            
            # Get recent activity (last 10 events)
            stats['recent_activity'] = logs[-10:] if len(logs) >= 10 else logs
            
            return stats
            
        except Exception as e:
            self.logger.error(f"Failed to generate statistics: {e}")
            return {'error': str(e)}
    
    def export_logs(self, start_time: Optional[float] = None, end_time: Optional[float] = None) -> str:
        """Export logs in JSON format with optional time range"""
        try:
            logs = self.get_recent_logs(10000)  # Get all recent logs
            
            # Filter by time range if specified
            if start_time or end_time:
                filtered_logs = []
                for log in logs:
                    log_time = log.get('unix_timestamp', 0)
                    if start_time and log_time < start_time:
                        continue
                    if end_time and log_time > end_time:
                        continue
                    filtered_logs.append(log)
                logs = filtered_logs
            
            export_data = {
                'export_timestamp': datetime.now().isoformat(),
                'total_logs': len(logs),
                'time_range': {
                    'start': start_time,
                    'end': end_time
                },
                'logs': logs
            }
            
            return json.dumps(export_data, indent=2)
            
        except Exception as e:
            self.logger.error(f"Failed to export logs: {e}")
            return json.dumps({'error': str(e)})
    
    def clear_logs(self, older_than_days: int = 30):
        """Clear old logs to manage file size"""
        try:
            cutoff_time = time.time() - (older_than_days * 24 * 60 * 60)
            
            # Read current logs
            logs = self.get_recent_logs(10000)
            
            # Filter out old logs
            current_logs = [
                log for log in logs 
                if log.get('unix_timestamp', 0) >= cutoff_time
            ]
            
            # Write back filtered logs
            with open(self.log_file, 'w') as f:
                for log in current_logs:
                    f.write(json.dumps(log) + '\n')
            
            removed_count = len(logs) - len(current_logs)
            self.logger.info(f"Cleared {removed_count} old log entries")
            
        except Exception as e:
            self.logger.error(f"Failed to clear logs: {e}")


# Convenience functions for easy access
def get_risk_logger(config: Dict[str, Any] = None) -> RiskLogger:
    """Get or create risk logger instance"""
    if config is None:
        config = {
            'log_level': 'INFO',
            'notification_channels': ['console', 'file']
        }
    return RiskLogger(config)

def log_risk_event(event_type: str, data: Dict[str, Any], severity: str = 'INFO'):
    """Convenience function to log risk events"""
    logger = get_risk_logger()
    logger.log_event(event_type, data, severity)
