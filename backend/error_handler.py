"""
Comprehensive Error Handling System for Flask Backend
Integrates with Flutter frontend error handling system
"""

import uuid
import traceback
import logging
from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any, Union
from functools import wraps
from flask import jsonify, request, current_app
from werkzeug.exceptions import HTTPException
import psycopg2


class ErrorCategory(Enum):
    """Error categories for better frontend handling"""
    USER_ERROR = "user_error"          # User can fix (validation, etc.)
    SYSTEM_ERROR = "system_error"      # Temporary system issue
    AUTH_ERROR = "auth_error"          # Authentication/authorization
    RATE_LIMIT = "rate_limit"          # Too many requests
    MAINTENANCE = "maintenance"        # Planned downtime
    DATABASE_ERROR = "database_error"  # Database connectivity issues
    VALIDATION_ERROR = "validation_error"  # Input validation failures
    PERMISSION_ERROR = "permission_error"  # Access denied


class ErrorSeverity(Enum):
    """Error severity levels matching frontend ErrorSeverity"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class AppError(Exception):
    """Base application error class"""
    def __init__(
        self,
        message: str,
        user_message: Optional[str] = None,
        category: ErrorCategory = ErrorCategory.SYSTEM_ERROR,
        severity: ErrorSeverity = ErrorSeverity.MEDIUM,
        status_code: int = 500,
        field: Optional[str] = None,
        retry_after: Optional[int] = None,
        context: Optional[Dict[str, Any]] = None
    ):
        self.message = message
        self.user_message = user_message or message
        self.category = category
        self.severity = severity
        self.status_code = status_code
        self.field = field
        self.retry_after = retry_after
        self.context = context or {}
        self.trace_id = str(uuid.uuid4())
        self.timestamp = datetime.utcnow()
        super().__init__(self.message)


class ValidationError(AppError):
    """Validation error for user input"""
    def __init__(self, message: str, field: Optional[str] = None, user_message: Optional[str] = None):
        super().__init__(
            message=message,
            user_message=user_message or f"Please check the {field or 'input'} field",
            category=ErrorCategory.VALIDATION_ERROR,
            severity=ErrorSeverity.LOW,
            status_code=400,
            field=field
        )


class AuthenticationError(AppError):
    """Authentication error"""
    def __init__(self, message: str = "Authentication required", user_message: Optional[str] = None):
        super().__init__(
            message=message,
            user_message=user_message or "Please log in to continue",
            category=ErrorCategory.AUTH_ERROR,
            severity=ErrorSeverity.HIGH,
            status_code=401
        )


class PermissionError(AppError):
    """Permission/authorization error"""
    def __init__(self, message: str = "Access denied", user_message: Optional[str] = None):
        super().__init__(
            message=message,
            user_message=user_message or "You don't have permission to perform this action",
            category=ErrorCategory.PERMISSION_ERROR,
            severity=ErrorSeverity.MEDIUM,
            status_code=403
        )


class DatabaseError(AppError):
    """Database operation error"""
    def __init__(self, message: str, user_message: Optional[str] = None, retry_after: int = 30):
        super().__init__(
            message=message,
            user_message=user_message or "Service temporarily unavailable. Please try again.",
            category=ErrorCategory.DATABASE_ERROR,
            severity=ErrorSeverity.HIGH,
            status_code=503,
            retry_after=retry_after
        )


class RateLimitError(AppError):
    """Rate limiting error"""
    def __init__(self, retry_after: int = 60, user_message: Optional[str] = None):
        super().__init__(
            message=f"Rate limit exceeded. Retry after {retry_after} seconds",
            user_message=user_message or f"Too many requests. Please wait {retry_after} seconds and try again.",
            category=ErrorCategory.RATE_LIMIT,
            severity=ErrorSeverity.MEDIUM,
            status_code=429,
            retry_after=retry_after
        )


class ErrorHandler:
    """Centralized error handling for Flask application"""
    
    def __init__(self, app=None):
        self.app = app
        if app is not None:
            self.init_app(app)
    
    def init_app(self, app):
        """Initialize error handling for Flask app"""
        self.app = app
        
        # Register error handlers
        app.errorhandler(AppError)(self.handle_app_error)
        app.errorhandler(HTTPException)(self.handle_http_error)
        app.errorhandler(psycopg2.Error)(self.handle_database_error)
        app.errorhandler(Exception)(self.handle_generic_error)
        
        # Setup structured logging
        self.setup_logging()
    
    def setup_logging(self):
        """Setup structured logging for errors"""
        if not self.app.logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            self.app.logger.addHandler(handler)
            self.app.logger.setLevel(logging.INFO)
    
    def handle_app_error(self, error: AppError):
        """Handle custom application errors"""
        self.log_error(error)
        return self.create_error_response(error), error.status_code
    
    def handle_http_error(self, error: HTTPException):
        """Handle HTTP exceptions"""
        app_error = self.convert_http_error(error)
        self.log_error(app_error)
        return self.create_error_response(app_error), error.code
    
    def handle_database_error(self, error: psycopg2.Error):
        """Handle database errors"""
        app_error = DatabaseError(
            message=f"Database error: {str(error)}",
            user_message="Service temporarily unavailable. Please try again.",
        )
        self.log_error(app_error, original_error=error)
        return self.create_error_response(app_error), 503
    
    def handle_generic_error(self, error: Exception):
        """Handle unexpected errors"""
        app_error = AppError(
            message=f"Unexpected error: {str(error)}",
            user_message="An unexpected error occurred. Please try again.",
            category=ErrorCategory.SYSTEM_ERROR,
            severity=ErrorSeverity.CRITICAL,
            status_code=500
        )
        self.log_error(app_error, original_error=error)
        return self.create_error_response(app_error), 500
    
    def convert_http_error(self, http_error: HTTPException) -> AppError:
        """Convert HTTP exceptions to AppError"""
        status_code = http_error.code
        message = http_error.description or str(http_error)
        
        # Map HTTP status codes to appropriate error categories and messages
        error_mapping = {
            400: {
                'category': ErrorCategory.VALIDATION_ERROR,
                'severity': ErrorSeverity.LOW,
                'user_message': 'Invalid request. Please check your input.'
            },
            401: {
                'category': ErrorCategory.AUTH_ERROR,
                'severity': ErrorSeverity.HIGH,
                'user_message': 'Authentication required. Please log in.'
            },
            403: {
                'category': ErrorCategory.PERMISSION_ERROR,
                'severity': ErrorSeverity.MEDIUM,
                'user_message': 'Access denied. You don\'t have permission for this action.'
            },
            404: {
                'category': ErrorCategory.USER_ERROR,
                'severity': ErrorSeverity.LOW,
                'user_message': 'The requested resource was not found.'
            },
            429: {
                'category': ErrorCategory.RATE_LIMIT,
                'severity': ErrorSeverity.MEDIUM,
                'user_message': 'Too many requests. Please wait and try again.',
                'retry_after': 60
            },
            500: {
                'category': ErrorCategory.SYSTEM_ERROR,
                'severity': ErrorSeverity.CRITICAL,
                'user_message': 'Internal server error. Please try again later.'
            },
            502: {
                'category': ErrorCategory.SYSTEM_ERROR,
                'severity': ErrorSeverity.HIGH,
                'user_message': 'Service temporarily unavailable. Please try again.',
                'retry_after': 30
            },
            503: {
                'category': ErrorCategory.MAINTENANCE,
                'severity': ErrorSeverity.HIGH,
                'user_message': 'Service temporarily unavailable. Please try again later.',
                'retry_after': 60
            }
        }
        
        error_config = error_mapping.get(status_code, {
            'category': ErrorCategory.SYSTEM_ERROR,
            'severity': ErrorSeverity.MEDIUM,
            'user_message': 'An error occurred. Please try again.'
        })
        
        return AppError(
            message=message,
            user_message=error_config['user_message'],
            category=error_config['category'],
            severity=error_config['severity'],
            status_code=status_code,
            retry_after=error_config.get('retry_after')
        )
    
    def create_error_response(self, error: AppError) -> Dict[str, Any]:
        """Create standardized error response"""
        response = {
            'error': {
                'code': error.category.value.upper(),
                'message': error.message,
                'user_message': error.user_message,
                'severity': error.severity.value,
                'trace_id': error.trace_id,
                'timestamp': error.timestamp.isoformat()
            }
        }
        
        # Add optional fields
        if error.field:
            response['error']['field'] = error.field
        
        if error.retry_after:
            response['error']['retry_after'] = error.retry_after
        
        if error.context:
            response['error']['context'] = error.context
        
        # Add request context in development
        if self.app.debug:
            response['error']['request'] = {
                'method': request.method,
                'url': request.url,
                'user_agent': request.headers.get('User-Agent'),
                'ip': request.remote_addr
            }
        
        return response
    
    def log_error(self, error: AppError, original_error: Optional[Exception] = None):
        """Log error with structured information"""
        log_data = {
            'trace_id': error.trace_id,
            'category': error.category.value,
            'severity': error.severity.value,
            'message': error.message,
            'user_message': error.user_message,
            'status_code': error.status_code,
            'timestamp': error.timestamp.isoformat(),
            'request_method': request.method if request else None,
            'request_url': request.url if request else None,
            'user_ip': request.remote_addr if request else None,
        }
        
        if error.field:
            log_data['field'] = error.field
        
        if error.context:
            log_data['context'] = error.context
        
        # Log stack trace for system errors
        if original_error and error.severity in [ErrorSeverity.HIGH, ErrorSeverity.CRITICAL]:
            log_data['stack_trace'] = traceback.format_exception(
                type(original_error), original_error, original_error.__traceback__
            )
        
        # Log at appropriate level based on severity
        if error.severity == ErrorSeverity.CRITICAL:
            self.app.logger.critical(f"Critical Error: {log_data}")
        elif error.severity == ErrorSeverity.HIGH:
            self.app.logger.error(f"High Severity Error: {log_data}")
        elif error.severity == ErrorSeverity.MEDIUM:
            self.app.logger.warning(f"Medium Severity Error: {log_data}")
        else:
            self.app.logger.info(f"Low Severity Error: {log_data}")


# Utility functions for common error scenarios
def validate_required_fields(data: Dict[str, Any], required_fields: list) -> None:
    """Validate that required fields are present and not empty"""
    for field in required_fields:
        if field not in data or not data[field]:
            raise ValidationError(
                message=f"Missing required field: {field}",
                field=field,
                user_message=f"Please provide a valid {field.replace('_', ' ')}"
            )


def validate_email(email: str) -> None:
    """Validate email format"""
    import re
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, email):
        raise ValidationError(
            message=f"Invalid email format: {email}",
            field="email",
            user_message="Please enter a valid email address"
        )


def require_auth(token: Optional[str]) -> None:
    """Validate authentication token"""
    if not token:
        raise AuthenticationError(
            message="No authentication token provided",
            user_message="Please log in to continue"
        )


def check_rate_limit(user_id: str, action: str, limit: int, window: int) -> None:
    """Check if user has exceeded rate limit (placeholder implementation)"""
    # This would integrate with your rate limiting system
    # For now, it's a placeholder that could be implemented with Redis or database
    pass


# Decorator for handling errors in routes
def handle_errors(f):
    """Decorator to wrap route functions with error handling"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except AppError:
            # Re-raise AppErrors to be handled by the error handler
            raise
        except Exception as e:
            # Convert unexpected errors to AppError
            raise AppError(
                message=f"Unexpected error in {f.__name__}: {str(e)}",
                user_message="An unexpected error occurred. Please try again.",
                category=ErrorCategory.SYSTEM_ERROR,
                severity=ErrorSeverity.CRITICAL,
                context={'function': f.__name__}
            )
    return decorated_function
