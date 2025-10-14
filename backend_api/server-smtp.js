const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage for demo purposes
let users = [];
let proposals = [];
let sows = [];
let verificationTokens = new Map(); // Store verification tokens

// SMTP Configuration
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: process.env.SMTP_PORT || 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

// Verify SMTP connection
transporter.verify((error, success) => {
  if (error) {
    console.log('❌ SMTP Error:', error.message);
    console.log('📧 Email functionality will be disabled');
  } else {
    console.log('✅ SMTP Server is ready to send emails');
  }
});

// Generate verification token
const generateVerificationToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Send verification email
const sendVerificationEmail = async (email, token) => {
  const verificationUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/verify-email?token=${token}`;
  
  const mailOptions = {
    from: `"Lukens" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Verify Your Email Address',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Welcome to Lukens!</h2>
        <p>Thank you for registering. Please verify your email address by clicking the button below:</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${verificationUrl}" 
             style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Verify Email Address
          </a>
        </div>
        <p>Or copy and paste this link into your browser:</p>
        <p style="word-break: break-all; color: #666;">${verificationUrl}</p>
        <p style="color: #666; font-size: 12px;">
          This link will expire in 24 hours. If you didn't create an account, please ignore this email.
        </p>
      </div>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('📧 Verification email sent:', info.messageId);
    return true;
  } catch (error) {
    console.error('❌ Error sending verification email:', error);
    return false;
  }
};

// Send password reset email
const sendPasswordResetEmail = async (email, token) => {
  const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/reset-password?token=${token}`;
  
  const mailOptions = {
    from: `"Lukens" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Reset Your Password',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Password Reset Request</h2>
        <p>You requested to reset your password. Click the button below to reset it:</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${resetUrl}" 
             style="background-color: #dc3545; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Reset Password
          </a>
        </div>
        <p>Or copy and paste this link into your browser:</p>
        <p style="word-break: break-all; color: #666;">${resetUrl}</p>
        <p style="color: #666; font-size: 12px;">
          This link will expire in 1 hour. If you didn't request this, please ignore this email.
        </p>
      </div>
    `
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('📧 Password reset email sent:', info.messageId);
    return true;
  } catch (error) {
    console.error('❌ Error sending password reset email:', error);
    return false;
  }
};

// Middleware to verify JWT token (simplified for demo)
const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // For demo purposes, we'll accept any token
    // In production, you'd verify with a proper JWT library
    req.user = { uid: 'demo-user-123', email: 'demo@example.com' };
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    message: 'Server is running with SMTP email support',
    smtp_configured: !!process.env.SMTP_USER
  });
});

// Register user
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, firstName, lastName, role } = req.body;
    
    // Check if user already exists
    const existingUser = users.find(u => u.email === email);
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Create user
    const user = {
      id: users.length + 1,
      email,
      password, // In production, hash this password
      first_name: firstName,
      last_name: lastName,
      role: role || 'creator',
      is_email_verified: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    users.push(user);

    // Generate verification token
    const verificationToken = generateVerificationToken();
    verificationTokens.set(verificationToken, {
      email,
      userId: user.id,
      expires: Date.now() + 24 * 60 * 60 * 1000 // 24 hours
    });

    // Send verification email
    if (process.env.SMTP_USER) {
      await sendVerificationEmail(email, verificationToken);
    }

    res.json({
      message: 'User registered successfully. Please check your email to verify your account.',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_email_verified: user.is_email_verified
      }
    });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Login user
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const user = users.find(u => u.email === email && u.password === password);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // In production, generate a proper JWT token
    const token = 'demo-token-' + user.id;

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_email_verified: user.is_email_verified
      }
    });
  } catch (error) {
    console.error('Error logging in user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify email
app.post('/api/auth/verify-email', async (req, res) => {
  try {
    const { token } = req.body;
    
    const tokenData = verificationTokens.get(token);
    if (!tokenData || Date.now() > tokenData.expires) {
      return res.status(400).json({ error: 'Invalid or expired token' });
    }

    // Update user verification status
    const user = users.find(u => u.id === tokenData.userId);
    if (user) {
      user.is_email_verified = true;
      user.updated_at = new Date().toISOString();
    }

    // Remove used token
    verificationTokens.delete(token);

    res.json({ message: 'Email verified successfully' });
  } catch (error) {
    console.error('Error verifying email:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Resend verification email
app.post('/api/auth/resend-verification', async (req, res) => {
  try {
    const { email } = req.body;
    
    const user = users.find(u => u.email === email);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.is_email_verified) {
      return res.status(400).json({ error: 'Email already verified' });
    }

    // Generate new verification token
    const verificationToken = generateVerificationToken();
    verificationTokens.set(verificationToken, {
      email,
      userId: user.id,
      expires: Date.now() + 24 * 60 * 60 * 1000 // 24 hours
    });

    // Send verification email
    if (process.env.SMTP_USER) {
      await sendVerificationEmail(email, verificationToken);
    }

    res.json({ message: 'Verification email sent' });
  } catch (error) {
    console.error('Error resending verification email:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Forgot password
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    
    const user = users.find(u => u.email === email);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Generate reset token
    const resetToken = generateVerificationToken();
    verificationTokens.set(resetToken, {
      email,
      userId: user.id,
      type: 'password_reset',
      expires: Date.now() + 60 * 60 * 1000 // 1 hour
    });

    // Send reset email
    if (process.env.SMTP_USER) {
      await sendPasswordResetEmail(email, resetToken);
    }

    res.json({ message: 'Password reset email sent' });
  } catch (error) {
    console.error('Error sending password reset email:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user profile
app.get('/api/user/profile', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const user = users.find(u => u.id == uid);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      is_email_verified: user.is_email_verified,
      created_at: user.created_at,
      updated_at: user.updated_at
    });
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Proposals routes (same as before)
app.get('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const userProposals = proposals.filter(p => p.user_id === uid);
    res.json(userProposals);
  } catch (error) {
    console.error('Error fetching proposals:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { title, content, status, client_name } = req.body;
    
    const proposal = {
      id: proposals.length + 1,
      user_id: uid,
      title,
      content,
      status: status || 'draft',
      client_name,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    proposals.push(proposal);
    res.json(proposal);
  } catch (error) {
    console.error('Error creating proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📧 SMTP configured: ${!!process.env.SMTP_USER}`);
  console.log(`📝 API endpoints available at http://localhost:${PORT}/api/`);
});
