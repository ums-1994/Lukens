"""
Test script for AI service integration
"""
import os
import sys
from pathlib import Path

# Add backend directory to path
backend_dir = Path(__file__).parent.parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

from dotenv import load_dotenv
from ai_service import AIService

# Load environment variables
load_dotenv()

def test_ai_service():
    """Test the AI service with a sample proposal"""
    
    print("=" * 60)
    print("Testing AI Service Integration")
    print("=" * 60)
    
    # Initialize AI service
    try:
        ai_service = AIService()
        print(f"\n✓ AI Service Initialized Successfully")
        print(f"✓ Using Model: {ai_service.model}")
        print(f"✓ Base URL: {ai_service.base_url}")
        print(f"✓ API Key: {ai_service.api_key[:20]}..." if ai_service.api_key else "✗ No API Key")
    except Exception as e:
        print(f"\n✗ Failed to initialize AI Service: {e}")
        return
    
    # Test sample proposal data
    sample_proposal = {
        "id": "test-001",
        "title": "Website Redesign Project",
        "client_name": "Acme Corporation",
        "project_type": "Web Development",
        "executive_summary": "We will redesign your website.",
        "scope_deliverables": "Various web pages and other stuff.",
        "timeline": "Quick turnaround in 2 weeks",
        "assumptions": "",
        "team_bios": "John - Developer",
        "company_profile": "Khonology is a leading tech company.",
        "terms_conditions": "Standard terms apply."
    }
    
    print("\n" + "=" * 60)
    print("Test 1: Risk Analysis (Wildcard Challenge)")
    print("=" * 60)
    
    try:
        result = ai_service.analyze_proposal_risks(sample_proposal)
        print(f"\n✓ Risk Score: {result.get('risk_score', 'N/A')}/100")
        print(f"✓ Risk Level: {result.get('overall_risk_level', 'N/A')}")
        print(f"✓ Can Release: {result.get('can_release', False)}")
        print(f"\n✓ Summary: {result.get('summary', 'No summary')}")
        print(f"\n✓ Issues Found: {len(result.get('issues', []))}")
        
        for i, issue in enumerate(result.get('issues', [])[:3], 1):
            print(f"\n  Issue {i}:")
            print(f"    - Section: {issue.get('section', 'N/A')}")
            print(f"    - Severity: {issue.get('severity', 'N/A')}")
            desc = issue.get('description', 'No description')
            print(f"    - Description: {desc[:80]}...")
            
    except Exception as e:
        print(f"\n✗ Risk Analysis Failed: {e}")
    
    print("\n" + "=" * 60)
    print("Test 2: Content Generation")
    print("=" * 60)
    
    try:
        context = {
            "client_name": "Acme Corporation",
            "project_type": "Web Development",
            "industry": "E-commerce"
        }
        
        result = ai_service.generate_proposal_section("executive_summary", context)
        print(f"\n✓ Generated Content ({len(result)} characters):")
        print(f"\n{result[:300]}...")
        
    except Exception as e:
        print(f"\n✗ Content Generation Failed: {e}")
    
    print("\n" + "=" * 60)
    print("Test 3: Content Improvement")
    print("=" * 60)
    
    try:
        poor_content = "We will do the project. It will be good."
        
        result = ai_service.improve_content(poor_content, "executive_summary")
        print(f"\n✓ Quality Score: {result['quality_score']}/100")
        print(f"\n✓ Strengths: {', '.join(result['strengths'][:2])}")
        print(f"\n✓ Improvements Suggested: {len(result['improvements'])}")
        
        if result['improvements']:
            print(f"\n  Top Improvement:")
            print(f"    - {result['improvements'][0]['suggestion']}")
        
    except Exception as e:
        print(f"\n✗ Content Improvement Failed: {e}")
    
    print("\n" + "=" * 60)
    print("Test 4: Compliance Check")
    print("=" * 60)
    
    try:
        result = ai_service.check_compliance(sample_proposal)
        print(f"\n✓ Compliance Score: {result['compliance_score']}/100")
        print(f"✓ Ready for Approval: {result['ready_for_approval']}")
        print(f"\n✓ Passed Checks: {len(result['passed_checks'])}")
        print(f"✓ Failed Checks: {len(result['failed_checks'])}")
        
        if result['failed_checks']:
            print(f"\n  Failed Check Example:")
            print(f"    - {result['failed_checks'][0]}")
        
    except Exception as e:
        print(f"\n✗ Compliance Check Failed: {e}")
    
    print("\n" + "=" * 60)
    print("All Tests Completed!")
    print("=" * 60)

if __name__ == "__main__":
    test_ai_service()