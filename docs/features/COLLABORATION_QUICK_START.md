# 🚀 Collaboration Feature - Quick Start Guide

## How to Invite Collaborators

### Step 1: Open Your Proposal
1. Navigate to **My Proposals**
2. Click on any proposal to open it in the editor
3. **Important:** Save the proposal first if it's new

### Step 2: Invite a Collaborator
1. Click the **"Share"** button in the top toolbar (next to Comments button)
2. In the dialog that opens:
   - Enter the collaborator's **email address**
   - Choose permission level:
     - **Can Comment** - Can view and add comments
     - **View Only** - Can only view the proposal
3. Click **"Send Invite"**

### Step 3: Email is Sent Automatically! ✉️
The collaborator will receive a professional email with:
- Proposal title and your name
- A secure access link
- Their permission level
- Expiration date (30 days)

---

## What Collaborators See

### When They Click the Link:
1. **No Login Required!** 🎉
   - Opens directly in their browser
   - No account creation needed

2. **Clean Interface**
   - Proposal content on the left
   - Comments sidebar on the right
   - Their email displayed at top

3. **Can Add Comments** (if permitted)
   - Type in the comment box
   - Click send icon
   - Comment appears immediately

---

## Managing Collaborators

### View Current Collaborators
1. Click **"Share"** button again
2. See all invited collaborators with:
   - Email address
   - Permission level
   - Status (Pending/Active)
   - Active = They've accessed the link
   - Pending = Haven't accessed yet

### Remove a Collaborator
1. In the collaborators list
2. Click the **X** icon next to their name
3. Their access is immediately revoked

---

## Testing the Feature

### Quick Test (Same Computer):
1. Create/open a proposal
2. Save it
3. Click "Share"
4. Invite your own email
5. Check your email
6. Click the link (open in incognito/private window)
7. See the guest view page
8. Try adding a comment!

---

## Configuration Needed

### SMTP Email Setup (Required)
The feature needs SMTP configured to send emails.

**In your `.env` file:**
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
# Note: Port 8080 is typically PostgreSQL, use 8081 for Flutter
FRONTEND_URL=http://localhost:8081
```

**For Gmail:**
1. Go to Google Account Settings
2. Security → 2-Step Verification → App Passwords
3. Generate an app password
4. Use that password in `SMTP_PASS`

**Alternative Email Providers:**
- **Outlook:** `smtp-mail.outlook.com:587`
- **SendGrid:** `smtp.sendgrid.net:587`
- **Mailgun:** `smtp.mailgun.org:587`

---

## Troubleshooting

### "Please save the proposal first"
- Save your proposal before inviting collaborators
- Click the Save button or wait for auto-save

### "Email failed to send"
- Check SMTP configuration in `.env`
- Verify your email credentials
- Check firewall/network settings
- Invitation is still created (link works), just email didn't send

### "Invalid collaboration token"
- Link may have expired (30 days)
- Invitation may have been removed
- Try sending a new invitation

### "This invitation has expired"
- Default 30-day expiration
- Send a new invitation

---

## Key Features Summary

✅ **Email invitations** - Automatic delivery  
✅ **No account needed** - Guests access directly  
✅ **Secure tokens** - 30-day expiration  
✅ **Permission levels** - View or Comment  
✅ **Real-time comments** - Instant feedback  
✅ **Easy management** - Add/remove anytime  
✅ **Professional emails** - Beautiful templates  
✅ **Guest interface** - Clean, focused view  

---

## Example Use Cases

### 📊 Client Review
```
Scenario: Send proposal to client for feedback
Steps:
1. Complete your proposal
2. Share with client@company.com
3. Permission: Can Comment
4. Client receives email
5. Client clicks link, reviews, adds comments
6. You see comments in your editor
```

### 👥 Team Collaboration
```
Scenario: Get input from team member
Steps:
1. Draft proposal
2. Share with colleague@company.com
3. Permission: Can Comment
4. Colleague reviews and suggests edits
5. Iterate based on feedback
```

### 👀 Stakeholder Review
```
Scenario: Show proposal to stakeholder
Steps:
1. Finalize proposal
2. Share with executive@company.com
3. Permission: View Only
4. Stakeholder reviews at their convenience
5. Discuss in person later
```

---

## Security Notes

🔒 **Secure by Design:**
- Unique tokens per invitation
- Tokens never exposed in URL permanently
- Time-limited access
- Owner can revoke anytime
- No account = No password risk

⚠️ **Best Practices:**
- Only invite trusted collaborators
- Remove access when no longer needed
- Monitor who has accessed
- Use "View Only" for sensitive proposals

---

## Need Help?

**Common Questions:**

**Q: Can I invite multiple people?**  
A: Yes! Send multiple invitations with different permissions.

**Q: Can collaborators edit the proposal?**  
A: No, only view and comment. Full editing requires a user account.

**Q: How do I see all comments?**  
A: Click the "Comments" button in your editor toolbar.

**Q: Can I change permissions after inviting?**  
A: Remove the old invitation and send a new one.

**Q: What happens if I delete the proposal?**  
A: All invitations are automatically deleted too.

---

## 🎉 You're Ready!

The collaboration feature is fully set up and ready to use. Start inviting collaborators and getting feedback on your proposals!

**Happy Collaborating!** 👥

