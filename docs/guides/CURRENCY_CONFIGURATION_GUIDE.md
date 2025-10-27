# 💰 Currency Configuration Guide

**Project:** Khonology Proposal & SOW Builder  
**Feature:** Multi-Currency Support for AI-Generated Content  
**Default Currency:** South African Rands (ZAR)

---

## 🌍 Overview

The AI Assistant now generates all pricing and budget content in **South African Rands (ZAR)** by default. This ensures proposals are automatically formatted for the South African market.

---

## ✅ What's Changed

### **Before:**
```
Budget Estimate: $150,000 - $200,000
Implementation: $50,000
Support: $10,000/month
```

### **After (Default - ZAR):**
```
Budget Estimate: R150,000 - R200,000
Implementation: R50,000
Support: R10,000/month
```

---

## 🔧 Configuration

### **Default Settings**
The AI is configured to use **South African Rands** by default:

```python
# backend/ai_service.py
DEFAULT_CURRENCY = "ZAR"  # South African Rands
DEFAULT_CURRENCY_SYMBOL = "R"  # Rand symbol
```

### **Custom Currency (Optional)**

If you need to change the currency (e.g., for international clients), you can configure it in your `.env` file:

```bash
# backend/.env

# Optional: Override default currency
DEFAULT_CURRENCY=USD
DEFAULT_CURRENCY_SYMBOL=$

# Or for other currencies:
# DEFAULT_CURRENCY=EUR
# DEFAULT_CURRENCY_SYMBOL=€
#
# DEFAULT_CURRENCY=GBP
# DEFAULT_CURRENCY_SYMBOL=£
```

**Supported Currencies:**
- 🇿🇦 **ZAR** (R) - South African Rand (Default)
- 🇺🇸 **USD** ($) - US Dollar
- 🇪🇺 **EUR** (€) - Euro
- 🇬🇧 **GBP** (£) - British Pound
- 🇦🇺 **AUD** ($) - Australian Dollar
- 🇨🇦 **CAD** ($) - Canadian Dollar
- And more...

---

## 🎯 How It Works

### **1. Section Generation**
When generating pricing-related sections, the AI receives explicit instructions:

```python
prompt = f"""...
IMPORTANT: All monetary amounts must be in South African Rands (ZAR) 
using the R symbol (e.g., R50,000).
Do NOT use dollars ($), euros (€), or any other currency.
..."""
```

### **2. Full Proposal Generation**
When generating complete proposals:

```python
prompt = f"""You are writing a complete business proposal for Khonology, 
a South African company.

IMPORTANT: All monetary amounts MUST be in South African Rands (ZAR) 
using the R symbol (e.g., R150,000, R2.5 million).
..."""
```

### **3. Content Improvement**
When improving existing content, the AI checks and converts currencies:

```python
prompt = f"""...
IMPORTANT: If the content contains pricing/monetary amounts, 
ensure they are in South African Rands (ZAR) using the R symbol.
Convert any dollars ($), euros (€), or other currencies to Rands.
..."""
```

---

## 📝 Example Outputs

### **Executive Summary with Pricing**
```
We propose implementing a comprehensive CRM solution for your 
organization at an estimated investment of R2.5 million over 
18 months. This includes:

- Software licensing: R800,000
- Implementation services: R1,200,000
- Training and support: R500,000
```

### **Budget & Pricing Section**
```
BUDGET BREAKDOWN

Phase 1: Discovery & Planning
- Business analysis: R150,000
- Technical assessment: R100,000
- Project planning: R50,000
Subtotal: R300,000

Phase 2: Implementation
- Core development: R600,000
- Integration work: R400,000
- Testing & QA: R200,000
Subtotal: R1,200,000

Phase 3: Deployment & Training
- Deployment services: R300,000
- User training: R150,000
- Documentation: R50,000
Subtotal: R500,000

TOTAL PROJECT COST: R2,000,000
```

### **Timeline with Costs**
```
Project Timeline & Budget

Month 1-2: Requirements & Design (R300,000)
Month 3-5: Development Phase 1 (R600,000)
Month 6-8: Development Phase 2 (R600,000)
Month 9-10: Testing & Refinement (R300,000)
Month 11-12: Deployment & Training (R200,000)

Total Investment: R2,000,000
```

---

## 🧪 Testing the Currency Feature

### **Test 1: Generate Budget Section**
```bash
# Use AI Assistant
1. Click ✨ AI Assistant
2. Select "Generate Section"
3. Section Type: "Pricing & Budget"
4. Prompt: "Create budget for CRM implementation project"
5. Check output uses R symbol
```

**Expected Output:**
```
The proposed CRM implementation is estimated at R1.8 million...
- Phase 1: R400,000
- Phase 2: R800,000
- Phase 3: R600,000
```

### **Test 2: Generate Full Proposal**
```bash
1. Click ✨ AI Assistant
2. Select "Full Proposal"
3. Prompt: "Proposal for retail POS system upgrade"
4. Check "Budget & Pricing" section uses R symbol
```

**Expected Output in Budget Section:**
```
INVESTMENT SUMMARY
Hardware: R500,000
Software: R300,000
Implementation: R400,000
Total: R1,200,000
```

### **Test 3: Improve Content with Wrong Currency**
```bash
1. Write content with dollars:
   "Project cost: $100,000"
   
2. Select text and click ✨ AI Assistant
3. Select "Improve"
4. Check improved version uses R symbol
```

**Expected Output:**
```
"Project cost: R100,000"  # Converted to Rands
```

---

## 🔍 Verification

After restarting your backend, you'll see:

```bash
cd backend
python app.py

# Console output:
✅ OpenRouter API Key loaded: sk-or-v1-...1234
✅ Using model: anthropic/claude-3.5-sonnet
💰 Currency set to: ZAR (R)  # ← Confirms currency
```

---

## 📊 Currency in Different Sections

### **Sections That Use Currency:**

1. **Executive Summary**
   - High-level cost estimates
   - ROI projections
   - Investment totals

2. **Budget & Pricing** ⭐ **Primary**
   - Detailed cost breakdowns
   - Line items
   - Subtotals and totals
   - Payment terms

3. **Timeline & Milestones**
   - Phase costs
   - Milestone payments
   - Budget distribution

4. **Assumptions & Dependencies**
   - Cost assumptions
   - Budget constraints
   - Financial prerequisites

5. **Terms & Conditions**
   - Payment terms
   - Late payment fees
   - Currency clauses

### **Sections That Don't Need Currency:**
- Company Profile
- Team & Expertise
- Methodology & Approach
- Risk Mitigation
- References & Case Studies

---

## 🌐 Multi-Currency Proposals (Advanced)

### **For International Clients:**

If you need to create proposals in multiple currencies, you can:

**Option 1: Change Default Currency**
```bash
# In backend/.env
DEFAULT_CURRENCY=USD
DEFAULT_CURRENCY_SYMBOL=$
```
Then restart backend for all proposals to use USD.

**Option 2: Manual Specification**
Add currency context when prompting:
```
Prompt: "Create budget for CRM project. Use US Dollars ($)."
```
The AI will follow the prompt instruction.

**Option 3: Post-Generation Conversion**
1. Generate in Rands
2. Use "Improve" feature with prompt:
   "Convert all Rand amounts to US Dollars at R18.50 = $1"

---

## 💡 Best Practices

### **1. Consistent Formatting**
Always use comma separators for thousands:
- ✅ R150,000
- ✅ R2,500,000
- ❌ R150000 (hard to read)

### **2. Large Amounts**
For clarity, use words for millions:
- ✅ R2.5 million
- ✅ R2,500,000
- Both are acceptable

### **3. Decimal Places**
- For whole amounts: R100,000 (no decimals)
- For partial amounts: R125,500.50
- Avoid: R100,000.00 (unnecessary decimals)

### **4. Ranges**
Use en-dash for ranges:
- ✅ R100,000 - R150,000
- ✅ R100,000 to R150,000
- ❌ R100,000-R150,000 (no spaces)

### **5. Context**
Always provide context with amounts:
- ✅ "Implementation: R150,000"
- ❌ "R150,000" (what's it for?)

---

## 🐛 Troubleshooting

### **Issue 1: AI Still Using Dollars**

**Symptoms:**
```
Budget: $100,000  # Should be R100,000
```

**Solution:**
1. Check backend console for currency config:
   ```
   💰 Currency set to: ZAR (R)
   ```
2. If not showing, restart backend:
   ```bash
   cd backend
   python app.py
   ```
3. Log out and back in (fresh token)
4. Try again

### **Issue 2: Mixed Currencies**

**Symptoms:**
```
Phase 1: $50,000
Phase 2: R100,000
```

**Solution:**
1. Use "Improve" feature on the section
2. AI will detect and convert all to Rands
3. Or manually edit and regenerate

### **Issue 3: Wrong Currency Symbol**

**Symptoms:**
```
Budget: ZAR 100,000  # Should be R100,000
```

**Solution:**
This is acceptable but not ideal. Use "Improve" to standardize to "R" format.

### **Issue 4: No Currency at All**

**Symptoms:**
```
Budget: 100,000  # Missing R symbol
```

**Solution:**
1. Regenerate the section
2. Or manually add R symbols
3. Use "Improve" to fix formatting

---

## 📋 Quick Reference

### **Command to Restart Backend:**
```bash
cd backend
python app.py
```

### **Check Currency Configuration:**
Look for this in console:
```
💰 Currency set to: ZAR (R)
```

### **Change Currency (in backend/.env):**
```bash
# South African Rand (Default)
DEFAULT_CURRENCY=ZAR
DEFAULT_CURRENCY_SYMBOL=R

# US Dollar
DEFAULT_CURRENCY=USD
DEFAULT_CURRENCY_SYMBOL=$

# Euro
DEFAULT_CURRENCY=EUR
DEFAULT_CURRENCY_SYMBOL=€
```

### **Test Currency in Proposal:**
1. Generate any section with "budget" or "pricing"
2. Check for R symbol (not $ or €)
3. Verify formatting: R100,000

---

## 🎓 Examples by Use Case

### **Software Development Proposal**
```
DEVELOPMENT COSTS

Backend Development: R450,000
- API development: R200,000
- Database design: R150,000
- Integration: R100,000

Frontend Development: R350,000
- UI/UX design: R150,000
- Implementation: R200,000

Testing & QA: R200,000

Total Development: R1,000,000
```

### **Consulting Services Proposal**
```
PROFESSIONAL SERVICES

Strategy Consulting: R80,000
- Initial assessment: R30,000
- Strategy development: R50,000

Implementation Support: R120,000
- Change management: R60,000
- Training delivery: R40,000
- Post-launch support: R20,000

Total Investment: R200,000
```

### **Infrastructure Upgrade Proposal**
```
INFRASTRUCTURE INVESTMENT

Hardware Procurement: R2,500,000
- Servers: R1,200,000
- Networking equipment: R800,000
- Storage systems: R500,000

Installation & Configuration: R600,000
Migration Services: R400,000

Total Project Cost: R3,500,000
```

---

## 🚀 Summary

✅ **Default Currency:** South African Rands (ZAR/R)  
✅ **Configurable:** Via .env file  
✅ **Automatic:** AI handles currency in all sections  
✅ **Consistent:** All proposals use same currency  
✅ **Convertible:** Can switch currencies as needed  

**Your AI Assistant now speaks South African Rands!** 🇿🇦💰

---

## 📞 Need Help?

**Files to Check:**
- `backend/ai_service.py` - Currency configuration
- `backend/.env` - Environment variables
- `AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md` - Full AI guide

**Console Commands:**
```bash
# Restart backend
cd backend
python app.py

# Check for currency line in output:
# 💰 Currency set to: ZAR (R)
```

---

*Last Updated: October 24, 2025*  
*Currency Default: ZAR (South African Rands)*

