import json
import os
from datetime import datetime

import psycopg2
from dotenv import load_dotenv

load_dotenv()

DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', 5432),
    'database': os.getenv('DB_NAME', 'khonology'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres'),
}

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
                updated_at = EXCLUDED.updated_at
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

