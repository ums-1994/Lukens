"""
Risk Gate Analysis API Endpoint
FastAPI route for AI-powered proposal risk analysis
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, validator
import logging
from typing import Dict, Any

from ..ai.risk_analyzer import get_risk_analyzer


# Request model
class AnalysisRequest(BaseModel):
    proposal_text: str
    
    @validator('proposal_text')
    def validate_proposal_text(cls, v):
        if not v or not v.strip():
            raise ValueError("Proposal text cannot be empty")
        if len(v.strip()) < 50:
            raise ValueError("Proposal text must be at least 50 characters long")
        if len(v.strip()) > 50000:
            raise ValueError("Proposal text cannot exceed 50000 characters")
        return v.strip()


# Response model
class AnalysisResponse(BaseModel):
    success: bool
    analysis: Dict[str, Any]
    message: str = ""


# Create router
analyze_router = APIRouter(prefix="/api/risk-gate", tags=["risk-analysis"])
logger = logging.getLogger(__name__)


@analyze_router.post("/analyze", response_model=AnalysisResponse)
async def analyze_proposal(request: AnalysisRequest):
    """
    Analyze proposal for risks using AI and vector retrieval
    
    Args:
        request: Analysis request containing proposal text
        
    Returns:
        Analysis results with missing sections, weak sections, compound risks, and summary
    """
    try:
        logger.info(f"Starting risk analysis for proposal of length {len(request.proposal_text)}")
        
        # Get risk analyzer instance
        risk_analyzer = get_risk_analyzer()
        
        # Perform analysis
        analysis_result = risk_analyzer.analyze_proposal(request.proposal_text)
        
        logger.info(f"Analysis completed successfully")
        
        return AnalysisResponse(
            success=True,
            analysis=analysis_result,
            message="Analysis completed successfully"
        )
        
    except ValueError as e:
        logger.warning(f"Validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    except Exception as e:
        logger.error(f"Error during analysis: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )


@analyze_router.get("/status")
async def get_analysis_status():
    """
    Get status of the AI analysis system
    
    Returns:
        System status including model loading and component availability
    """
    try:
        risk_analyzer = get_risk_analyzer()
        model_status = risk_analyzer.get_model_status()
        
        return {
            "success": True,
            "status": "operational" if model_status["model_loaded"] else "loading",
            "components": model_status
        }
        
    except Exception as e:
        logger.error(f"Error getting status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get status: {str(e)}"
        )


@analyze_router.get("/health")
async def health_check():
    """
    Simple health check endpoint
    
    Returns:
        Health status of the analysis service
    """
    return {
        "success": True,
        "status": "healthy",
        "service": "risk-gate-analysis"
    }
