#!/usr/bin/env python3
"""
Simple Risk Gate Test
"""

import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.getcwd())

try:
    from risk_gate.risk_engine.risk_gate import RiskGate
    
    print("🚀 Testing Risk Gate System...")
    print("=" * 50)
    
    # Initialize Risk Gate
    risk_gate = RiskGate()
    
    # Test with a simple proposal
    test_proposal = """
    EXECUTIVE SUMMARY
    This is a test proposal for our services.
    
    SCOPE OF WORK
    We will provide development services including:
    - Web application development
    - Database design
    - Testing and deployment
    
    BUDGET
    Total cost: $25,000
    
    TIMELINE
    Project duration: 8 weeks
    
    TEAM
    Our team has experienced developers.
    """
    
    print("📋 Analyzing test proposal...")
    result = risk_gate.analyze_proposal(test_proposal)
    
    if result['success']:
        print(f"✅ Analysis successful!")
        print(f"📊 Risk Score: {result['risk_score']:.2f}")
        print(f"🚦 Compound Risk: {result['compound_risk']}")
        print(f"📈 Risk Level: {result['risk_level']}")
        print(f"🎯 Decision: {result['decision']}")
        
        print(f"\n📄 Summary:")
        print(result['summary'])
        
        if result['recommendations']:
            print(f"\n💡 Recommendations:")
            for i, rec in enumerate(result['recommendations'][:3], 1):
                print(f"  {i}. {rec}")
    else:
        print(f"❌ Analysis failed: {result['error']}")
    
    print("\n🎉 Test completed!")
    
except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    print("Make sure all dependencies are installed:")
    print("pip install numpy PyPDF2 python-docx sentence-transformers chromadb")
    
except Exception as e:
    print(f"❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
