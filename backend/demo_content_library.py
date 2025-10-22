"""
Demo script to showcase the content library
"""
import requests
import json
from typing import List, Dict

BASE_URL = "http://localhost:8000"

def print_header(text: str):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70)

def print_section(text: str):
    """Print a formatted section"""
    print(f"\n📌 {text}")
    print("-" * 70)

def get_modules(category: str = None, search: str = None) -> List[Dict]:
    """Get content modules"""
    params = {}
    if category:
        params['category'] = category
    if search:
        params['q'] = search
    
    response = requests.get(f"{BASE_URL}/api/modules/", params=params)
    if response.status_code == 200:
        return response.json()
    return []

def get_content_blocks() -> List[Dict]:
    """Get content blocks"""
    response = requests.get(f"{BASE_URL}/content")
    if response.status_code == 200:
        return response.json()
    return []

def demo_templates():
    """Demo: Show available templates"""
    print_header("📝 AVAILABLE TEMPLATES")
    
    templates = get_modules(category="Templates")
    
    for i, template in enumerate(templates, 1):
        print(f"\n{i}. {template['title']}")
        print(f"   Category: {template['category']}")
        print(f"   Editable: {'Yes' if template['is_editable'] else 'No'}")
        print(f"   Version: {template['version']}")
        
        # Show first 200 characters of content
        preview = template['body'][:200].replace('\n', ' ')
        print(f"   Preview: {preview}...")

def demo_company_info():
    """Demo: Show company information"""
    print_header("🏢 COMPANY INFORMATION")
    
    blocks = get_content_blocks()
    company_blocks = [
        b for b in blocks 
        if b['key'] in ['company_name', 'company_tagline', 'company_address', 
                        'company_phone', 'company_email', 'company_website']
    ]
    
    for block in company_blocks:
        print(f"\n{block['label']}:")
        print(f"  {block['content']}")

def demo_legal_content():
    """Demo: Show legal content"""
    print_header("⚖️ LEGAL & COMPLIANCE CONTENT")
    
    blocks = get_content_blocks()
    legal_blocks = [
        b for b in blocks 
        if b['key'] in ['terms', 'confidentiality_clause', 'warranty_clause', 
                        'payment_terms', 'change_control']
    ]
    
    for block in legal_blocks:
        print(f"\n📄 {block['label']}")
        # Show first 150 characters
        preview = block['content'][:150].replace('\n', ' ')
        print(f"   {preview}...")
        print(f"   [Total length: {len(block['content'])} characters]")

def demo_references():
    """Demo: Show client references"""
    print_header("🌟 CLIENT REFERENCES")
    
    references = get_modules(category="References")
    
    for ref in references:
        print(f"\n📊 {ref['title']}")
        
        # Extract key information
        lines = ref['body'].split('\n')
        for line in lines[:15]:  # Show first 15 lines
            if line.strip() and not line.startswith('#'):
                print(f"   {line}")

def demo_methodology():
    """Demo: Show delivery methodology"""
    print_header("🔄 DELIVERY METHODOLOGY")
    
    methodology = get_modules(category="Methodology")
    
    for method in methodology:
        print(f"\n📋 {method['title']}")
        
        # Show structure
        lines = ref['body'].split('\n')
        for line in lines:
            if line.startswith('##'):
                print(f"   {line}")

def demo_search():
    """Demo: Search functionality"""
    print_header("🔍 SEARCH FUNCTIONALITY")
    
    search_terms = ['risk', 'cloud', 'agile', 'payment']
    
    for term in search_terms:
        results = get_modules(search=term)
        print(f"\n🔎 Search for '{term}': {len(results)} results")
        
        for result in results[:3]:  # Show first 3 results
            print(f"   • {result['title']} ({result['category']})")

def demo_categories():
    """Demo: Show all categories"""
    print_header("📂 CONTENT CATEGORIES")
    
    all_modules = get_modules()
    
    # Group by category
    categories = {}
    for module in all_modules:
        cat = module['category']
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(module['title'])
    
    # Display
    for category, titles in sorted(categories.items()):
        print(f"\n📁 {category} ({len(titles)} modules)")
        for title in titles[:5]:  # Show first 5
            print(f"   • {title}")
        if len(titles) > 5:
            print(f"   ... and {len(titles) - 5} more")

def demo_usage_example():
    """Demo: Show how to use content in a proposal"""
    print_header("💡 USAGE EXAMPLE: Building a Proposal")
    
    print("\n1️⃣ Get Executive Summary Template")
    templates = get_modules(category="Templates", search="Executive")
    if templates:
        template = templates[0]
        print(f"   ✅ Found: {template['title']}")
        print(f"   📝 Length: {len(template['body'])} characters")
    
    print("\n2️⃣ Get Company Information")
    blocks = get_content_blocks()
    company_name = next((b for b in blocks if b['key'] == 'company_name'), None)
    if company_name:
        print(f"   ✅ Company: {company_name['content']}")
    
    print("\n3️⃣ Get Standard Terms")
    terms = next((b for b in blocks if b['key'] == 'terms'), None)
    if terms:
        print(f"   ✅ Terms: {len(terms['content'])} characters")
    
    print("\n4️⃣ Get Relevant Case Study")
    references = get_modules(category="References")
    if references:
        print(f"   ✅ Available: {len(references)} case studies")
    
    print("\n5️⃣ Assemble Proposal")
    print("   ✅ Executive Summary (from template)")
    print("   ✅ Company Profile (from content blocks)")
    print("   ✅ Scope & Deliverables (from template)")
    print("   ✅ References (from case studies)")
    print("   ✅ Terms & Conditions (from content blocks)")
    print("\n   🎉 Complete proposal ready!")

def demo_statistics():
    """Demo: Show content statistics"""
    print_header("📊 CONTENT LIBRARY STATISTICS")
    
    modules = get_modules()
    blocks = get_content_blocks()
    
    print(f"\n📚 Total Content Modules: {len(modules)}")
    print(f"🗂️  Total Content Blocks: {len(blocks)}")
    
    # Category breakdown
    categories = {}
    for module in modules:
        cat = module['category']
        categories[cat] = categories.get(cat, 0) + 1
    
    print(f"\n📂 Categories: {len(categories)}")
    for cat, count in sorted(categories.items(), key=lambda x: x[1], reverse=True):
        print(f"   {cat:.<40} {count:>3} modules")
    
    # Editable vs protected
    editable = sum(1 for m in modules if m['is_editable'])
    protected = len(modules) - editable
    
    print(f"\n🔓 Editable Modules: {editable}")
    print(f"🔒 Protected Modules: {protected}")
    
    # Total content size
    total_chars = sum(len(m['body']) for m in modules)
    total_chars += sum(len(b['content']) for b in blocks)
    
    print(f"\n📝 Total Content Size: {total_chars:,} characters")
    print(f"   (~{total_chars // 1000} KB)")

def main():
    """Run all demos"""
    print("\n" + "🎬" * 35)
    print("  KHONOLOGY CONTENT LIBRARY DEMO")
    print("🎬" * 35)
    
    try:
        # Check if backend is running
        response = requests.get(f"{BASE_URL}/api/modules/", timeout=2)
        if response.status_code != 200:
            print("\n❌ Backend not responding correctly")
            print("   Make sure the backend is running: uvicorn app:app --reload")
            return
    except requests.exceptions.RequestException:
        print("\n❌ Cannot connect to backend")
        print("   Make sure the backend is running: uvicorn app:app --reload")
        return
    
    # Run demos
    demo_statistics()
    demo_categories()
    demo_templates()
    demo_company_info()
    demo_legal_content()
    demo_references()
    demo_search()
    demo_usage_example()
    
    print_header("✅ DEMO COMPLETE")
    print("\n💡 Next Steps:")
    print("   1. Explore content via API: http://localhost:8000/docs")
    print("   2. Customize content for your needs")
    print("   3. Integrate into your Flutter app")
    print("   4. Use AI to generate proposals with this content")
    print("\n📚 Documentation: See CONTENT_LIBRARY_GUIDE.md")
    print("\n" + "🎬" * 35 + "\n")

if __name__ == "__main__":
    main()