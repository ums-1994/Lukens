"""
Flask Middleware for Error Handling and Request Processing
"""

import time
import uuid
from functools import wraps
from flask import request, g, current_app
from error_handler import ErrorHandler, RateLimitError, AuthenticationError


class RequestMiddleware:
    """Middleware for request processing and error handling"""
    
    def __init__(self, app=None):
        self.app = app
        if app is not None:
            self.init_app(app)
    
    def init_app(self, app):
        """Initialize middleware for Flask app"""
        self.app = app
        
        # Initialize error handler
        self.error_handler = ErrorHandler(app)
        
        # Register middleware functions
        app.before_request(self.before_request)
        app.after_request(self.after_request)
        app.teardown_appcontext(self.teardown_request)
    
    def before_request(self):
        """Process request before handling"""
        # Generate request ID for tracing
        g.request_id = str(uuid.uuid4())
        g.start_time = time.time()
        
        # Log request
        current_app.logger.info(
            f"Request started: {request.method} {request.url} "
            f"[ID: {g.request_id}] [IP: {request.remote_addr}]"
        )
        
        # Add CORS headers for development
        if current_app.debug:
            self.add_cors_headers()
    
    def after_request(self, response):
        """Process response after handling"""
        # Calculate request duration
        duration = time.time() - g.get('start_time', time.time())
        
        # Add request ID to response headers
        response.headers['X-Request-ID'] = g.get('request_id', 'unknown')
        
        # Log response
        current_app.logger.info(
            f"Request completed: {request.method} {request.url} "
            f"[ID: {g.get('request_id', 'unknown')}] "
            f"[Status: {response.status_code}] "
            f"[Duration: {duration:.3f}s]"
        )
        
        return response
    
    def teardown_request(self, exception):
        """Clean up after request"""
        if exception:
            current_app.logger.error(
                f"Request failed with exception: {exception} "
                f"[ID: {g.get('request_id', 'unknown')}]"
            )
    
    def add_cors_headers(self):
        """Add CORS headers for development"""
        # This would be handled by Flask-CORS in production
        pass


def require_auth(f):
    """Decorator to require authentication for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            raise AuthenticationError(
                message="No authorization header provided",
                user_message="Please log in to access this resource"
            )
        
        if not auth_header.startswith('Bearer '):
            raise AuthenticationError(
                message="Invalid authorization header format",
                user_message="Invalid authentication format"
            )
        
        token = auth_header.split(' ')[1]
        
        # Here you would validate the token
        # For now, we'll just check if it exists
        if not token:
            raise AuthenticationError(
                message="No token provided",
                user_message="Please log in to access this resource"
            )
        
        # Store token in g for use in the route
        g.auth_token = token
        g.user_id = extract_user_id_from_token(token)  # Implement this function
        
        return f(*args, **kwargs)
    
    return decorated_function


def rate_limit(max_requests: int = 100, window: int = 3600):
    """Decorator to add rate limiting to routes"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Get user identifier (IP or user ID)
            user_id = g.get('user_id') or request.remote_addr
            route_key = f"{request.endpoint}:{user_id}"
            
            # Check rate limit (this would integrate with Redis or similar)
            if is_rate_limited(route_key, max_requests, window):
                raise RateLimitError(
                    retry_after=window,
                    user_message=f"Too many requests. Please wait {window} seconds and try again."
                )
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator


def validate_json(required_fields: list = None):
    """Decorator to validate JSON request data"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            from error_handler import ValidationError, validate_required_fields
            
            if not request.is_json:
                raise ValidationError(
                    message="Request must be JSON",
                    user_message="Please send data in JSON format"
                )
            
            data = request.get_json()
            if not data:
                raise ValidationError(
                    message="Empty JSON data",
                    user_message="Please provide valid data"
                )
            
            if required_fields:
                validate_required_fields(data, required_fields)
            
            # Store validated data in g for use in the route
            g.json_data = data
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator


# Utility functions (these would be implemented based on your auth system)
def extract_user_id_from_token(token: str) -> str:
    """Extract user ID from JWT token"""
    # This is a placeholder - implement based on your JWT system
    # You might use PyJWT or similar library
    try:
        # Decode JWT token and extract user ID
        # For now, return a placeholder
        return "user_123"
    except Exception:
        raise AuthenticationError(
            message="Invalid token",
            user_message="Your session has expired. Please log in again."
        )


def is_rate_limited(key: str, max_requests: int, window: int) -> bool:
    """Check if a key has exceeded rate limit"""
    # This is a placeholder - implement with Redis or database
    # For now, always return False (no rate limiting)
    return False


# Health check middleware
def add_health_check(app):
    """Add health check endpoint"""
    @app.route('/health')
    def health_check():
        """Health check endpoint"""
        return {
            'status': 'healthy',
            'timestamp': time.time(),
            'version': app.config.get('VERSION', '1.0.0')
        }
    
    @app.route('/ready')
    def readiness_check():
        """Readiness check endpoint"""
        # Check database connectivity, external services, etc.
        try:
            # Add your readiness checks here
            # For example, check database connection
            return {
                'status': 'ready',
                'timestamp': time.time(),
                'checks': {
                    'database': 'ok',
                    'external_services': 'ok'
                }
            }
        except Exception as e:
            current_app.logger.error(f"Readiness check failed: {e}")
            return {
                'status': 'not_ready',
                'timestamp': time.time(),
                'error': str(e)
            }, 503
