const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// SQLite database connection
const dbPath = path.join(__dirname, 'proposal_sow_builder.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('❌ Error opening database:', err.message);
  } else {
    console.log('✅ Connected to SQLite database');
    initializeDatabase();
  }
});

// Initialize database tables
function initializeDatabase() {
  const createTables = `
    -- Create users table
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        role TEXT NOT NULL CHECK (role IN ('creator', 'approver', 'admin', 'client', 'business_developer', 'reviewer_approver')),
        is_email_verified BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    -- Create verification tokens table
    CREATE TABLE IF NOT EXISTS verification_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        token TEXT UNIQUE NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create password reset tokens table
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        token TEXT UNIQUE NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create proposals table
    CREATE TABLE IF NOT EXISTS proposals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'archived')),
        client_name TEXT,
        client_email TEXT,
        budget REAL,
        timeline_days INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create SOWs table
    CREATE TABLE IF NOT EXISTS sows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'archived')),
        client_name TEXT,
        client_email TEXT,
        project_scope TEXT,
        deliverables TEXT,
        timeline TEXT,
        budget REAL,
        payment_terms TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create content library table
    CREATE TABLE IF NOT EXISTS content_library (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        tags TEXT,
        is_template BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create approvals table
    CREATE TABLE IF NOT EXISTS approvals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proposal_id INTEGER,
        sow_id INTEGER,
        approver_id INTEGER NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
        comments TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (sow_id) REFERENCES sows(id) ON DELETE CASCADE,
        FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE CASCADE,
        CHECK ((proposal_id IS NOT NULL AND sow_id IS NULL) OR (proposal_id IS NULL AND sow_id IS NOT NULL))
    );

    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_verification_tokens_user_id ON verification_tokens(user_id);
    CREATE INDEX IF NOT EXISTS idx_verification_tokens_token ON verification_tokens(token);
    CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
    CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
    CREATE INDEX IF NOT EXISTS idx_proposals_user_id ON proposals(user_id);
    CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
    CREATE INDEX IF NOT EXISTS idx_sows_user_id ON sows(user_id);
    CREATE INDEX IF NOT EXISTS idx_sows_status ON sows(status);
    CREATE INDEX IF NOT EXISTS idx_content_library_user_id ON content_library(user_id);
    CREATE INDEX IF NOT EXISTS idx_approvals_proposal_id ON approvals(proposal_id);
    CREATE INDEX IF NOT EXISTS idx_approvals_sow_id ON approvals(sow_id);
  `;

  db.exec(createTables, (err) => {
    if (err) {
      console.error('❌ Error creating tables:', err.message);
    } else {
      console.log('✅ Database tables initialized');
    }
  });
}

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
  const verificationUrl = `http://localhost:3000/verify-email?token=${token}`;
  
  const mailOptions = {
    from: `"Proposal SOW Builder" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Verify Your Email Address',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333;">Welcome to Proposal SOW Builder!</h2>
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
    from: `"Proposal SOW Builder" <${process.env.SMTP_USER}>`,
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
    // In production, verify with a proper JWT library
    req.user = { uid: 'demo-user-123', email: 'demo@example.com' };
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Helper function to run database queries with promises
const dbRun = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) reject(err);
      else resolve({ id: this.lastID, changes: this.changes });
    });
  });
};

const dbGet = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
};

const dbAll = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
};

// Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    message: 'Server is running with SQLite database and SMTP support',
    database_connected: true,
    smtp_configured: !!process.env.SMTP_USER
  });
});

// Register user
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, firstName, lastName, role } = req.body;
    
    // Check if user already exists
    const existingUser = await dbGet(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await dbRun(
      `INSERT INTO users (email, password_hash, first_name, last_name, role, is_email_verified, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
      [email, passwordHash, firstName, lastName, role || 'creator', 0]
    );

    // Generate verification token
    const verificationToken = generateVerificationToken();
    await dbRun(
      `INSERT INTO verification_tokens (user_id, token, expires_at, created_at)
       VALUES (?, ?, datetime('now', '+24 hours'), datetime('now'))`,
      [result.id, verificationToken]
    );

    // Send verification email
    if (process.env.SMTP_USER) {
      await sendVerificationEmail(email, verificationToken);
    }

    res.json({
      message: 'User registered successfully. Please check your email to verify your account.',
      user: {
        id: result.id,
        email: email,
        first_name: firstName,
        last_name: lastName,
        role: role || 'creator',
        is_email_verified: false
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
    
    const user = await dbGet(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
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
        is_email_verified: user.is_email_verified === 1
      }
    });
  } catch (error) {
    console.error('Error logging in user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Email verification page (GET endpoint for direct link access)
app.get('/verify-email', async (req, res) => {
  try {
    const { token } = req.query;
    
    if (!token) {
      return res.status(400).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h2 style="color: #dc3545;">Invalid Verification Link</h2>
            <p>No verification token provided.</p>
            <a href="http://localhost:8080" style="color: #007bff;">Return to App</a>
          </body>
        </html>
      `);
    }
    
    const tokenData = await dbGet(
      'SELECT * FROM verification_tokens WHERE token = ? AND expires_at > datetime("now")',
      [token]
    );
    
    if (!tokenData) {
      return res.status(400).send(`
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h2 style="color: #dc3545;">Invalid or Expired Token</h2>
            <p>This verification link is invalid or has expired.</p>
            <a href="http://localhost:8080" style="color: #007bff;">Return to App</a>
          </body>
        </html>
      `);
    }

    // Update user verification status
    await dbRun(
      'UPDATE users SET is_email_verified = 1, updated_at = datetime("now") WHERE id = ?',
      [tokenData.user_id]
    );

    // Remove used token
    await dbRun(
      'DELETE FROM verification_tokens WHERE id = ?',
      [tokenData.id]
    );

    res.send(`
      <html>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
          <h2 style="color: #28a745;">Email Verified Successfully!</h2>
          <p>Your email has been verified. You can now login to your account.</p>
          <a href="http://localhost:8080" style="color: #007bff; text-decoration: none; background: #007bff; color: white; padding: 10px 20px; border-radius: 5px;">Return to App</a>
        </body>
      </html>
    `);
  } catch (error) {
    console.error('Error verifying email:', error);
    res.status(500).send(`
      <html>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
          <h2 style="color: #dc3545;">Verification Error</h2>
          <p>An error occurred during email verification.</p>
          <a href="http://localhost:8080" style="color: #007bff;">Return to App</a>
        </body>
      </html>
    `);
  }
});

// Verify email (API endpoint)
app.post('/api/auth/verify-email', async (req, res) => {
  try {
    const { token } = req.body;
    
    const tokenData = await dbGet(
      'SELECT * FROM verification_tokens WHERE token = ? AND expires_at > datetime("now")',
      [token]
    );
    
    if (!tokenData) {
      return res.status(400).json({ error: 'Invalid or expired token' });
    }

    // Update user verification status
    await dbRun(
      'UPDATE users SET is_email_verified = 1, updated_at = datetime("now") WHERE id = ?',
      [tokenData.user_id]
    );

    // Remove used token
    await dbRun(
      'DELETE FROM verification_tokens WHERE id = ?',
      [tokenData.id]
    );

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
    
    const user = await dbGet(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.is_email_verified === 1) {
      return res.status(400).json({ error: 'Email already verified' });
    }

    // Generate new verification token
    const verificationToken = generateVerificationToken();
    await dbRun(
      `INSERT INTO verification_tokens (user_id, token, expires_at, created_at)
       VALUES (?, ?, datetime('now', '+24 hours'), datetime('now'))`,
      [user.id, verificationToken]
    );

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
    
    const user = await dbGet(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Generate reset token
    const resetToken = generateVerificationToken();
    await dbRun(
      `INSERT INTO password_reset_tokens (user_id, token, expires_at, created_at)
       VALUES (?, ?, datetime('now', '+1 hour'), datetime('now'))`,
      [user.id, resetToken]
    );

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
    const user = await dbGet(
      'SELECT * FROM users WHERE id = ?',
      [uid]
    );
    
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

// Proposals routes
app.get('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const proposals = await dbAll(
      'SELECT * FROM proposals WHERE user_id = ? ORDER BY created_at DESC',
      [uid]
    );
    res.json(proposals);
  } catch (error) {
    console.error('Error fetching proposals:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { title, content, status, client_name } = req.body;
    
    const result = await dbRun(
      `INSERT INTO proposals (user_id, title, content, status, client_name, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
      [uid, title, content, status || 'draft', client_name]
    );
    
    const proposal = await dbGet(
      'SELECT * FROM proposals WHERE id = ?',
      [result.id]
    );
    
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
  console.log(`🗄️  Database: SQLite (proposal_sow_builder.db)`);
  console.log(`📝 API endpoints available at http://localhost:${PORT}/api/`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down server...');
  db.close((err) => {
    if (err) {
      console.error('❌ Error closing database:', err.message);
    } else {
      console.log('✅ Database connection closed');
    }
    process.exit(0);
  });
});
