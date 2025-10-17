# 📚 Content Library Guide

## Overview

Your Proposal & SOW Builder now includes a comprehensive **Content Library** with Khonology-specific content that can be reused across proposals. The content library has two storage systems:

1. **PostgreSQL Content Modules** - Rich, versioned content with categories
2. **SQLite Content Blocks** - Simple key-value content storage

---

## 🚀 Quick Setup

### Step 1: Populate PostgreSQL Content Modules

```bash
cd backend
python populate_content_library.py
```

This creates and populates the `content_modules` table with:
- Company profiles
- Service offerings
- Methodology descriptions
- Legal terms and conditions
- Standard assumptions
- Risk assessments
- Technical best practices
- Proposal templates
- Team bio templates
- Client references

### Step 2: Populate SQLite Content Blocks

```bash
cd backend
python populate_sqlite_content.py
```

This populates the `content_blocks` table with:
- Company information (name, address, contact)
- Standard terms and conditions
- Privacy policy
- Signature blocks
- Confidentiality clauses
- Warranty clauses
- Payment terms
- Change control process

---

## 📊 Content Categories

### PostgreSQL Content Modules

| Category | Description | Count | Editable |
|----------|-------------|-------|----------|
| **Company Profile** | About Khonology, services, values | 2 | No |
| **Methodology** | Delivery approach, Agile practices | 2 | No |
| **Legal** | Terms, conditions, contracts | 1 | No |
| **Assumptions** | Standard project assumptions | 1 | No |
| **Risk Management** | Risk assessments and mitigation | 1 | No |
| **Technical** | Architecture, AI/ML frameworks | 2 | Yes |
| **Templates** | Reusable proposal sections | 4 | Yes |
| **References** | Client case studies | 3 | No |

**Total: 16 modules**

### SQLite Content Blocks

| Key | Label | Usage |
|-----|-------|-------|
| `company_name` | Company Name | Headers, footers |
| `company_tagline` | Company Tagline | Cover pages |
| `company_address` | Company Address | Contact sections |
| `company_phone` | Company Phone | Contact sections |
| `company_email` | Company Email | Contact sections |
| `company_website` | Company Website | Contact sections |
| `terms` | Standard Terms & Conditions | Legal sections |
| `privacy_policy` | Privacy Policy | Legal sections |
| `signature_block` | Signature Block | Approval pages |
| `confidentiality_clause` | Confidentiality Clause | Legal sections |
| `warranty_clause` | Warranty Clause | Legal sections |
| `payment_terms` | Payment Terms | Investment sections |
| `change_control` | Change Control Process | Project management |

**Total: 13 blocks**

---

## 🔌 API Endpoints

### Content Modules (PostgreSQL)

#### List All Modules
```http
GET /api/modules/
```

**Query Parameters:**
- `q` - Search in title and body
- `category` - Filter by category

**Example:**
```bash
curl http://localhost:8000/api/modules/?category=Templates
```

**Response:**
```json
[
  {
    "id": "1",
    "title": "Executive Summary Template",
    "category": "Templates",
    "body": "# Executive Summary\n\n...",
    "version": 1,
    "created_at": "2024-01-15T10:30:00",
    "updated_at": "2024-01-15T10:30:00",
    "is_editable": true
  }
]
```

#### Get Single Module
```http
GET /api/modules/{module_id}
```

#### Create Module
```http
POST /api/modules/
Content-Type: application/json

{
  "title": "New Module",
  "category": "Templates",
  "body": "Content here...",
  "is_editable": true
}
```

#### Update Module
```http
PUT /api/modules/{module_id}
Content-Type: application/json

{
  "title": "Updated Title",
  "body": "Updated content...",
  "note": "Updated for Q1 2024"
}
```

#### Delete Module
```http
DELETE /api/modules/{module_id}
```

#### Get Version History
```http
GET /api/modules/{module_id}/versions
```

#### Revert to Previous Version
```http
POST /api/modules/{module_id}/revert
Content-Type: application/json

{
  "version": 2,
  "note": "Reverting to previous version"
}
```

### Content Blocks (SQLite)

#### List All Blocks
```http
GET /content
```

**Response:**
```json
[
  {
    "id": 1,
    "key": "company_name",
    "label": "Company Name",
    "content": "Khonology",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
]
```

#### Create Block
```http
POST /content
Content-Type: application/json

{
  "key": "new_block",
  "label": "New Block",
  "content": "Content here..."
}
```

#### Update Block
```http
PUT /content/{block_id}
Content-Type: application/json

{
  "key": "company_name",
  "label": "Company Name",
  "content": "Khonology Inc."
}
```

#### Delete Block
```http
DELETE /content/{block_id}
```

---

## 💡 Usage Examples

### Example 1: Building a Proposal with Templates

```python
import requests

# Get executive summary template
response = requests.get(
    "http://localhost:8000/api/modules/",
    params={"category": "Templates", "q": "Executive Summary"}
)
template = response.json()[0]

# Customize the template
executive_summary = template["body"].replace(
    "[Client Name]", "Acme Corporation"
).replace(
    "[brief description of project objective]",
    "modernize their legacy inventory management system"
)

# Use in proposal
proposal = {
    "title": "Acme Corp - Inventory System Modernization",
    "sections": {
        "Executive Summary": executive_summary
    }
}
```

### Example 2: Adding Company Information

```python
import requests

# Get company info
response = requests.get("http://localhost:8000/content")
content_blocks = {block["key"]: block["content"] for block in response.json()}

# Build contact section
contact_info = f"""
## Contact Information

{content_blocks["company_name"]}
{content_blocks["company_tagline"]}

{content_blocks["company_address"]}

Phone: {content_blocks["company_phone"]}
Email: {content_blocks["company_email"]}
Web: {content_blocks["company_website"]}
"""
```

### Example 3: Using Standard Terms

```python
import requests

# Get standard terms
response = requests.get("http://localhost:8000/content")
terms_block = next(
    block for block in response.json() 
    if block["key"] == "terms"
)

# Add to proposal
proposal_sections["Terms & Conditions"] = terms_block["content"]
```

### Example 4: Searching Content

```python
import requests

# Search for risk-related content
response = requests.get(
    "http://localhost:8000/api/modules/",
    params={"q": "risk"}
)

risk_modules = response.json()
for module in risk_modules:
    print(f"{module['title']} ({module['category']})")
```

---

## 🎨 Frontend Integration (Flutter)

### Create Content Library Service

```dart
// lib/services/content_library_service.dart

class ContentLibraryService {
  final String baseUrl;
  String? _authToken;

  ContentLibraryService({required this.baseUrl});

  void setAuthToken(String token) {
    _authToken = token;
  }

  Future<List<ContentModule>> getModules({
    String? category,
    String? searchQuery,
  }) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    if (searchQuery != null) queryParams['q'] = searchQuery;

    final uri = Uri.parse('$baseUrl/api/modules/')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ContentModule.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load content modules');
    }
  }

  Future<ContentModule> getModule(String moduleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/modules/$moduleId'),
      headers: {
        'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode == 200) {
      return ContentModule.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load module');
    }
  }

  Future<List<ContentBlock>> getContentBlocks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/content'),
      headers: {
        'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ContentBlock.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load content blocks');
    }
  }
}

class ContentModule {
  final String id;
  final String title;
  final String category;
  final String body;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEditable;

  ContentModule({
    required this.id,
    required this.title,
    required this.category,
    required this.body,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.isEditable,
  });

  factory ContentModule.fromJson(Map<String, dynamic> json) {
    return ContentModule(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      body: json['body'],
      version: json['version'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isEditable: json['is_editable'],
    );
  }
}

class ContentBlock {
  final int id;
  final String key;
  final String label;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentBlock({
    required this.id,
    required this.key,
    required this.label,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      id: json['id'],
      key: json['key'],
      label: json['label'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
```

### Use in Proposal Editor

```dart
// In your proposal editor widget

class ProposalEditorPage extends StatefulWidget {
  @override
  _ProposalEditorPageState createState() => _ProposalEditorPageState();
}

class _ProposalEditorPageState extends State<ProposalEditorPage> {
  final ContentLibraryService _contentService = ContentLibraryService(
    baseUrl: 'http://localhost:8000',
  );

  Future<void> _insertTemplate() async {
    // Show template picker
    final templates = await _contentService.getModules(
      category: 'Templates',
    );

    final selected = await showDialog<ContentModule>(
      context: context,
      builder: (context) => TemplatePickerDialog(templates: templates),
    );

    if (selected != null) {
      // Insert template content into editor
      setState(() {
        _contentController.text = selected.body;
      });
    }
  }

  Future<void> _insertCompanyInfo() async {
    final blocks = await _contentService.getContentBlocks();
    final companyName = blocks.firstWhere(
      (b) => b.key == 'company_name',
    ).content;

    // Insert into editor
    _contentController.text += '\n\n$companyName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Proposal'),
        actions: [
          IconButton(
            icon: Icon(Icons.library_books),
            onPressed: _insertTemplate,
            tooltip: 'Insert Template',
          ),
          IconButton(
            icon: Icon(Icons.business),
            onPressed: _insertCompanyInfo,
            tooltip: 'Insert Company Info',
          ),
        ],
      ),
      body: TextField(
        controller: _contentController,
        maxLines: null,
        decoration: InputDecoration(
          hintText: 'Enter proposal content...',
        ),
      ),
    );
  }
}
```

---

## 🔧 Customization

### Adding New Content Modules

1. **Via API:**
```bash
curl -X POST http://localhost:8000/api/modules/ \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Custom Template",
    "category": "Templates",
    "body": "Your content here...",
    "is_editable": true
  }'
```

2. **Via SQL:**
```sql
INSERT INTO content_modules (title, category, body, is_editable)
VALUES (
  'Custom Template',
  'Templates',
  'Your content here...',
  true
);
```

### Adding New Content Blocks

```bash
curl -X POST http://localhost:8000/content \
  -H "Content-Type: application/json" \
  -d '{
    "key": "custom_block",
    "label": "Custom Block",
    "content": "Your content here..."
  }'
```

### Modifying Existing Content

1. **Find the module ID:**
```bash
curl http://localhost:8000/api/modules/?q=Executive
```

2. **Update the module:**
```bash
curl -X PUT http://localhost:8000/api/modules/1 \
  -H "Content-Type: application/json" \
  -d '{
    "body": "Updated content...",
    "note": "Updated for 2024"
  }'
```

---

## 📈 Best Practices

### 1. Use Templates for Consistency
- Start every proposal with standard templates
- Customize templates for specific clients
- Maintain version history for audit trails

### 2. Leverage Content Blocks for Reusability
- Use content blocks for frequently repeated text
- Update blocks centrally to affect all proposals
- Keep blocks focused and single-purpose

### 3. Organize by Category
- Use clear, consistent category names
- Group related content together
- Make it easy to find content quickly

### 4. Version Control
- Use the version history feature for important changes
- Add meaningful notes when updating content
- Revert to previous versions if needed

### 5. Mark Non-Editable Content
- Set `is_editable: false` for legal/compliance content
- Protect standard terms and conditions
- Allow flexibility for templates and technical content

---

## 🎯 Hackathon Integration

### Compound Risk Gate Enhancement

The content library enhances the Compound Risk Gate by:

1. **Detecting Missing Standard Content**
```python
# Check if standard terms are included
standard_terms = get_content_block("terms")
if standard_terms not in proposal.sections.get("Terms", ""):
    risk_score += 15
    issues.append("Standard terms and conditions not included")
```

2. **Validating Required Sections**
```python
# Check if required templates are used
required_templates = ["Executive Summary", "Scope & Deliverables"]
for template in required_templates:
    if template not in proposal.sections:
        risk_score += 10
        issues.append(f"Missing required section: {template}")
```

3. **Detecting Content Deviations**
```python
# Check if legal clauses were modified
original_warranty = get_content_block("warranty_clause")
if proposal_warranty != original_warranty:
    risk_score += 5
    issues.append("Warranty clause modified - requires legal review")
```

---

## 🚀 Next Steps

1. **Run the population scripts** to load content
2. **Test the API endpoints** with Postman or curl
3. **Integrate into your Flutter app** using the service examples
4. **Customize content** for your specific needs
5. **Add content library UI** to your proposal editor

---

## 📞 Support

For questions or issues:
- Check API documentation: `http://localhost:8000/docs`
- Review backend logs for errors
- Ensure database connections are working
- Verify authentication tokens are valid

---

**Happy Building! 🎉**