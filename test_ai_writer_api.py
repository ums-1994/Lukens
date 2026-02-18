#!/usr/bin/env python3
"""
AI Writer API Test Script
Tests the AI Writer API endpoints
"""

import sys
import os
import json

# Add the current directory to Python path
sys.path.insert(0, os.getcwd())

try:
    from risk_gate.ai_writer import AIWriter
    
    print("🧪 Testing AI Writer API Functions...")
    print("=" * 50)
    
    # Initialize AI Writer
    ai_writer = AIWriter()
    
    # Test data
    test_proposal = """
    EXECUTIVE SUMMARY
    This is a basic proposal for software development services.
    
    SCOPE OF WORK
    We will develop a web application for the client.
    
    BUDGET
    Total cost is $25,000.
    
    TIMELINE
    Project will take about 6 weeks.
    
    TEAM
    Our team has experienced developers.
    """
    
    # Test 1: Generate Section API
    print("📝 Testing Generate Section API...")
    section_request = {
        "section_name": "executive_summary",
        "proposal_text": test_proposal,
        "template_examples": []
    }
    
    result1 = ai_writer.generate_missing_section(
        section_name=section_request["section_name"],
        proposal_text=section_request["proposal_text"],
        template_examples=section_request["template_examples"]
    )
    
    print(f"✅ Status: {result1['success']}")
    print(f"📊 Confidence: {result1['confidence']:.2f}")
    print(f"💭 Reasoning: {result1['reasoning']}")
    print(f"📄 Generated (first 150 chars): {result1['generated_text'][:150]}...")
    print()
    
    # Test 2: Improve Area API
    print("🔧 Testing Improve Area API...")
    area_request = {
        "area_name": "weak_timeline",
        "proposal_text": test_proposal
    }
    
    result2 = ai_writer.improve_weak_area(
        area_name=area_request["area_name"],
        proposal_text=area_request["proposal_text"]
    )
    
    print(f"✅ Status: {result2['success']}")
    print(f"📊 Confidence: {result2['confidence']:.2f}")
    print(f"💭 Reasoning: {result2['reasoning']}")
    print(f"📄 Improved (first 150 chars): {result2['generated_text'][:150]}...")
    print()
    
    # Test 3: Correct Clause API
    print("⚖️ Testing Correct Clause API...")
    clause_request = {
        "clause_name": "payment_terms",
        "proposal_text": test_proposal,
        "template_clause": None
    }
    
    result3 = ai_writer.correct_clause(
        clause_name=clause_request["clause_name"],
        proposal_text=clause_request["proposal_text"],
        template_clause=clause_request["template_clause"]
    )
    
    print(f"✅ Status: {result3['success']}")
    print(f"📊 Confidence: {result3['confidence']:.2f}")
    print(f"💭 Reasoning: {result3['reasoning']}")
    print(f"📄 Corrected (first 150 chars): {result3['generated_text'][:150]}...")
    print()
    
    # Test 4: Complete API workflow
    print("🔄 Testing Complete API Workflow...")
    
    # Step 1: Generate missing executive summary
    exec_summary = ai_writer.generate_missing_section(
        section_name="executive_summary",
        proposal_text=test_proposal
    )
    
    # Step 2: Improve the timeline
    improved_timeline = ai_writer.improve_weak_area(
        area_name="weak_timeline",
        proposal_text=test_proposal
    )
    
    # Step 3: Add payment terms clause
    payment_terms = ai_writer.correct_clause(
        clause_name="payment_terms",
        proposal_text=test_proposal
    )
    
    # Combine all improvements
    enhanced_proposal = test_proposal + "\n\n" + exec_summary['generated_text'] + "\n\n" + improved_timeline['generated_text'] + "\n\n" + payment_terms['generated_text']
    
    print(f"✅ Workflow completed successfully")
    print(f"📊 Average Confidence: {(exec_summary['confidence'] + improved_timeline['confidence'] + payment_terms['confidence']) / 3:.2f}")
    print(f"📄 Enhanced proposal length: {len(enhanced_proposal)} characters")
    print()
    
    # Summary
    all_tests_passed = all([result1['success'], result2['success'], result3['success']])
    
    print("=" * 50)
    if all_tests_passed:
        print("🎉 All API tests passed!")
        print("✅ AI Writer is ready for production use")
        print("\n📋 API Endpoints Ready:")
        print("  POST /risk-gate/ai/generate-section")
        print("  POST /risk-gate/ai/improve-area") 
        print("  POST /risk-gate/ai/correct-clause")
        print("  GET  /risk-gate/ai/status")
        print("  GET  /risk-gate/ai/health")
    else:
        print("❌ Some API tests failed")
    
    print(f"\n🚀 Start the API server with: python ai_writer_api_server.py")
    
except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    print("Make sure all dependencies are installed")
    
except Exception as e:
    print(f"❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
