#!/usr/bin/env python3
"""
AI Writer Test Script
Tests the AI Writer functionality for content generation
"""

import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.getcwd())

try:
    from risk_gate.ai_writer import AIWriter
    
    print("🤖 Testing AI Writer System...")
    print("=" * 50)
    
    # Initialize AI Writer
    ai_writer = AIWriter()
    
    # Test proposal text
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
    
    print("📝 Testing Section Generation...")
    
    # Test 1: Generate missing section
    result1 = ai_writer.generate_missing_section(
        section_name="deliverables",
        proposal_text=test_proposal
    )
    
    print(f"✅ Section Generation: {result1['success']}")
    print(f"📊 Confidence: {result1['confidence']:.2f}")
    print(f"💭 Reasoning: {result1['reasoning']}")
    print(f"📄 Generated Text (first 200 chars): {result1['generated_text'][:200]}...")
    print()
    
    # Test 2: Improve weak area
    result2 = ai_writer.improve_weak_area(
        area_name="weak_timeline",
        proposal_text=test_proposal
    )
    
    print("🔧 Testing Area Improvement...")
    print(f"✅ Area Improvement: {result2['success']}")
    print(f"📊 Confidence: {result2['confidence']:.2f}")
    print(f"💭 Reasoning: {result2['reasoning']}")
    print(f"📄 Improved Text (first 200 chars): {result2['generated_text'][:200]}...")
    print()
    
    # Test 3: Correct clause
    result3 = ai_writer.correct_clause(
        clause_name="payment_terms",
        proposal_text=test_proposal
    )
    
    print("⚖️ Testing Clause Correction...")
    print(f"✅ Clause Correction: {result3['success']}")
    print(f"📊 Confidence: {result3['confidence']:.2f}")
    print(f"💭 Reasoning: {result3['reasoning']}")
    print(f"📄 Corrected Text (first 200 chars): {result3['generated_text'][:200]}...")
    print()
    
    # Test 4: Test with template examples
    template_examples = [
        "This project will deliver a comprehensive web application with user authentication, database management, and responsive design.",
        "Deliverables include: 1. Fully functional web application 2. User documentation 3. Technical documentation 4. Testing reports"
    ]
    
    result4 = ai_writer.generate_missing_section(
        section_name="deliverables",
        proposal_text=test_proposal,
        template_examples=template_examples
    )
    
    print("🎯 Testing with Template Examples...")
    print(f"✅ Generation with Examples: {result4['success']}")
    print(f"📊 Confidence: {result4['confidence']:.2f}")
    print(f"💭 Reasoning: {result4['reasoning']}")
    print()
    
    # Summary
    all_tests_passed = all([result1['success'], result2['success'], result3['success'], result4['success']])
    
    print("=" * 50)
    if all_tests_passed:
        print("🎉 All AI Writer tests passed!")
        print("✅ System is ready for API integration")
    else:
        print("❌ Some tests failed - check logs for details")
    
    print(f"\n📊 Average Confidence: {sum([result1['confidence'], result2['confidence'], result3['confidence'], result4['confidence']]) / 4:.2f}")
    
except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    print("Make sure all dependencies are installed:")
    print("pip install numpy PyPDF2 python-docx sentence-transformers chromadb")
    
except Exception as e:
    print(f"❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
