const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

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

// Middleware to verify Firebase token (simplified for demo)
const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // For demo purposes, we'll accept any token
    // In production, you'd verify with Firebase Admin SDK
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
    message: 'Server is running without database (demo mode)'
  });
});

// Get user profile
app.get('/api/user/profile', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const user = users.find(u => u.firebase_uid === uid);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(user);
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
    
    const userData = {
      firebase_uid: uid,
      email: email,
      first_name: firstName,
      last_name: lastName,
      role: role,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    const existingUserIndex = users.findIndex(u => u.firebase_uid === uid);
    if (existingUserIndex >= 0) {
      users[existingUserIndex] = { ...users[existingUserIndex], ...userData };
    } else {
      users.push(userData);
    }
    
    res.json(userData);
  } catch (error) {
    console.error('Error creating/updating user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Proposals routes
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

app.put('/api/proposals/:id', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { id } = req.params;
    const { title, content, status, client_name } = req.body;
    
    const proposalIndex = proposals.findIndex(p => p.id == id && p.user_id === uid);
    
    if (proposalIndex === -1) {
      return res.status(404).json({ error: 'Proposal not found' });
    }
    
    proposals[proposalIndex] = {
      ...proposals[proposalIndex],
      title,
      content,
      status,
      client_name,
      updated_at: new Date().toISOString()
    };
    
    res.json(proposals[proposalIndex]);
  } catch (error) {
    console.error('Error updating proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/api/proposals/:id', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { id } = req.params;
    
    const proposalIndex = proposals.findIndex(p => p.id == id && p.user_id === uid);
    
    if (proposalIndex === -1) {
      return res.status(404).json({ error: 'Proposal not found' });
    }
    
    proposals.splice(proposalIndex, 1);
    res.json({ message: 'Proposal deleted successfully' });
  } catch (error) {
    console.error('Error deleting proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// SOWs routes
app.get('/api/sows', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const userSows = sows.filter(s => s.user_id === uid);
    res.json(userSows);
  } catch (error) {
    console.error('Error fetching SOWs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/sows', verifyToken, async (req, res) => {
  try {
    const { uid } = req.user;
    const { title, content, status, client_name, project_scope, deliverables, timeline, budget } = req.body;
    
    const sow = {
      id: sows.length + 1,
      user_id: uid,
      title,
      content,
      status: status || 'draft',
      client_name,
      project_scope,
      deliverables,
      timeline,
      budget,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    sows.push(sow);
    res.json(sow);
  } catch (error) {
    console.error('Error creating SOW:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔧 Demo mode: No database required`);
  console.log(`📝 API endpoints available at http://localhost:${PORT}/api/`);
});
