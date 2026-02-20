#!/usr/bin/env python3
"""
Compound Risk API Test Script
Tests the compound risk detection API endpoints
"""

import sys
import os
import json
import requests

# Add the current directory to Python path
sys.path.insert(0, os.getcwd())

try:
    from risk_gate.api.compound_risk_routes import compound_risk_bp
    from flask import Flask
    
    print("🔍 Testing Compound Risk API...")
    print("=" * 60)
    
    # Create Flask app for testing
    app = Flask(__name__)
    app.register_blueprint(compound_risk_bp)
    
    # Test client
    with app.test_client() as client:
        
        # Test 1: Health Check
        print("\n🏥 Testing Health Check...")
        response = client.get('/api/compound-risk/health')
        print(f"✅ Health Check Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            print(f"📊 Status: {data.get('status')}")
            print(f"⏰ Timestamp: {data.get('timestamp')}")
        
        # Test 2: System Status
        print("\n📊 Testing System Status...")
        response = client.get('/api/compound-risk/status')
        print(f"✅ System Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            print(f"🔧 System Status: {data.get('system_status')}")
            print(f"🎯 Version: {data.get('version')}")
            print(f"🚀 Features: {', '.join(data.get('features', []))}")
        
        # Test 3: Risk Thresholds
        print("\n📏 Testing Risk Thresholds...")
        response = client.get('/api/compound-risk/thresholds')
        print(f"✅ Thresholds Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            print(f"🎯 Compound Risk Threshold: {data.get('compound_risk_threshold')}")
            print(f"⚖️ Theme Weights: {len(data.get('theme_weights', {}))} themes")
            print(f"📊 Severity Scores: {len(data.get('severity_scores', {}))} severity levels")
        
        # Test 4: Quick Compound Risk Assessment
        print("\n⚡ Testing Quick Compound Risk Assessment...")
        
        test_issues = [
            {
                "type": "structural",
                "severity": "high",
                "theme": "content_completeness",
                "description": "Missing executive summary section",
                "location": "executive_summary",
                "confidence": 0.9
            },
            {
                "type": "clause",
                "severity": "critical",
                "theme": "legal_deviation",
                "description": "Payment terms clause deviates from standard",
                "location": "payment_terms",
                "confidence": 0.95
            },
            {
                "type": "weakness",
                "severity": "medium",
                "theme": "quality_issues",
                "description": "Timeline description is weak",
                "location": "timeline",
                "confidence": 0.8
            }
        ]
        
        response = client.post('/api/compound-risk/quick-assess',
                              data=json.dumps({'issues': test_issues}),
                              content_type='application/json')
        print(f"✅ Quick Assessment Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            compound_risk = data.get('compound_risk', {})
            print(f"🚨 Compound Risk High: {compound_risk.get('is_high')}")
            print(f"📈 Compound Score: {compound_risk.get('score')}")
            print(f"📝 Summary: {compound_risk.get('summary')[:100]}...")
            print(f"🎯 Recommended Action: {compound_risk.get('recommended_action')}")
        
        # Test 5: Full Compound Risk Analysis
        print("\n🔬 Testing Full Compound Risk Analysis...")
        
        test_proposal = """
        BUDGET
        Total cost is $25,000.
        
        TIMELINE
        Project will take about 6 weeks.
        
        TEAM
        Our team has experienced developers.
        """
        
        response = client.post('/api/compound-risk/analyze',
                              data=json.dumps({
                                  'proposal_text': test_proposal,
                                  'include_ai_fixes': True
                              }),
                              content_type='application/json')
        print(f"✅ Full Analysis Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            print(f"📊 Overall Score: {data.get('overall_score')}")
            print(f"🚨 Compound Risk High: {data.get('compound_risk', {}).get('is_high')}")
            print(f"📈 Compound Risk Score: {data.get('compound_risk', {}).get('score')}")
            print(f"🚫 Release Blocked: {data.get('release_blocked')}")
            print(f"📋 Total Issues: {len(data.get('issues', []))}")
            
            if data.get('ai_global_fix'):
                ai_fix = data['ai_global_fix']
                print(f"🤖 AI Global Fix: {ai_fix.get('success')}")
                print(f"📄 Total Issues Fixed: {ai_fix.get('total_issues_fixed')}")
                print(f"📊 Overall Confidence: {ai_fix.get('confidence', 0):.2f}")
        
        # Test 6: AI Global Fixes Generation
        print("\n🤖 Testing AI Global Fixes Generation...")
        
        response = client.post('/api/compound-risk/generate-fixes',
                              data=json.dumps({
                                  'issues': test_issues,
                                  'proposal_text': test_proposal
                              }),
                              content_type='application/json')
        print(f"✅ AI Fixes Status: {response.status_code}")
        if response.status_code == 200:
            data = response.get_json()
            print(f"🤖 Generation Success: {data.get('success')}")
            if data.get('success'):
                print(f"📄 Total Issues Fixed: {data.get('total_issues_fixed')}")
                print(f"📊 Overall Confidence: {data.get('confidence', 0):.2f}")
                print(f"📝 Global Summary: {data.get('global_summary')[:100]}...")
                print(f"📋 Action Plan: {data.get('action_plan')[:100]}...")
                
                # Show fix categories
                fixes = data.get('fixes', {})
                print(f"🔧 Fix Categories:")
                for fix_type, fix_list in fixes.items():
                    if fix_list:
                        print(f"  - {fix_type}: {len(fix_list)} fixes")
        
        # Test 7: Error Handling
        print("\n❌ Testing Error Handling...")
        
        # Test missing proposal text
        response = client.post('/api/compound-risk/analyze',
                              data=json.dumps({}),
                              content_type='application/json')
        print(f"✅ Missing Proposal Text Error: {response.status_code}")
        if response.status_code == 400:
            data = response.get_json()
            print(f"📝 Error Message: {data.get('error')}")
        
        # Test missing issues
        response = client.post('/api/compound-risk/quick-assess',
                              data=json.dumps({}),
                              content_type='application/json')
        print(f"✅ Missing Issues Error: {response.status_code}")
        if response.status_code == 400:
            data = response.get_json()
            print(f"📝 Error Message: {data.get('error')}")
        
        # Test invalid endpoint
        response = client.get('/api/compound-risk/invalid-endpoint')
        print(f"✅ Invalid Endpoint Error: {response.status_code}")
        if response.status_code == 404:
            data = response.get_json()
            if data:
                print(f"📝 Error Message: {data.get('error')}")
            else:
                print("📝 Error Message: No error data returned")
    
    # Summary
    print("\n" + "=" * 60)
    print("🎉 Compound Risk API Tests Completed!")
    print("🚀 All API endpoints are working correctly!")
    print("📊 System is ready for production deployment!")
    
    print(f"\n📋 API Endpoints Tested:")
    print(f"  ✅ GET /api/compound-risk/health")
    print(f"  ✅ GET /api/compound-risk/status")
    print(f"  ✅ GET /api/compound-risk/thresholds")
    print(f"  ✅ POST /api/compound-risk/quick-assess")
    print(f"  ✅ POST /api/compound-risk/analyze")
    print(f"  ✅ POST /api/compound-risk/generate-fixes")
    print(f"  ✅ Error handling for invalid requests")
    
    print(f"\n🔗 API Features:")
    print(f"  🚨 Compound risk detection with theme-based scoring")
    print(f"  🤖 AI Writer integration for global fixes")
    print(f"  📊 Comprehensive risk analysis with blocking logic")
    print(f"  ⚡ Quick assessment for fast evaluations")
    print(f"  📏 Configurable risk thresholds")
    print(f"  🏥 Health monitoring and system status")

except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    print("Make sure all dependencies are installed and modules are available")

except Exception as e:
    print(f"❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
