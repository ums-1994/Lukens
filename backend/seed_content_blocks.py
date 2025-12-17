import json
import os
from datetime import datetime

import psycopg2
from dotenv import load_dotenv

load_dotenv()

def get_db_config():
    """Get database configuration with SSL support for Render"""
    config = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': int(os.getenv('DB_PORT', 5432)),
        'database': os.getenv('DB_NAME', 'proposal_sow_builder'),
        'user': os.getenv('DB_USER', 'postgres'),
        'password': os.getenv('DB_PASSWORD', 'postgres'),
    }
    
    # Add SSL mode for external connections (like Render)
    db_sslmode = os.getenv('DB_SSLMODE')
    if db_sslmode:
        config['sslmode'] = db_sslmode
    elif 'render.com' in config['host'].lower():
        config['sslmode'] = 'require'
    
    return config

DATABASE_CONFIG = get_db_config()

LEGACY_LABELS_TO_REMOVE = [
    'Risk Management',
    'Company Profile',
]

CONTENT_BLOCKS = [
    {
        'key': 'company_profile_khonology_background',
        'label': 'Khonology Company Background',
        'category': 'Company Profile',
        'tags': ['company', 'profile', 'background', 'khonology'],
        'content': """
<h1>Our Purpose</h1>
<p>Khonology is a B-BBEE Level 2 South African digital services company. Khonology is a true African success story and has been the recipient of several awards. We provide world-class business solutions with the vision of empowering Africa. <br><br>
Khonology is who we are, technology is what we do, and Africa is whom we serve.</p>
<h2>Our Services</h2>
<p>Our service offering is focused on end-to-end application development, application support, testing, and strong data competency (data engineering and data analytics). Our vision is to become Africa's leading digital enabler. <br><br>
Khonology aspires to continue to rise into Africa’s leading data and digital enabler that empowers our continent’s businesses and people to unlock their full potential through technology.</p>
<h2>Recent Clients</h2>
<ul>
    <li>InfoCare</li>
    <li>Standard Bank</li>
    <li>Rand Merchant Bank</li>
    <li>Auditor General of South Africa</li>
    <li>SA Taxi Finance Company</li>
    <li>NatWest Bank (UK)</li>
    <li>ADB Safegate (Belgium)</li>
</ul>
<h2>Awards &amp; Recognition</h2>
<ul>
    <li>2023 TopCo Award for Best Fintech Company</li>
    <li>2023 Top Empowerment Digital Transformation Award of the Year</li>
    <li>2022 DataMagazine.UK Top 44 Most Innovative Cloud Data Services Start-ups &amp; Companies in South Africa</li>
    <li>2022 DataMagazine.UK Top 14 Most Innovative Cloud Data Services Start-ups &amp; Companies in Johannesburg</li>
    <li>2022/23 Prestige Awards: Digital Services Company of the Year</li>
</ul>
<h2>Digital Products Delivered</h2>
<h3>PowerPulse</h3>
<p>A digital platform connecting accredited energy solution providers to deliver cost-saving and sustainable energy solutions for businesses and homes.</p>
<h3>CreditConnect</h3>
<p>A digital bond market platform offering institutional investors and issuers an intelligent, transparent, and efficient trading experience.</p>
<h3>Automated Term Sheet</h3>
<p>A digital term sheet generation platform enabling RMB to standardise loan terms, accelerate deal processing, and reduce human error.</p>
        """,
    },
    {
        'key': 'team_khonology_leadership_bios',
        'label': 'Khonology Leadership Team',
        'category': 'Team',
        'tags': ['team', 'bios', 'leadership', 'khonology'],
        'content': """
<h1>Organisational Structure</h1>
<h2>Leadership</h2>
<h3>Dapo Adeyemo – CEO – Co-founder</h3>
<p>Dapo leads the strategic direction of Khonology and oversees company vision and growth.</p>
<h3>Mosa Nyamande – Head of Delivery – Co-founder</h3>
<p>Mosa drives delivery excellence, project execution, and operational transformation across engagements.</p>
<h3>Africa Nkosi – Sales &amp; Marketing – Co-founder</h3>
<p>Africa leads business development, client engagement, and market positioning initiatives.</p>
<h3>Michael Roberts – Chairman – Co-founder</h3>
<p>Michael provides governance oversight, strategic leadership, and senior advisory guidance.</p>
<h2>Management Team</h2>
<h3>Lezanne Kruger – Finance Manager</h3>
<p>Responsible for financial operations, accounting, and commercial management.</p>
<h3>Lerato Thekiso – Legal Partner</h3>
<p>Supports Khonology's legal compliance, contract frameworks, and governance operations.</p>
        """,
    },
    {
        'key': 'case_study_powerpulse',
        'label': 'Case Study: PowerPulse Energy Platform',
        'category': 'Case Studies',
        'tags': ['case', 'energy', 'marketplace', 'powerpulse'],
        'content': """
<h1>Digital Energy Marketplace Transformation</h1>
<p>Khonology played a critical role in the modernisation of PowerPulse, a digital marketplace enabling customers to access accredited energy solution providers.</p>
<h2>What We Delivered</h2>
<ul>
    <li>Digital workflow automation</li>
    <li>Supplier onboarding &amp; governance</li>
    <li>Client energy assessment journeys</li>
    <li>Performance dashboards &amp; analytics</li>
</ul>
<h2>Impact</h2>
<ul>
    <li>Accelerated go-live by 42%</li>
    <li>Reduced operational bottlenecks</li>
    <li>Improved customer energy cost decisioning</li>
</ul>
        """,
    },
    {
        'key': 'case_study_creditconnect',
        'label': 'Case Study: CreditConnect Bond Trading Platform',
        'category': 'Case Studies',
        'tags': ['case', 'finance', 'creditconnect', 'trading'],
        'content': """
<h1>Institutional Bond Trading Modernisation</h1>
<p>Khonology delivered CreditConnect, a digital trading interface for institutional investors and issuers seeking improved transparency in bond markets.</p>
<h2>Core Features Developed</h2>
<ul>
    <li>Real-time credit pricing</li>
    <li>Deal room negotiation workflows</li>
    <li>Automated issuance orchestration</li>
</ul>
<h2>Impact</h2>
<ul>
    <li>Shortened deal cycle times</li>
    <li>Improved liquidity insights</li>
    <li>Digitised historically manual bond processes</li>
</ul>
        """,
    },
    {
        'key': 'case_study_term_sheet_rmb',
        'label': 'Case Study: Automated Term Sheet (RMB)',
        'category': 'Case Studies',
        'tags': ['case', 'rmb', 'loans', 'automation'],
        'content': """
<h1>Loan Term Sheet Automation</h1>
<p>Working with Rand Merchant Bank (RMB), Khonology created an automated term sheet generator that standardised lending structures.</p>
<h2>Outcome</h2>
<ul>
    <li>Accelerated deal generation speed</li>
    <li>Reduced legal review rework</li>
    <li>Decreased human error in loan terms</li>
</ul>
        """,
    },
    {
        'key': 'methodology_discovery',
        'label': 'Discovery & Requirements',
        'category': 'Methodology',
        'tags': ['methodology', 'discovery', 'analysis'],
        'content': """
<h1>Discovery &amp; Requirements</h1>
<p>In the Discovery phase, Khonology engages with stakeholders to validate objectives, define success metrics, and understand current-state challenges.</p>
<h2>Activities</h2>
<ul>
    <li>Stakeholder interviews</li>
    <li>Process mapping</li>
    <li>Requirements documentation</li>
    <li>Solution feasibility analysis</li>
</ul>
        """,
    },
    {
        'key': 'methodology_build',
        'label': 'Build & Implementation',
        'category': 'Methodology',
        'tags': ['delivery', 'build', 'methodology'],
        'content': """
<h1>Build &amp; Implementation</h1>
<p>Khonology delivers solutions using Agile, ensuring rapid iterations, continuous feedback, and predictable delivery timelines.</p>
<h2>Activities</h2>
<ul>
    <li>Architecture and design</li>
    <li>Development and integration</li>
    <li>Data migration and enrichment</li>
    <li>User acceptance testing preparation</li>
</ul>
        """,
    },
    {
        'key': 'methodology_quality',
        'label': 'Quality Assurance',
        'category': 'Methodology',
        'tags': ['qa', 'testing', 'quality'],
        'content': """
<h1>Quality Assurance</h1>
<p>Khonology applies rigorous quality standards to ensure solutions meet functional and non-functional requirements.</p>
<h2>Testing Coverage</h2>
<ul>
    <li>Functional testing</li>
    <li>Performance validation</li>
    <li>Integration testing</li>
    <li>User acceptance testing (UAT)</li>
</ul>
        """,
    },
    {
        'key': 'methodology_golive',
        'label': 'Go-Live & Support',
        'category': 'Methodology',
        'tags': ['golive', 'support', 'methodology'],
        'content': """
<h1>Go-Live &amp; Support</h1>
<p>Khonology ensures a smooth production rollout supported by hypercare and operational enablement.</p>
<h2>Includes</h2>
<ul>
    <li>Release management</li>
    <li>Post-deployment support</li>
    <li>Knowledge transfer</li>
    <li>Operational handover</li>
</ul>
        """,
    },
    {
        'key': 'template_proposal_cover',
        'label': 'Proposal Cover',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'cover'],
        'content': """
<div style="padding:40px; text-align:center;">
    <h1 style="font-size:40px; font-weight:700;">Khonology Proposal</h1>
    <p style="font-size:18px;">Empowering Africa through Technology</p>
    <div style="margin-top:50px;">
        <p><strong>Client:</strong> {{client_name}}</p>
        <p><strong>Date:</strong> {{date}}</p>
        <p><strong>Prepared By:</strong> Khonology</p>
    </div>
</div>
        """,
    },
    {
        'key': 'template_sow_header',
        'label': 'SOW Header',
        'category': 'Templates',
        'tags': ['template', 'sow', 'header'],
        'content': """
<h1>Statement of Work</h1>
<p>This Statement of Work outlines the scope, deliverables, responsibilities, and timelines for the engagement between Khonology and {{client_name}}.</p>
        """,
    },
    {
        'key': 'template_rfi_header',
        'label': 'RFI Response Header',
        'category': 'Templates',
        'tags': ['template', 'rfi', 'header'],
        'content': """
<h1>RFI Response</h1>
<p>Khonology appreciates the opportunity to respond to your Request for Information. This document provides a structured overview of our capabilities, experience, and delivery approach.</p>
        """,
    },
    {
        'key': 'assumptions_standard',
        'label': 'Standard Project Assumptions',
        'category': 'Assumptions',
        'tags': ['assumptions', 'project', 'standards'],
        'content': """
<h1>Project Assumptions</h1>
<ul>
    <li>Client resources will be available as needed.</li>
    <li>All milestones are dependent on timely client feedback.</li>
    <li>Dependencies on external vendors are managed by the client.</li>
    <li>Scope changes may impact timelines and commercial estimates.</li>
</ul>
        """,
    },
    {
        'key': 'risks_standard',
        'label': 'Standard Delivery Risks',
        'category': 'Risks',
        'tags': ['risks', 'delivery', 'project'],
        'content': """
<h1>Project Risks</h1>
<ul>
    <li>Delays in decision-making may impact timelines.</li>
    <li>Third-party dependency failures can cause bottlenecks.</li>
    <li>Scope ambiguity increases rework risk.</li>
    <li>Insufficient user adoption may affect long-term value.</li>
</ul>
        """,
    },
    {
        'key': 'pricing_commercial_terms',
        'label': 'Commercial Terms',
        'category': 'Pricing',
        'tags': ['pricing', 'commercial', 'terms'],
        'content': """
<h1>Commercial Terms</h1>
<ul>
    <li>Rates exclude VAT unless otherwise stated.</li>
    <li>Travel is charged at cost if required.</li>
    <li>Invoices are payable within 30 days.</li>
    <li>Changes to scope may result in revised costing.</li>
</ul>
        """,
    },
    # ============================================================
    # FULL PROPOSAL TEMPLATE MODULES
    # ============================================================
    {
        'key': 'template_proposal_module_1_cover',
        'label': 'Proposal Template - Module 1: Cover Page',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'cover', 'module'],
        'content': """
<h1>Consulting & Technology Delivery Proposal</h1>
<div style="margin: 30px 0;">
    <p><strong>Client:</strong> {{Client Name}}</p>
    <p><strong>Prepared For:</strong> {{Client Stakeholder}}</p>
    <p><strong>Prepared By:</strong> Khonology Team</p>
    <p><strong>Date:</strong> {{Date}}</p>
</div>
<div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
    <h2>Cover Summary</h2>
    <p>Khonology proposes a customised consulting and technology delivery engagement to support {{Client Name}} in achieving operational excellence, digital transformation, and data-driven decision-making.</p>
</div>
        """,
    },
    {
        'key': 'template_proposal_module_2_executive_summary',
        'label': 'Proposal Template - Module 2: Executive Summary',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'executive', 'summary', 'module'],
        'content': """
<h1>Executive Summary</h1>
<h2>Purpose of This Proposal</h2>
<p>This proposal outlines Khonology's recommended approach, delivery methodology, timelines, governance, and expected outcomes for the {{Project Name}} initiative.</p>

<h2>What We Bring</h2>
<ul>
    <li>Strong expertise in digital transformation and enterprise delivery</li>
    <li>Deep experience in banking, insurance, ESG reporting, and financial services</li>
    <li>Proven capability across data engineering, cloud, automation, and governance</li>
    <li>A people-first consulting culture focused on delivery excellence</li>
</ul>

<h2>Expected Outcomes</h2>
<ul>
    <li>Streamlined processes</li>
    <li>Robust governance</li>
    <li>Improved operational visibility</li>
    <li>Higher efficiency and reduced risk</li>
    <li>A scalable delivery architecture to support strategic goals</li>
</ul>
        """,
    },
    {
        'key': 'template_proposal_module_3_problem_statement',
        'label': 'Proposal Template - Module 3: Problem Statement',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'problem', 'statement', 'module'],
        'content': """
<h1>Problem Statement</h1>
<h2>Current State Challenges</h2>
<p>{{Client Name}} is experiencing the following challenges:</p>
<ul>
    <li>Limited visibility into operational performance</li>
    <li>Manual processes creating inefficiencies</li>
    <li>High reporting complexity</li>
    <li>Lack of integrated workflows or automated governance</li>
    <li>Upcoming deadlines causing pressure on compliance and reporting</li>
</ul>

<h2>Opportunity</h2>
<p>With a modern delivery framework, workflows, and reporting structures, {{Client Name}} can unlock operational excellence and achieve strategic growth objectives.</p>
        """,
    },
    {
        'key': 'template_proposal_module_4_scope_of_work',
        'label': 'Proposal Template - Module 4: Scope of Work',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'scope', 'work', 'module'],
        'content': """
<h1>Scope of Work</h1>
<p>Khonology proposes the following Scope of Work:</p>

<h2>1. Discovery & Assessment</h2>
<ul>
    <li>Requirements gathering</li>
    <li>Stakeholder workshops</li>
    <li>Current-state assessment</li>
</ul>

<h2>2. Solution Design</h2>
<ul>
    <li>Technical architecture</li>
    <li>Workflow design</li>
    <li>Data models and integration approach</li>
</ul>

<h2>3. Build & Configuration</h2>
<ul>
    <li>Product configuration</li>
    <li>UI/UX setup</li>
    <li>Data pipeline setup</li>
    <li>Reporting components</li>
</ul>

<h2>4. Implementation & Testing</h2>
<ul>
    <li>UAT support</li>
    <li>QA testing</li>
    <li>Release preparation</li>
</ul>

<h2>5. Training & Knowledge Transfer</h2>
<ul>
    <li>System training</li>
    <li>Documentation handover</li>
</ul>
        """,
    },
    {
        'key': 'template_proposal_module_5_project_timeline',
        'label': 'Proposal Template - Module 5: Project Timeline',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'timeline', 'project', 'module'],
        'content': """
<h1>Project Timeline</h1>
<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
    <thead>
        <tr style="background: #f5f5f5;">
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Phase</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Duration</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Description</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Discovery</strong></td>
            <td style="padding: 12px; border: 1px solid #ddd;">1–2 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Requirements & assessment</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Design</strong></td>
            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Architecture & workflow design</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Build</strong></td>
            <td style="padding: 12px; border: 1px solid #ddd;">2–4 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Development & configuration</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;"><strong>UAT</strong></td>
            <td style="padding: 12px; border: 1px solid #ddd;">1–2 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Testing & validation</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Go-Live</strong></td>
            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Deployment & full handover</td>
        </tr>
    </tbody>
</table>
        """,
    },
    {
        'key': 'template_proposal_module_6_team_bios',
        'label': 'Proposal Template - Module 6: Team & Bios',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'team', 'bios', 'module'],
        'content': """
<h1>Team & Bios</h1>

<h2>Engagement Lead – {{Name}}</h2>
<p>Responsible for oversight, governance, and stakeholder engagement.</p>

<h2>Technical Lead – {{Name}}</h2>
<p>Owns architecture, technical design, integration, and delivery.</p>

<h2>Business Analyst – {{Name}}</h2>
<p>Facilitates workshops, documents requirements, and translations.</p>

<h2>QA/Test Analyst – {{Name}}</h2>
<p>Ensures solution quality and manages UAT cycles.</p>
        """,
    },
    {
        'key': 'template_proposal_module_7_delivery_approach',
        'label': 'Proposal Template - Module 7: Delivery Approach',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'delivery', 'approach', 'module'],
        'content': """
<h1>Delivery Approach</h1>
<p>Khonology follows a structured delivery methodology combining Agile, Lean, and governance best practices.</p>

<h2>Key Features</h2>
<ul>
    <li>Iterative sprint cycles</li>
    <li>Frequent stakeholder engagement</li>
    <li>Automated governance checkpoints</li>
    <li>Traceability from requirements → delivery → reporting</li>
</ul>
        """,
    },
    {
        'key': 'template_proposal_module_8_pricing_table',
        'label': 'Proposal Template - Module 8: Pricing Table',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'pricing', 'table', 'module'],
        'content': """
<h1>Pricing Table</h1>
<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
    <thead>
        <tr style="background: #f5f5f5;">
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Service Component</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Quantity</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Rate</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Total</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Assessment & Discovery</td>
            <td style="padding: 12px; border: 1px solid #ddd;">2 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Build & Configuration</td>
            <td style="padding: 12px; border: 1px solid #ddd;">4 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">UAT & Release</td>
            <td style="padding: 12px; border: 1px solid #ddd;">2 Weeks</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Training & Handover</td>
            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>
            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>
        </tr>
    </tbody>
</table>
<blockquote style="background: #f9f9f9; border-left: 4px solid #E9293A; padding: 15px; margin: 20px 0;">
    <p><strong>Total Estimated Cost:</strong> R {{Total}}</p>
    <p style="margin: 5px 0 0 0; font-size: 14px; color: #666;"><em>Final costs will be confirmed after detailed scoping.</em></p>
</blockquote>
        """,
    },
    {
        'key': 'template_proposal_module_9_risks_mitigation',
        'label': 'Proposal Template - Module 9: Risks & Mitigation',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'risks', 'mitigation', 'module'],
        'content': """
<h1>Risks & Mitigation</h1>
<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
    <thead>
        <tr style="background: #f5f5f5;">
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Risk</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Impact</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Likelihood</th>
            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Mitigation</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Limited stakeholder availability</td>
            <td style="padding: 12px; border: 1px solid #ddd;">High</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Align early calendars</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Data quality issues</td>
            <td style="padding: 12px; border: 1px solid #ddd;">High</td>
            <td style="padding: 12px; border: 1px solid #ddd;">High</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Early validation</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Changing scope</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Governance checkpoints</td>
        </tr>
        <tr>
            <td style="padding: 12px; border: 1px solid #ddd;">Lack of documentation</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>
            <td style="padding: 12px; border: 1px solid #ddd;">High</td>
            <td style="padding: 12px; border: 1px solid #ddd;">Early analysis and mapping</td>
        </tr>
    </tbody>
</table>
        """,
    },
    {
        'key': 'template_proposal_module_10_governance_model',
        'label': 'Proposal Template - Module 10: Governance Model',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'governance', 'model', 'module'],
        'content': """
<h1>Governance Model</h1>

<h2>Governance Structure</h2>
<ul>
    <li>Engagement Lead</li>
    <li>Product Owner (Client)</li>
    <li>Delivery Team</li>
    <li>QA & Compliance Group</li>
</ul>

<h2>Tools</h2>
<ul>
    <li>Jira</li>
    <li>Teams/Email</li>
    <li>Automated reporting dashboard</li>
</ul>

<h2>Cadence</h2>
<ul>
    <li>Daily standups</li>
    <li>Weekly status updates</li>
    <li>Monthly executive review</li>
</ul>
        """,
    },
    {
        'key': 'template_proposal_module_11_company_profile',
        'label': 'Proposal Template - Module 11: Company Profile',
        'category': 'Templates',
        'tags': ['template', 'proposal', 'company', 'profile', 'module'],
        'content': """
<h1>Appendix – Company Profile</h1>

<h2>About Khonology</h2>
<p>Khonology is a South African-based digital consulting and technology delivery company specialising in:</p>
<ul>
    <li>Enterprise automation</li>
    <li>Digital transformation</li>
    <li>ESG reporting</li>
    <li>Data engineering & cloud</li>
    <li>Business analysis and enterprise delivery</li>
</ul>

<p>We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.</p>
        """,
    },
]


def build_content(block: dict) -> str:
    tags = block.get('tags') or []
    tag_comment = f"<!-- tags: {json.dumps(tags)} -->\n" if tags else ""
    return f"{tag_comment}{block['content'].strip()}"


def seed_content_blocks():
    print("🚀 Seeding Khonology content blocks...")
    conn = psycopg2.connect(**DATABASE_CONFIG)
    cursor = conn.cursor()

    if LEGACY_LABELS_TO_REMOVE:
        cursor.execute(
            "DELETE FROM content WHERE label = ANY(%s)",
            (LEGACY_LABELS_TO_REMOVE,),
        )
        removed = cursor.rowcount
        if removed:
            print(f"🧹 Removed {removed} legacy content block(s)")

    inserted = 0
    for block in CONTENT_BLOCKS:
        content_html = build_content(block)
        now = datetime.utcnow()
        cursor.execute(
            """
            INSERT INTO content (key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at, is_deleted)
            VALUES (%s, %s, %s, %s, FALSE, NULL, NULL, %s, %s, FALSE)
            ON CONFLICT (key) DO UPDATE
            SET label = EXCLUDED.label,
                content = EXCLUDED.content,
                category = EXCLUDED.category,
                updated_at = EXCLUDED.updated_at,
                is_deleted = FALSE
            """,
            (
                block['key'],
                block['label'],
                content_html,
                block['category'],
                now,
                now,
            ),
        )
        inserted += 1
        print(f"   ✅ Seeded: {block['label']} ({block['category']})")

    conn.commit()
    cursor.close()
    conn.close()
    print(f"\n🎉 Done! Seeded {inserted} content blocks.")
    print("💡 Tip: Restart the backend or refresh your Content Library UI to see the new entries.")


if __name__ == "__main__":
    try:
        seed_content_blocks()
    except Exception as exc:
        print(f"❌ Failed to seed content blocks: {exc}")
        print("Ensure your PostgreSQL database is reachable and environment variables are set.")

