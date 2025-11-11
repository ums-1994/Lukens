# 🔧 DocuSign Key Upload - Complete Troubleshooting Guide

## 🚨 **Current Error:**
```
invalid_grant - no_valid_keys_or_signatures
```

**What this means:** DocuSign cannot verify your JWT signature because the public key doesn't match your private key.

---

## ✅ **COMPLETE FIX - Step by Step**

### **STEP 1: Delete ALL Existing Keys** 🗑️

1. Go to: **https://demo.docusign.net**
2. Click your **profile icon** (top right) → **Settings**
3. Click **"Apps and Keys"** in the left sidebar
4. Click on your app (you'll see Integration Key: `c72eda5f-1c22-46a2-97b6-df3e40a9bbcd`)
5. Scroll down to the **"RSA Keypairs"** section
6. **⚠️ CRITICAL:** For EVERY keypair you see:
   - Click the **trash icon (🗑️)**
   - Confirm deletion
   - Repeat until the section shows **"No RSA Keypairs"**

**Why:** If you have multiple keys, DocuSign randomly picks one. We need ONLY the correct key.

---

### **STEP 2: Add the Correct Public Key** ✅

1. Still in the same **RSA Keypairs** section (should now be empty)
2. Click **"+ ADD RSA KEYPAIR"** button
3. A text area will appear
4. **Copy THIS EXACT TEXT** (all 7 lines):

```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0PqLuapcAjn4B7JiTKoP
1arrPV5vGllYrtJ0vaP/4+Mh0RH8x5FlRIOLUEdV5lkPzeoN8jGa3kdOjYN58F0b
uhnm5IOjVZPvGxPDdUuW6hwbXuOiAFrZ/fJJZ4dvzb96bv1slqyJ5a+6XuOZSRqk
+hcwELstyv0XzFawRFXqT26ZlpyCMDs75C9bBEElR/fYzMyTvlTdygwEigf0mjoP
s4ICpfYHPFBgLl7eRGDNwaT2hLcPaLPcMxCNlw1nrdKEU46hquELeqEEB7IV8cQa
CE6C9j+pikpFOkHzHWv6Y+HFLmTuXneDVfv1SchdZCLgEwG8VFelFiA2V8z1bwXA
awIDAQAB
-----END PUBLIC KEY-----
```

5. **Paste** it into the text area
6. Click **"SAVE"** button
7. You should see a success message: "RSA public key added successfully"

---

### **STEP 3: Wait for DocuSign to Process** ⏰

**DocuSign needs 3-5 minutes to propagate your key to their servers.**

- Set a **5-minute timer**
- Get a coffee ☕
- Do NOT test immediately!

---

### **STEP 4: Test the Connection** 🧪

After waiting 5 minutes, run:

```powershell
cd backend
python quick_test.py
```

**Expected Output:**
```
✅ SUCCESS! DocuSign authentication works!
🎉 Your integration is ready to use!
```

---

## 🔍 **Common Mistakes Checklist**

| ❌ Mistake | ✅ Correct |
|-----------|----------|
| Adding multiple keys | Delete ALL old keys first |
| Missing BEGIN/END lines | Include the entire 7-line key |
| Testing immediately | Wait 5 minutes after saving |
| Copying with extra spaces | Copy exactly as shown |
| Partial key upload | Must include all characters |

---

## 🆘 **Still Not Working?**

If you still get errors after following ALL steps above:

### Option A: Check for Typos

Run this to verify your configuration:
```powershell
python diagnose_docusign.py
```

### Option B: Regenerate Everything

If all else fails, start completely fresh:

```powershell
# Delete old keys
del docusign_private.key
del docusign_public.key

# Generate new keypair
python generate_docusign_keys.py

# Show the new public key
python show_public_key.py

# Upload the NEW key to DocuSign (delete all old ones first!)
# Wait 5 minutes
# Test again
python quick_test.py
```

---

## 📸 **What You Should See in DocuSign**

After correctly adding the key, the RSA Keypairs section should look like this:

```
RSA Keypairs
├─ Public key #1
│  └─ Added: [today's date]
│  └─ [Trash icon]
└─ + ADD RSA KEYPAIR (button)
```

**You should see ONLY ONE keypair!**

---

## 🎯 **Quick Reference**

Run `python show_public_key.py` anytime to see your public key again.

---

## 📞 **Need Help?**

If this still doesn't work after following ALL steps:

1. Take a screenshot of your DocuSign RSA Keypairs section
2. Run: `python diagnose_docusign.py` and share the output
3. Verify your Integration Key matches: `c72eda5f-1c22-46a2-97b6-df3e40a9bbcd`

---

**Last Updated:** 2025-10-28

**Your Files:**
- Private Key: `backend/docusign_private.key` (keep secret!)
- Public Key: `backend/docusign_public.key` (upload to DocuSign)








