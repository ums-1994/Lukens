const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { Pool } = require('pg');
const admin = require('firebase-admin');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: true, // Allow all origins for development
  credentials: true
}));

// Better JSON parsing with error handling
app.use(express.json({ 
  limit: '10mb',
  verify: (req, res, buf) => {
    try {
      JSON.parse(buf);
    } catch (e) {
      console.error('JSON parsing error:', e.message);
      console.error('Raw body:', buf.toString());
    }
  }
}));
app.use(express.urlencoded({ extended: true }));

// Initialize Firebase Admin
let serviceAccount;
try {
  serviceAccount = require('./firebase-service-account.json');
} catch (error) {
  console.log('Firebase service account not found. Using environment variables...');
  serviceAccount = {
    type: "service_account",
    project_id: process.env.FIREBASE_PROJECT_ID || "lukens-e17d6",
    private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
    private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
    client_id: process.env.FIREBASE_CLIENT_ID,
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL}`
  };
}

if (serviceAccount && serviceAccount.project_id) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('Firebase Admin initialized successfully');
} else {
  console.log('Firebase Admin not initialized - authentication will be disabled');
}

// PostgreSQL connection
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'proposal_sow_builder',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
});

// Firebase handles email verification automatically

// Test database connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to PostgreSQL:', err);
  } else {
    console.log('Connected to PostgreSQL database');
    release();
  }
});

// Middleware to verify Firebase token
const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    if (!admin.apps.length) {
      console.log('Firebase Admin not initialized, skipping token verification');
      // For development, allow requests without Firebase Admin
      req.user = { uid: 'dev-user', email: 'dev@example.com' };
      return next();
    }

    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Token verification error:', error);
    // For development, allow requests even if token verification fails
    if (process.env.NODE_ENV === 'development') {
      console.log('Development mode: allowing request despite token error');
      req.user = { uid: 'dev-user', email: 'dev@example.com' };
      return next();
    }
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Add sample data endpoint for development
app.post('/api/dev/sample-data', async (req, res) => {
  try {
    const { uid } = req.body;
    if (!uid) {
      return res.status(400).json({ error: 'User ID required' });
    }

    // Check if user exists, if not create one
    const userResult = await pool.query(
      'SELECT id FROM users WHERE firebase_uid = $1',
      [uid]
    );

    if (userResult.rows.length === 0) {
      await pool.query(
        'INSERT INTO users (firebase_uid, email, first_name, last_name, role, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())',
        [uid, 'dev@example.com', 'Dev', 'User', 'creator']
      );
    }

    // Add sample proposals
    const sampleProposals = [
      {
        title: 'Website Redesign Proposal',
        content: 'Complete website redesign for improved user experience and modern design.',
        status: 'draft',
        client_name: 'ABC Company',
        budget: 5000.00,
        timeline_days: 30
      },
      {
        title: 'Mobile App Development',
        content: 'Native mobile app development for iOS and Android platforms.',
        status: 'submitted',
        client_name: 'XYZ Corp',
        budget: 15000.00,
        timeline_days: 90
      },
      {
        title: 'E-commerce Platform',
        content: 'Full e-commerce solution with payment integration and inventory management.',
        status: 'approved',
        client_name: 'Retail Solutions',
        budget: 25000.00,
        timeline_days: 120
      }
    ];

    for (const proposal of sampleProposals) {
      await pool.query(
        'INSERT INTO proposals (user_id, title, content, status, client_name, budget, timeline_days, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())',
        [uid, proposal.title, proposal.content, proposal.status, proposal.client_name, proposal.budget, proposal.timeline_days]
      );
    }

    res.json({ message: 'Sample data added successfully' });
  } catch (error) {
    console.error('Error adding sample data:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Firebase handles email verification - no test endpoint needed

// Authentication endpoints (Firebase handles authentication and email verification)
app.post('/api/auth/register', async (req, res) => {
  try {
    // Firebase handles user registration and email verification
    // This endpoint is just for creating user profile after Firebase registration
    res.json({
      message: 'Use Firebase registration on the client side',
      note: 'Firebase will handle email verification automatically'
    });
  } catch (error) {
    console.error('Error in register endpoint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    // Firebase handles authentication on the client side
    // This endpoint is just for getting user profile after Firebase login
    res.json({
      message: 'Use Firebase authentication on the client side',
      note: 'This endpoint is not needed for Firebase auth'
    });
  } catch (error) {
    console.error('Error in login endpoint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user profile
app.get('/api/user/profile', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const result = await pool.query(
      'SELECT * FROM users WHERE firebase_uid = $1',
      [uid]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create or update user profile
app.post('/api/user/profile', verifyToken, async (req, res) => {
  try {
    const { uid, email } = req.user;
    const { firstName, lastName, role } = req.body;
    
    const result = await pool.query(
      `INSERT INTO users (firebase_uid, email, first_name, last_name, role, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       ON CONFLICT (firebase_uid) 
       DO UPDATE SET 
         email = EXCLUDED.email,
         first_name = EXCLUDED.first_name,
         last_name = EXCLUDED.last_name,
         role = EXCLUDED.role,
         updated_at = NOW()
       RETURNING *`,
      [uid, email, firstName, lastName, role]
    );
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error creating/updating user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Proposals routes
app.get('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    console.log('Fetching proposals for user:', uid);
    
    const result = await pool.query(
      'SELECT * FROM proposals WHERE user_id = $1 ORDER BY created_at DESC',
      [uid]
    );
    
    console.log('Found proposals:', result.rows.length);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching proposals:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/proposals', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { title, content, status, client_name } = req.body;
    
    const result = await pool.query(
      `INSERT INTO proposals (user_id, title, content, status, client_name, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       RETURNING *`,
      [uid, title, content, status || 'draft', client_name]
    );
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error creating proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/proposals/:id', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { id } = req.params;
    const { title, content, status, client_name } = req.body;
    
    const result = await pool.query(
      `UPDATE proposals 
       SET title = $1, content = $2, status = $3, client_name = $4, updated_at = NOW()
       WHERE id = $5 AND user_id = $6
       RETURNING *`,
      [title, content, status, client_name, id, uid]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Proposal not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/api/proposals/:id', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { id } = req.params;
    
    const result = await pool.query(
      'DELETE FROM proposals WHERE id = $1 AND user_id = $2 RETURNING *',
      [id, uid]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Proposal not found' });
    }
    
    res.json({ message: 'Proposal deleted successfully' });
  } catch (error) {
    console.error('Error deleting proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// SOWs routes (similar structure)
app.get('/api/sows', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const result = await pool.query(
      'SELECT * FROM sows WHERE user_id = $1 ORDER BY created_at DESC',
      [uid]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching SOWs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/sows', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { title, content, status, client_name, project_scope, deliverables, timeline, budget } = req.body;
    
    const result = await pool.query(
      `INSERT INTO sows (user_id, title, content, status, client_name, project_scope, deliverables, timeline, budget, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
       RETURNING *`,
      [uid, title, content, status || 'draft', client_name, project_scope, deliverables, timeline, budget]
    );
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error creating SOW:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
