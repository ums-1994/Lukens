"""
SQLAlchemy models for the KhonoPro Proposal System - Client Side
"""
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, ForeignKey, CheckConstraint, Float, JSON
from sqlalchemy.dialects.postgresql import UUID, ENUM, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

Base = declarative_base()

class Client(Base):
    __tablename__ = "clients"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    organization = Column(String(150))
    role = Column(ENUM('Client', 'Approver', 'Admin', name='client_role_enum'), default='Client')
    token = Column(UUID(as_uuid=True), unique=True, nullable=False, default=uuid.uuid4)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    proposals = relationship("Proposal", back_populates="client", cascade="all, delete-orphan")
    dashboard_tokens = relationship("ClientDashboardToken", back_populates="client", cascade="all, delete-orphan")
    feedback = relationship("ProposalFeedback", back_populates="client", cascade="all, delete-orphan")

class Proposal(Base):
    __tablename__ = "proposals"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False)
    content = Column(Text)
    pdf_path = Column(Text)
    status = Column(ENUM('Draft', 'In Review', 'Released', 'Approved', 'Signed', 'Archived', name='proposal_status_enum'), default='Draft')
    client_id = Column(UUID(as_uuid=True), ForeignKey('clients.id', ondelete='CASCADE'), nullable=False)
    created_by = Column(UUID(as_uuid=True))  # Internal user who created the proposal
    released_at = Column(DateTime(timezone=True))
    signed_at = Column(DateTime(timezone=True))
    signed_by = Column(String(150))
    signature_data = Column(Text)  # Base64 encoded signature
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Workflow fields
    governance_status = Column(String(50))  # 'PASSED', 'FAILED', 'PENDING', null
    risk_score = Column(Float)  # 0-100 risk score
    risk_level = Column(String(20))  # 'Low', 'Medium', 'High'
    completed_steps = Column(JSONB)  # Array of completed step names: ['compose', 'govern', 'risk', etc.]
    template_id = Column(String(255))  # Template used for this proposal
    template_type = Column(String(50))  # 'proposal', 'sow', 'rfi'
    proposal_data = Column(JSONB)  # Store form data, selected modules, etc.
    
    # Relationships
    client = relationship("Client", back_populates="proposals")
    approvals = relationship("Approval", back_populates="proposal", cascade="all, delete-orphan")
    dashboard_tokens = relationship("ClientDashboardToken", back_populates="proposal", cascade="all, delete-orphan")
    feedback = relationship("ProposalFeedback", back_populates="proposal", cascade="all, delete-orphan")

class Approval(Base):
    __tablename__ = "approvals"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    approver_name = Column(String(150), nullable=False)
    approver_email = Column(String(150), nullable=False)
    approved_pdf_path = Column(Text)
    approved_at = Column(DateTime(timezone=True), server_default=func.now())
    proposal_id = Column(UUID(as_uuid=True), ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    
    # Relationships
    proposal = relationship("Proposal", back_populates="approvals")

class ClientDashboardToken(Base):
    __tablename__ = "client_dashboard_tokens"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    token = Column(Text, unique=True, nullable=False)
    client_id = Column(UUID(as_uuid=True), ForeignKey('clients.id', ondelete='CASCADE'), nullable=False)
    proposal_id = Column(UUID(as_uuid=True), ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    client = relationship("Client", back_populates="dashboard_tokens")
    proposal = relationship("Proposal", back_populates="dashboard_tokens")

class ProposalFeedback(Base):
    __tablename__ = "proposal_feedback"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    proposal_id = Column(UUID(as_uuid=True), ForeignKey('proposals.id', ondelete='CASCADE'), nullable=False)
    client_id = Column(UUID(as_uuid=True), ForeignKey('clients.id', ondelete='CASCADE'), nullable=False)
    feedback_text = Column(Text)
    rating = Column(Integer, CheckConstraint('rating >= 1 AND rating <= 5'))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    proposal = relationship("Proposal", back_populates="feedback")
    client = relationship("Client", back_populates="feedback")
