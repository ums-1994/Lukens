#!/usr/bin/env python3
"""
Compound Risk Detection Test Script
Tests the enhanced Risk Gate system with compound risk detection
"""

import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.getcwd())

try:
    from risk_gate.risk_engine.compound_risk import CompoundRiskDetector, Issue
    from risk_gate.risk_engine.ai_writer_helper import AIWriterGlobalHelper
    from risk_gate import RiskGate
    
    print("🔍 Testing Compound Risk Detection System...")
    print("=" * 60)
    
    # Test 1: Compound Risk Detector
    print("\n📊 Testing Compound Risk Detector...")
    
    detector = CompoundRiskDetector()
    
    # Create test issues
    test_issues = [
        Issue(
            type='structural',
            severity='high',
            theme='content_completeness',
            description='Missing executive summary section',
            location='executive_summary',
            confidence=0.9
        ),
        Issue(
            type='clause',
            severity='critical',
            theme='legal_deviation',
            description='Payment terms clause deviates from standard',
            location='payment_terms',
            confidence=0.95
        ),
        Issue(
            type='weakness',
            severity='medium',
            theme='quality_issues',
            description='Timeline description is weak',
            location='timeline',
            confidence=0.8
        ),
        Issue(
            type='semantic',
            severity='high',
            theme='semantic_risk',
            description='Contradiction between budget and scope',
            location='budget_section',
            confidence=0.85
        )
    ]
    
    compound_result = detector.calculate_compound_risk(test_issues)
    
    print(f"✅ Compound Risk Detection: {compound_result['is_high']}")
    print(f"📈 Compound Score: {compound_result['score']}")
    print(f"📝 Summary: {compound_result['summary']}")
    print(f"🎯 Recommended Action: {compound_result['recommended_action']}")
    print(f"🤖 AI Suggestion: {compound_result['ai_global_suggestion']}")
    
    if 'theme_breakdown' in compound_result:
        print("📋 Theme Breakdown:")
        for theme, data in compound_result['theme_breakdown'].items():
            print(f"  - {theme}: Score {data['score']}, {data['count']} issues")
    
    # Test 2: AI Writer Global Helper
    print("\n🤖 Testing AI Writer Global Helper...")
    
    helper = AIWriterGlobalHelper()
    
    # Convert issues to dict format for helper
    issue_dicts = [
        {
            'type': issue.type,
            'severity': issue.severity,
            'theme': issue.theme,
            'description': issue.description,
            'location': issue.location,
            'confidence': issue.confidence
        }
        for issue in test_issues
    ]
    
    test_proposal = """
    EXECUTIVE SUMMARY
    
    SCOPE OF WORK
    We will develop a web application.
    
    BUDGET
    Total cost is $25,000.
    
    TIMELINE
    Project will take 6 weeks.
    """
    
    global_fix_result = helper.write_global_summary(issue_dicts, test_proposal)
    
    print(f"✅ Global Fix Generation: {global_fix_result['success']}")
    if global_fix_result['success']:
        print(f"📄 Total Issues Fixed: {global_fix_result['total_issues_fixed']}")
        print(f"📊 Overall Confidence: {global_fix_result['confidence']:.2f}")
        print(f"📝 Global Summary: {global_fix_result['global_summary']}")
        print(f"📋 Action Plan: {global_fix_result['action_plan']}")
        
        # Show fix categories
        for fix_type, fixes in global_fix_result['fixes'].items():
            if fixes:
                print(f"  🔧 {fix_type}: {len(fixes)} fixes generated")
    
    # Test 3: Full Risk Gate Analysis with Compound Risk
    print("\n🚀 Testing Full Risk Gate Analysis...")
    
    risk_gate = RiskGate()
    
    # Test proposal with multiple critical issues
    problematic_proposal = """
    BUDGET
    Total cost is $25,000.
    
    TIMELINE
    Project will take about 6 weeks.
    
    TEAM
    Our team has experienced developers.
    """
    
    full_analysis = risk_gate.analyze_proposal(problematic_proposal)
    
    print(f"✅ Full Analysis: {full_analysis['success']}")
    if full_analysis['success']:
        print(f"📊 Overall Score: {full_analysis['overall_score']}")
        print(f"🚨 Compound Risk High: {full_analysis['compound_risk']['is_high']}")
        print(f"📈 Compound Risk Score: {full_analysis['compound_risk']['score']}")
        print(f"🚫 Release Blocked: {full_analysis['release_blocked']}")
        
        if full_analysis['release_blocked']:
            print(f"📝 Block Reason: {full_analysis['block_reason']}")
        
        if full_analysis['ai_global_fix']:
            print(f"🤖 AI Global Fix Available: {full_analysis['ai_global_fix']['success']}")
        
        print(f"📋 Total Issues: {len(full_analysis['issues'])}")
        
        # Show issue breakdown
        issue_types = {}
        for issue in full_analysis['issues']:
            issue_type = issue['type']
            issue_types[issue_type] = issue_types.get(issue_type, 0) + 1
        
        print("📊 Issue Breakdown:")
        for issue_type, count in issue_types.items():
            print(f"  - {issue_type}: {count} issues")
    
    # Test 4: Very High Risk Scenario
    print("\n🚨 Testing Very High Risk Scenario...")
    
    very_risky_proposal = """
    BUDGET
    Cheap work.
    
    TIMELINE
    Soon.
    """
    
    risky_analysis = risk_gate.analyze_proposal(very_risky_proposal)
    
    print(f"✅ Risky Proposal Analysis: {risky_analysis['success']}")
    if risky_analysis['success']:
        print(f"📊 Overall Score: {risky_analysis['overall_score']}")
        print(f"🚨 Compound Risk High: {risky_analysis['compound_risk']['is_high']}")
        print(f"📈 Compound Risk Score: {risky_analysis['compound_risk']['score']}")
        print(f"🚫 Release Blocked: {risky_analysis['release_blocked']}")
        print(f"📋 Total Issues: {len(risky_analysis['issues'])}")
        
        if risky_analysis['release_blocked']:
            print(f"📝 Block Reason: {risky_analysis['block_reason']}")
            print(f"🤖 AI Global Fix: {risky_analysis['ai_global_fix']['success'] if risky_analysis['ai_global_fix'] else 'None'}")
    
    # Test 5: Low Risk Scenario
    print("\n✅ Testing Low Risk Scenario...")
    
    good_proposal = """
    EXECUTIVE SUMMARY
    This proposal outlines our comprehensive approach to delivering exceptional value for your project.
    
    SCOPE OF WORK
    We will develop a comprehensive web application with user authentication, database management, and responsive design.
    
    DELIVERABLES
    1. Fully functional web application
    2. User documentation and training materials
    3. Technical documentation
    4. Testing and quality assurance reports
    
    TIMELINE
    Phase 1: Planning and Design (2 weeks)
    Phase 2: Development (4 weeks)
    Phase 3: Testing and Deployment (2 weeks)
    Total duration: 8 weeks
    
    BUDGET
    Total investment: $50,000
    - Phase 1: $10,000
    - Phase 2: $25,000
    - Phase 3: $10,000
    - Contingency: $5,000
    
    TEAM
    Our team consists of experienced professionals:
    - Project Manager with 10+ years experience
    - Senior Developer with 8+ years experience
    - QA Specialist with 5+ years experience
    - UI/UX Designer with 6+ years experience
    
    PAYMENT TERMS
    Payments shall be made within 30 days of invoice date. Late payments shall incur interest at 1.5% per month.
    
    INTELLECTUAL PROPERTY
    All work product shall become the exclusive property of the client upon full payment.
    """
    
    good_analysis = risk_gate.analyze_proposal(good_proposal)
    
    print(f"✅ Good Proposal Analysis: {good_analysis['success']}")
    if good_analysis['success']:
        print(f"📊 Overall Score: {good_analysis['overall_score']}")
        print(f"🚨 Compound Risk High: {good_analysis['compound_risk']['is_high']}")
        print(f"📈 Compound Risk Score: {good_analysis['compound_risk']['score']}")
        print(f"🚫 Release Blocked: {good_analysis['release_blocked']}")
        print(f"📋 Total Issues: {len(good_analysis['issues'])}")
    
    # Summary
    print("\n" + "=" * 60)
    print("🎉 Compound Risk Detection Tests Completed!")
    
    all_tests_passed = (
        compound_result['is_high'] or compound_result['score'] > 3.0 and  # Should detect risk
        global_fix_result['success'] and  # Should generate fixes
        full_analysis['success'] and  # Full analysis should work
        risky_analysis['success'] and  # Risky analysis should work
        good_analysis['success'] and  # Good proposal analysis should work
        not good_analysis['release_blocked']  # Should not block good proposal
    )
    
    if all_tests_passed:
        print("✅ All tests passed! Compound risk detection is working correctly.")
        print("🚀 System ready for production with enhanced risk detection.")
    else:
        print("❌ Some tests failed. Check the output above for details.")
    
    print(f"\n📊 Test Summary:")
    print(f"  - Compound Risk Detector: {'✅' if compound_result['score'] > 3.0 else '❌'}")
    print(f"  - AI Writer Global Helper: {'✅' if global_fix_result['success'] else '❌'}")
    print(f"  - Full Analysis (Problematic): {'✅' if full_analysis['success'] else '❌'}")
    print(f"  - Full Analysis (Very Risky): {'✅' if risky_analysis['success'] else '❌'}")
    print(f"  - Full Analysis (Low Risk): {'✅' if good_analysis['success'] and not good_analysis['release_blocked'] else '❌'}")
    
    # Show compound risk blocking behavior
    print(f"\n🚨 Compound Risk Blocking:")
    print(f"  - Problematic Proposal Blocked: {'✅' if full_analysis.get('release_blocked', False) else '❌'}")
    print(f"  - Very Risky Proposal Blocked: {'✅' if risky_analysis.get('release_blocked', False) else '❌'}")
    print(f"  - Good Proposal Blocked: {'✅' if not good_analysis.get('release_blocked', True) else '❌'}")
    
except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    print("Make sure all dependencies are installed and modules are available")
    
except Exception as e:
    print(f"❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
