"""
FastAPI Server with Risk Gate Analysis Endpoint
Main application entry point for the new AI-powered risk analysis
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

from risk_gate.api.analyze_endpoint import analyze_router

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Risk Gate AI Analysis API",
    description="AI-powered proposal risk analysis with Hugging Face models",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(analyze_router)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Risk Gate AI Analysis API",
        "version": "1.0.0",
        "endpoints": {
            "analyze": "/api/risk-gate/analyze",
            "status": "/api/risk-gate/status",
            "health": "/api/risk-gate/health"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "risk-gate-ai-analysis",
        "version": "1.0.0"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
