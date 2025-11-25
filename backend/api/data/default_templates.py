"""
Default proposal templates and modules used to seed the database.
"""

DEFAULT_TEMPLATES = [
    {
        "template_key": "proposal_standard",
        "name": "Consulting & Technology Delivery Proposal",
        "description": "11-section proposal covering discovery through governance.",
        "template_type": "proposal",
        "category": "Standard",
        "status": "approved",
        "is_public": True,
        "is_approved": True,
        "version": 1,
        "dynamic_fields": [
            {"field_key": "client_name", "field_name": "Client Name"},
            {"field_key": "project_name", "field_name": "Project Name"},
            {"field_key": "engagement_lead", "field_name": "Engagement Lead"},
            {"field_key": "date", "field_name": "Date"},
        ],
        "sections": [
            {
                "key": "executive_summary",
                "title": "Executive Summary",
                "required": True,
                "body": (
                    "This proposal outlines Khonology's recommended approach for {{project_name}} "
                    "at {{client_name}}. We combine transformation expertise, delivery rigor, and "
                    "governance discipline to accelerate outcomes."
                ),
            },
            {
                "key": "company_profile",
                "title": "Company Profile",
                "required": True,
                "body": (
                    "Khonology is a South African consulting studio delivering digital products, "
                    "AI-enabled workflows, and managed services across the continent."
                ),
            },
            {
                "key": "scope_deliverables",
                "title": "Scope & Deliverables",
                "required": True,
                "body": (
                    "Phase 1 – Discovery & Blueprinting\n"
                    "Phase 2 – Build & Configure\n"
                    "Phase 3 – Deploy, Train, and Transition."
                ),
            },
            {
                "key": "delivery_approach",
                "title": "Delivery Approach",
                "required": False,
                "body": (
                    "We run two-week sprints with embedded governance gates, integrating Khonology "
                    "and client squads for transparent delivery."
                ),
            },
            {
                "key": "case_studies",
                "title": "Case Studies",
                "required": False,
                "body": (
                    "Recent references include:\n"
                    "• Digital onboarding platform for Tier-1 bank\n"
                    "• ESG automation for a multinational mining group."
                ),
            },
            {
                "key": "team_bios",
                "title": "Team Bios",
                "required": False,
                "body": (
                    "Our core team includes an Engagement Lead, Technical Lead, Business Analyst, "
                    "and QA Specialist with combined 45+ years of experience."
                ),
            },
            {
                "key": "assumptions_risks",
                "title": "Assumptions & Risks",
                "required": False,
                "body": (
                    "Assumptions: Client SMEs available weekly, environments provisioned on time.\n"
                    "Risks: Scope expansion, delayed approvals, data quality challenges."
                ),
            },
            {
                "key": "terms_conditions",
                "title": "Terms & Conditions",
                "required": True,
                "body": (
                    "Engagement governed by the Khonology MSA. Fees payable within 30 days of invoice. "
                    "All pricing denominated in ZAR."
                ),
            },
        ],
    },
    {
        "template_key": "sow_modernization",
        "name": "Statement of Work – Modernization Sprint",
        "description": "Structured SOW for short, high-impact modernization engagements.",
        "template_type": "sow",
        "category": "SOW",
        "status": "approved",
        "is_public": True,
        "is_approved": True,
        "version": 1,
        "dynamic_fields": [
            {"field_key": "client_name", "field_name": "Client Name"},
            {"field_key": "workstream", "field_name": "Workstream"},
            {"field_key": "start_date", "field_name": "Start Date"},
            {"field_key": "end_date", "field_name": "End Date"},
        ],
        "sections": [
            {
                "key": "project_overview",
                "title": "Project Overview",
                "required": True,
                "body": (
                    "Khonology will deliver a focused {{workstream}} modernization initiative for "
                    "{{client_name}} between {{start_date}} and {{end_date}}."
                ),
            },
            {
                "key": "deliverables",
                "title": "Deliverables",
                "required": True,
                "body": (
                    "1. Discovery findings & current-state map\n"
                    "2. Target architecture & backlog\n"
                    "3. Pilot or MVP deployment\n"
                    "4. Transition playbook."
                ),
            },
            {
                "key": "timeline",
                "title": "Timeline & Milestones",
                "required": True,
                "body": (
                    "Week 1 – Discovery\n"
                    "Week 2 – Solution design\n"
                    "Weeks 3-5 – Build & iterate\n"
                    "Week 6 – Go-live & handover."
                ),
            },
            {
                "key": "pricing_budget",
                "title": "Pricing & Investment",
                "required": True,
                "body": (
                    "Total professional services investment: R 1,250,000 (ex VAT).\n"
                    "Invoicing: 40% mobilization, 40% mid-sprint, 20% on completion."
                ),
            },
            {
                "key": "assumptions_risks",
                "title": "Engagement Assumptions",
                "required": True,
                "body": (
                    "Client to provide product owner availability, integration access, and "
                    "decision turnarounds within 3 business days."
                ),
            },
            {
                "key": "terms_conditions",
                "title": "Commercial Terms",
                "required": True,
                "body": (
                    "MSA terms apply. Travel & expenses billed at cost. Additional scope "
                    "managed via change control."
                ),
            },
        ],
    },
]
