import os
from flask import Flask
from flask_cors import CORS
from models_content_library import db
from routes_content_library import content_bp


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)

    # Database configuration (env override, with sensible defaults)
    db_user = os.getenv("DB_USER", "postgres")
    db_pass = os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "proposal_sow_builder")

    app.config["SQLALCHEMY_DATABASE_URI"] = (
        os.getenv(
            "DATABASE_URL",
            f"postgresql+psycopg2://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}",
        )
    )
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)

    with app.app_context():
        # Do not create_all for managed schemas; tables already created in Postgres
        pass

    app.register_blueprint(content_bp)
    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=True)








