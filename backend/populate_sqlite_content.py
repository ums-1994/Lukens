"""
Populate SQLite content_blocks with basic Khonology content
"""
import sqlite3
import os
from datetime import datetime

BASE_DIR = os.path.dirname(__file__)
SQLITE_PATH = os.path.join(BASE_DIR, "content.db")

def now_iso():
    return datetime.utcnow().isoformat() + "Z"

def create_table():
    """Create content_blocks table if it doesn't exist"""
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS content_blocks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            label TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)
    
    conn.commit()
    conn.close()

def populate_content():
    """Populate content_blocks with Khonology-specific content"""
    
    content_blocks = [
        {
            "key": "company_name",
            "label": "Company Name",
            "content": "Khonology"
        },
        {
            "key": "company_tagline",
            "label": "Company Tagline",
            "content": "Transforming Business Through Technology"
        },
        {
            "key": "company_address",
            "label": "Company Address",
            "content": "123 Innovation Drive, Suite 500\nSan Francisco, CA 94105\nUnited States"
        },
        {
            "key": "company_phone",
            "label": "Company Phone",
            "content": "+1 (555) 123-4567"
        },
        {
            "key": "company_email",
            "label": "Company Email",
            "content": "info@khonology.com"
        },
        {
            "key": "company_website",
            "label": "Company Website",
            "content": "www.khonology.com"
        },
        {
            "key": "terms",
            "label": "Standard Terms & Conditions",
            "content": """TERMS AND CONDITIONS

1. ENGAGEMENT TERMS
This Statement of Work (SOW) is governed by the Master Services Agreement (MSA) between Khonology and the Client.

2. PAYMENT TERMS
- Invoices are due within 30 days of receipt
- Late payments subject to 1.5% monthly interest
- All amounts in USD unless otherwise specified

3. INTELLECTUAL PROPERTY
- Client retains ownership of pre-existing IP
- Custom deliverables become Client property upon final payment
- Khonology retains ownership of frameworks and methodologies

4. CONFIDENTIALITY
Both parties agree to maintain confidentiality of proprietary information for 3 years following engagement completion.

5. WARRANTIES
Services will be performed in a professional manner consistent with industry standards. 90-day warranty on software deliverables.

6. LIMITATION OF LIABILITY
Khonology's total liability shall not exceed total fees paid. Neither party liable for indirect or consequential damages.

7. CHANGE MANAGEMENT
Scope changes require written approval via formal change request process.

8. TERMINATION
Either party may terminate with 30 days written notice. Client responsible for payment through termination date."""
        },
        {
            "key": "privacy_policy",
            "label": "Privacy Policy",
            "content": """PRIVACY POLICY

Khonology is committed to protecting your privacy and handling your data in an open and transparent manner.

DATA COLLECTION
We collect information necessary to provide our services, including contact details, project requirements, and business information.

DATA USAGE
Your data is used solely for delivering services, communication, and improving our offerings. We do not sell or share your data with third parties without consent.

DATA SECURITY
We implement industry-standard security measures including encryption, access controls, and regular security audits.

DATA RETENTION
We retain data for the duration of our engagement and as required by law or contractual obligations.

YOUR RIGHTS
You have the right to access, correct, or delete your personal data. Contact us at privacy@khonology.com."""
        },
        {
            "key": "signature_block",
            "label": "Signature Block",
            "content": """ACCEPTANCE

By signing below, both parties agree to the terms outlined in this proposal.

KHONOLOGY:

_______________________________
Name: [Khonology Representative]
Title: [Title]
Date: _______________


CLIENT:

_______________________________
Name: [Client Representative]
Title: [Title]
Date: _______________"""
        },
        {
            "key": "confidentiality_clause",
            "label": "Confidentiality Clause",
            "content": """CONFIDENTIALITY

Both parties acknowledge that during the course of this engagement, they may have access to confidential information including but not limited to:
- Business strategies and plans
- Technical specifications and designs
- Financial information
- Customer data
- Proprietary methodologies

Each party agrees to:
1. Maintain strict confidentiality of all such information
2. Use confidential information solely for the purpose of this engagement
3. Not disclose confidential information to third parties without written consent
4. Return or destroy confidential information upon request or engagement completion

This obligation survives for three (3) years following the termination of this agreement."""
        },
        {
            "key": "warranty_clause",
            "label": "Warranty Clause",
            "content": """WARRANTY

Khonology warrants that:

1. PROFESSIONAL SERVICES
All services will be performed in a professional and workmanlike manner consistent with industry standards.

2. SOFTWARE DELIVERABLES
Custom software deliverables will be free from material defects for ninety (90) days following delivery.

3. COMPLIANCE
Services will comply with applicable laws and regulations.

4. AUTHORITY
Khonology has full authority to enter into this agreement and perform the services.

LIMITATION: THE WARRANTIES SET FORTH ABOVE ARE EXCLUSIVE AND IN LIEU OF ALL OTHER WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE."""
        },
        {
            "key": "payment_terms",
            "label": "Payment Terms",
            "content": """PAYMENT TERMS

1. INVOICING
Invoices will be issued according to the payment schedule outlined in the Investment section of this proposal.

2. DUE DATE
Payment is due within thirty (30) days of invoice date.

3. LATE PAYMENT
Late payments will incur interest charges of 1.5% per month (18% per annum) or the maximum rate permitted by law, whichever is less.

4. CURRENCY
All fees are quoted and payable in United States Dollars (USD) unless otherwise specified.

5. EXPENSES
Reasonable travel and other expenses will be billed at cost with prior Client approval.

6. TAXES
Fees are exclusive of all applicable taxes. Client is responsible for all sales, use, and excise taxes."""
        },
        {
            "key": "change_control",
            "label": "Change Control Process",
            "content": """CHANGE CONTROL PROCESS

Changes to project scope, timeline, or budget must follow this formal process:

1. CHANGE REQUEST SUBMISSION
Either party may submit a written change request describing:
- Proposed change and rationale
- Impact on scope, timeline, and budget
- Priority and urgency

2. IMPACT ASSESSMENT
Khonology will assess the change request within 5 business days, providing:
- Detailed impact analysis
- Revised timeline and budget
- Implementation approach

3. APPROVAL
Both parties must provide written approval before implementation. Changes are not authorized until formal approval is received.

4. IMPLEMENTATION
Approved changes will be incorporated into the project plan and tracked separately.

5. DOCUMENTATION
All change requests and approvals will be documented and maintained as part of project records."""
        }
    ]
    
    print("🚀 Populating SQLite content_blocks...")
    
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()
    
    inserted = 0
    updated = 0
    
    for block in content_blocks:
        now = now_iso()
        
        try:
            # Try to insert
            cur.execute(
                "INSERT INTO content_blocks (key, label, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                (block["key"], block["label"], block["content"], now, now)
            )
            inserted += 1
            print(f"  ✅ Inserted: {block['label']}")
        except sqlite3.IntegrityError:
            # Key exists, update instead
            cur.execute(
                "UPDATE content_blocks SET label=?, content=?, updated_at=? WHERE key=?",
                (block["label"], block["content"], now, block["key"])
            )
            updated += 1
            print(f"  🔄 Updated: {block['label']}")
    
    conn.commit()
    
    # Get total count
    cur.execute("SELECT COUNT(*) FROM content_blocks")
    total = cur.fetchone()[0]
    
    conn.close()
    
    print(f"\n✅ SQLite content population complete!")
    print(f"  📊 Inserted: {inserted}")
    print(f"  🔄 Updated: {updated}")
    print(f"  📚 Total blocks: {total}")
    print(f"\n💡 Access via: GET http://localhost:8000/content")

if __name__ == "__main__":
    create_table()
    populate_content()