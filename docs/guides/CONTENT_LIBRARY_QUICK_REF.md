# 📚 Content Library - Quick Reference

## ⚡ Quick Start

```bash
# 1. Backend is already running on http://localhost:8000
# 2. Content is already populated (30 modules + 20 blocks)
# 3. Ready to use!
```

---

## 🔌 API Endpoints

### Content Modules (PostgreSQL)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/modules/` | GET | List all modules |
| `/api/modules/?category=Templates` | GET | Filter by category |
| `/api/modules/?q=risk` | GET | Search content |
| `/api/modules/{id}` | GET | Get single module |
| `/api/modules/` | POST | Create module |
| `/api/modules/{id}` | PUT | Update module |
| `/api/modules/{id}` | DELETE | Delete module |
| `/api/modules/{id}/versions` | GET | Version history |
| `/api/modules/{id}/revert` | POST | Revert version |

### Content Blocks (SQLite)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/content` | GET | List all blocks |
| `/content` | POST | Create block |
| `/content/{id}` | PUT | Update block |
| `/content/{id}` | DELETE | Delete block |

---

## 📂 Available Categories

```
Templates (4)          - Reusable proposal sections
Company Profile (4)    - About Khonology
References (3)         - Client case studies
Methodology (2)        - Delivery approaches
Technical (2)          - Architecture & AI/ML
Team Bio (2)           - Leadership bios
Legal (2)              - Terms & conditions
Risk Management (1)    - Risk assessments
Assumptions (1)        - Project assumptions
+ 9 more categories
```

---

## 💡 Common Use Cases

### 1. Get Executive Summary Template
```bash
curl "http://localhost:8000/api/modules/?category=Templates&q=Executive"
```

### 2. Get Company Information
```bash
curl http://localhost:8000/content | jq '.[] | select(.key=="company_name")'
```

### 3. Get All Templates
```bash
curl "http://localhost:8000/api/modules/?category=Templates"
```

### 4. Search for Risk Content
```bash
curl "http://localhost:8000/api/modules/?q=risk"
```

### 5. Get Standard Terms
```bash
curl http://localhost:8000/content | jq '.[] | select(.key=="terms")'
```

---

## 🎯 Key Content Blocks

| Key | Content |
|-----|---------|
| `company_name` | Khonology |
| `company_tagline` | Transforming Business Through Technology |
| `company_address` | Full address |
| `company_phone` | +1 (555) 123-4567 |
| `company_email` | info@khonology.com |
| `company_website` | www.khonology.com |
| `terms` | Complete T&Cs |
| `privacy_policy` | Privacy policy |
| `signature_block` | Signature template |
| `confidentiality_clause` | Confidentiality agreement |
| `warranty_clause` | Warranty terms |
| `payment_terms` | Payment terms |
| `change_control` | Change process |

---

## 🔧 Quick Commands

### View All Content
```bash
# PostgreSQL modules
curl http://localhost:8000/api/modules/

# SQLite blocks
curl http://localhost:8000/content
```

### Run Demo
```bash
cd backend
python demo_content_library.py
```

### Update Company Name
```bash
curl -X PUT http://localhost:8000/content/1 \
  -H "Content-Type: application/json" \
  -d '{"key":"company_name","label":"Company Name","content":"Your Company"}'
```

### Add New Template
```bash
curl -X POST http://localhost:8000/api/modules/ \
  -H "Content-Type: application/json" \
  -d '{"title":"New Template","category":"Templates","body":"Content...","is_editable":true}'
```

---

## 📊 Statistics

```
Total Modules:     30
Total Blocks:      20
Categories:        18
Editable:          14
Protected:         16
Total Size:        ~29 KB
```

---

## 🎬 Demo Script

```bash
# 1. Show statistics
curl http://localhost:8000/api/modules/ | jq 'length'

# 2. Show categories
curl http://localhost:8000/api/modules/ | jq '.[].category' | sort -u

# 3. Show templates
curl "http://localhost:8000/api/modules/?category=Templates" | jq '.[].title'

# 4. Show company info
curl http://localhost:8000/content | jq '.[] | select(.key | startswith("company"))'

# 5. Search functionality
curl "http://localhost:8000/api/modules/?q=risk" | jq '.[].title'
```

---

## 🚀 Integration Example

```python
import requests

# Get content
def get_template(name):
    response = requests.get(
        "http://localhost:8000/api/modules/",
        params={"category": "Templates", "q": name}
    )
    return response.json()[0]["body"]

def get_company_info(key):
    response = requests.get("http://localhost:8000/content")
    blocks = {b["key"]: b["content"] for b in response.json()}
    return blocks.get(key)

# Use in proposal
exec_summary = get_template("Executive")
company_name = get_company_info("company_name")
terms = get_company_info("terms")

proposal = {
    "sections": {
        "Executive Summary": exec_summary.replace("[Client Name]", "Acme"),
        "Company": company_name,
        "Terms": terms
    }
}
```

---

## 📚 Documentation

- **Full Guide**: `CONTENT_LIBRARY_GUIDE.md`
- **Inventory**: `CONTENT_LIBRARY_INVENTORY.md`
- **Summary**: `CONTENT_LIBRARY_SUMMARY.md`
- **API Docs**: http://localhost:8000/docs

---

## ✅ Checklist

- [x] Content library populated
- [x] API endpoints working
- [x] Documentation created
- [x] Demo script available
- [ ] Customize company information
- [ ] Integrate with Flutter UI
- [ ] Connect to AI features
- [ ] Test compound risk gate

---

## 🎯 For Hackathon

**Show this in your demo:**
1. Content library with 30+ modules ✅
2. API access and search ✅
3. AI using content for proposals ✅
4. Risk detection with content validation ✅
5. Version control and audit trail ✅

**Time to demo: 5 minutes**

---

**Quick access: http://localhost:8000/docs** 🚀