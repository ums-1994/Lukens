from datetime import datetime
import uuid
import os

from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.dialects.postgresql import UUID


db = SQLAlchemy()  # If you already initialize db elsewhere, import it instead


def gen_uuid() -> str:
    return str(uuid.uuid4())


class ContentModule(db.Model):
    __tablename__ = "content_modules"

    id = db.Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    title = db.Column(db.String(512), nullable=False)
    category = db.Column(db.String(128), nullable=False)
    body = db.Column(db.Text, nullable=False)
    version = db.Column(db.Integer, default=1)
    created_by = db.Column(UUID(as_uuid=False), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_editable = db.Column(db.Boolean, default=False)

    versions = db.relationship(
        "ModuleVersion",
        backref="module",
        lazy=True,
        cascade="all, delete-orphan",
    )

    def serialize(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "category": self.category,
            "body": self.body,
            "version": self.version,
            "created_by": self.created_by,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "is_editable": self.is_editable,
        }


class ModuleVersion(db.Model):
    __tablename__ = "module_versions"

    id = db.Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    module_id = db.Column(
        UUID(as_uuid=False), db.ForeignKey("content_modules.id", ondelete="CASCADE")
    )
    version = db.Column(db.Integer, nullable=False)
    snapshot = db.Column(db.Text, nullable=False)
    created_by = db.Column(UUID(as_uuid=False), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    note = db.Column(db.String(512), nullable=True)

    def serialize(self) -> dict:
        return {
            "id": self.id,
            "module_id": self.module_id,
            "version": self.version,
            "snapshot": self.snapshot,
            "created_by": self.created_by,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "note": self.note,
        }








