"""
SQLAlchemy models compatible with existing database structure
"""
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID, ENUM
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

Base = declarative_base()

class Client(Base):
    __tablename__ = "clients"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(150), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    organization = Column(String(150))
    role = Column(ENUM('Client', 'Approver', 'Admin', name='client_role_enum'), default='Client')
    token = Column(UUID(as_uuid=True), unique=True, nullable=False, default=func.gen_random_uuid())
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    proposals = relationship("Proposal", back_populates="client", cascade="all, delete-orphan")
    dashboard_tokens = relationship("ClientDashboardToken", back_populates="client", cascade="all, delete-orphan")
    feedback = relationship("ProposalFeedback", back_populates="client", cascade="all, delete-orphan")

class Proposal(Base):
    __tablename__ = "proposals"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(150))  # Existing column
    title = Column(String(255), nullable=False)  # Existing column
    content = Column(Text)  # Existing column
    status = Column(String(150))  # Existing column - keeping as string for compatibility
    client_name = Column(String(150))  # Existing column
    client_email = Column(String(150))  # Existing column
    budget = Column(String(50))  # Existing column
    timeline_days = Column(Integer)  # Existing column
    created_at = Column(DateTime(timezone=True), server_default=func.now())  # Existing column
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())  # Existing column
    
    # New columns for client dashboard functionality
    client_id = Column(Integer, ForeignKey('clients.id', ondelete='SET NULL'), nullable=True)
    released_at = Column(DateTime(timezone=True))
    signed_at = Column(DateTime(timezone=True))
    signed_by = Column(String(150))
    signature_data = Column(Text)  # Base64 encoded signature
    
    # Relationships
    client = relationship("Client", back_populates="proposals")
    approvals = relationship("Approval", back_populates="proposal", cascade="all, delete-orphan")
    dashboard_tokens = relationship("ClientDashboardToken", back_populates="proposal", cascade="all, delete-orphan")
    feedback = relationship("ProposalFeedback", back_populates="proposal", cascade="all, delete-orphan")

class Approval(Base):
    __tablename__ = "approvals"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    approver_name = Column(String(150), nullable=False)
    approver_email = Column(String(150), nullable=False)
    approved_pdf_path = Column(Text)
    approved_at = Column(DateTime(timezone=True), server_default=func.now())
    proposal_id = Column(Integer, ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    
    # Relationships
    proposal = relationship("Proposal", back_populates="approvals")

class ClientDashboardToken(Base):
    __tablename__ = "client_dashboard_tokens"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    token = Column(Text, unique=True, nullable=False)
    client_id = Column(Integer, ForeignKey('clients.id', ondelete='CASCADE'), nullable=False)
    proposal_id = Column(Integer, ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    client = relationship("Client", back_populates="dashboard_tokens")
    proposal = relationship("Proposal", back_populates="dashboard_tokens")

class ProposalFeedback(Base):
    __tablename__ = "proposal_feedback"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    proposal_id = Column(Integer, ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    client_id = Column(Integer, ForeignKey('clients.id', ondelete='CASCADE'), nullable=False)
    feedback_text = Column(Text)
    rating = Column(Integer, CheckConstraint('rating >= 1 AND rating <= 5'))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    proposal = relationship("Proposal", back_populates="feedback")
    client = relationship("Client", back_populates="feedback")

class DocumentComment(Base):
    __tablename__ = "document_comments"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    proposal_id = Column(Integer, ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    comment_text = Column(Text, nullable=False)
    created_by = Column(String(150))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    proposal = relationship("Proposal")
