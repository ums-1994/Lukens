"""
Main Flask application factory
"""
from flask import Flask
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

def create_app():
    """Create and configure Flask application"""
    app = Flask(__name__)
    
    # CORS configuration
    CORS(app, supports_credentials=True)
    
    # Rate limiting
    limiter = Limiter(
        app=app,
        key_func=get_remote_address,
        default_limits=["200 per day", "50 per hour"]
    )
    
    # App configuration
    app.config['JSON_SORT_KEYS'] = False
    app.config['PROPAGATE_EXCEPTIONS'] = True
    app.config['UPLOAD_FOLDER'] = os.getenv('UPLOAD_FOLDER', './uploads')
    app.config['MAX_CONTENT_LENGTH'] = int(os.getenv('MAX_CONTENT_LENGTH', 104857600))
    
    # Create upload folder
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    
    # Register blueprints
    from api.routes import auth, proposals, clients, ai, collaboration, content, docusign, onboarding
    
    app.register_blueprint(auth.bp)
    app.register_blueprint(proposals.bp)
    app.register_blueprint(clients.bp)
    app.register_blueprint(ai.bp)
    app.register_blueprint(collaboration.bp)
    app.register_blueprint(content.bp)
    app.register_blueprint(docusign.bp)
    app.register_blueprint(onboarding.bp)
    
    # Health check
    @app.get("/health")
    def health_check():
        from api.utils.database import get_db_connection
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
            return {"status": "ok", "database": "connected"}, 200
        except Exception as e:
            return {"status": "error", "database": str(e)}, 500
    
    # Initialize database on first request
    @app.before_request
    def init_db():
        from api.utils.database import init_database
        init_database()
    
    return app

# Create app instance
app = create_app()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8000)

