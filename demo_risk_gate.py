#!/usr/bin/env python3
"""
Risk Gate Demo Script
Demonstrates the complete risk analysis pipeline
"""

import sys
import os

# Add the risk_gate directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'risk_gate'))

from risk_gate import RiskGate, analyze_proposal


def demo_risk_analysis():
    """Demonstrate risk analysis with sample proposals"""
    
    print("🚀 Risk Gate Demo - Compound Risk Analysis System")
    print("=" * 60)
    
    # Sample proposals for testing
    sample_proposals = {
        "good_proposal": """
EXECUTIVE SUMMARY
This proposal outlines our comprehensive approach to developing a custom e-commerce platform for XYZ Corporation. Our solution includes a fully responsive web application with advanced features including user authentication, payment processing, inventory management, and analytics dashboard.

SCOPE OF WORK
The project will be delivered in 4 phases:
1. Requirements gathering and UI/UX design (2 weeks)
2. Frontend development (4 weeks)  
3. Backend development and API integration (3 weeks)
4. Testing, deployment, and training (1 week)

The platform will include:
- User registration and authentication system
- Product catalog with search and filtering
- Shopping cart and checkout process
- Payment gateway integration (Stripe/PayPal)
- Admin dashboard for inventory management
- Analytics and reporting module
- Mobile-responsive design

DELIVERABLES
1. Fully functional e-commerce web application
2. Source code and documentation
3. User manual and admin guide
4. Testing reports and quality assurance documentation
5. Deployment and setup guide
6. 3 months post-launch support

TIMELINE
Total project duration: 10 weeks
- Week 1-2: Design and requirements
- Week 3-6: Development
- Week 7-8: Testing and integration
- Week 9: Deployment
- Week 10: Training and handover

BUDGET
Phase 1 - Design: $8,000
Phase 2 - Frontend Development: $16,000
Phase 3 - Backend Development: $14,000
Phase 4 - Testing & Deployment: $6,000
Contingency (10%): $4,400
Total Project Cost: $48,400

TEAM
John Smith - Project Manager (12 years experience, PMP certified)
Jane Doe - Lead Developer (8 years experience, full-stack expertise)
Mike Johnson - UI/UX Designer (6 years experience, e-commerce specialist)
Sarah Wilson - QA Engineer (5 years experience, automated testing)

ASSUMPTIONS
- Client will provide timely feedback and approvals
- Required APIs and third-party services will be accessible
- Content and product data will be provided by client
- Testing environment will be available
- Project scope will remain stable without major changes

INTELLECTUAL PROPERTY
All custom code and deliverables become client property upon final payment. We retain rights to reusable components and frameworks not specific to this project.

PAYMENT TERMS
- 30% upon contract signing ($14,520)
- 40% upon milestone completion (Phase 2) ($19,360)
- 30% upon final delivery and acceptance ($14,520)

TERMINATION
Either party may terminate with 14 days written notice. Client pays for work completed up to termination date.
        """,
        
        "risky_proposal": """
basic proposal

we can do the project for you. our team has experience. timeline will be a few weeks maybe. budget is reasonable price.

we will deliver stuff when done. payment terms are flexible.

contact us for more info.
        """,
        
        "medium_proposal": """
PROJECT PROPOSAL

OVERVIEW
We propose to develop a mobile application for your business.

SCOPE
The app will include basic features and functionality.

DELIVERABLES
- Mobile application
- Documentation

TIMELINE
The project will take approximately 2-3 months to complete.

BUDGET
Cost is around $25,000.

TEAM
Our development team has relevant experience.

ASSUMPTIONS
- Client cooperation
- Clear requirements
        """
    }
    
    # Initialize Risk Gate
    print("🔧 Initializing Risk Gate system...")
    risk_gate = RiskGate()
    
    # Check system status
    status = risk_gate.get_system_status()
    print(f"✅ System Status: {status['system_status']}")
    print(f"📁 Templates Loaded: {status['templates_loaded']}")
    print(f"🤖 Vector Store Available: {status['vector_store_available']}")
    print()
    
    # Analyze each sample proposal
    for name, proposal_text in sample_proposals.items():
        print(f"📋 Analyzing: {name.replace('_', ' ').title()}")
        print("-" * 40)
        
        try:
            # Quick assessment first
            quick_result = risk_gate.get_quick_risk_assessment(proposal_text)
            print(f"⚡ Quick Assessment: {quick_result['estimated_risk'].title()} Risk")
            print(f"📊 Completeness: {quick_result['completeness_score']:.1%}")
            print(f"📝 Word Count: {quick_result['word_count']}")
            
            if quick_result['missing_elements']:
                print(f"⚠️  Missing: {', '.join(quick_result['missing_elements'])}")
            
            print()
            
            # Full analysis
            print("🔍 Running full risk analysis...")
            result = risk_gate.analyze_proposal(proposal_text)
            
            if result['success']:
                print(f"🎯 Risk Score: {result['risk_score']:.2f}")
                print(f"📈 Risk Level: {result['risk_level'].title()}")
                print(f"🚦 Decision: {result['decision'].replace('_', ' ').title()}")
                print(f"✅ Compound Risk: {'Yes' if result['compound_risk'] else 'No'}")
                
                # Show key issues
                issues = []
                if result['missing_sections']:
                    issues.append(f"Missing sections: {len(result['missing_sections'])}")
                if result['altered_clauses']:
                    issues.append(f"Altered clauses: {len(result['altered_clauses'])}")
                if result['weak_areas']:
                    issues.append(f"Weak areas: {len(result['weak_areas'])}")
                if result['ai_semantic_flags']:
                    issues.append(f"Semantic issues: {len(result['ai_semantic_flags'])}")
                
                if issues:
                    print(f"🔍 Issues Found: {', '.join(issues)}")
                
                # Show summary
                print("\n📄 Summary:")
                print(result['summary'])
                
                # Show top recommendations
                if result['recommendations']:
                    print(f"\n💡 Top Recommendations:")
                    for i, rec in enumerate(result['recommendations'][:3], 1):
                        print(f"  {i}. {rec}")
                
            else:
                print(f"❌ Analysis failed: {result['error']}")
            
        except Exception as e:
            print(f"❌ Error analyzing {name}: {str(e)}")
        
        print("\n" + "=" * 60 + "\n")
    
    print("🎉 Demo completed!")
    print("\nTo use the Risk Gate in your own code:")
    print("```python")
    print("from risk_gate import analyze_proposal")
    print("result = analyze_proposal('your proposal text here')")
    print("print(f'Risk Score: {result[\"risk_score\"]:.2f}')")
    print("print(f'Compound Risk: {result[\"compound_risk\"]}')")
    print("```")


if __name__ == "__main__":
    demo_risk_analysis()
