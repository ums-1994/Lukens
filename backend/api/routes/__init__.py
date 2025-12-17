"""Route blueprints for the backend API."""

from .creator import bp as creator_bp
from .client import bp as client_bp
from .approver import bp as approver_bp
from .collaborator import bp as collaborator_bp
from .clients import bp as clients_bp
from .auth import bp as auth_bp
from .shared import bp as shared_bp

__all__ = ['creator_bp', 'client_bp', 'approver_bp', 'collaborator_bp', 'clients_bp', 'auth_bp', 'shared_bp']

