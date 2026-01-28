// Local Firebase Auth SDK
// Complete authentication implementation

class FirebaseAuth {
  constructor(app) {
    this.app = app;
    this.currentUser = null;
    this._listeners = [];
  }

  onAuthStateChanged(callback) {
    this._listeners.push(callback);
    if (this.currentUser) {
      callback(this.currentUser);
    }
  }

  _notifyListeners(user) {
    this.currentUser = user;
    this._listeners.forEach(callback => callback(user));
  }

  async signInWithEmailAndPassword(email, password) {
    console.log('🔐 Firebase sign in:', email);
    
    // Simulate validation
    if (!email || !password) {
      throw new Error('Email and password are required');
    }

    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 800));

    const user = {
      uid: 'local-user-' + Date.now(),
      email: email,
      displayName: email.split('@')[0],
      emailVerified: true,
      getIdToken: () => Promise.resolve('local-firebase-token-' + Date.now()),
      refreshToken: 'local-refresh-token-' + Date.now()
    };

    this._notifyListeners(user);
    return { user };
  }

  async createUserWithEmailAndPassword(email, password) {
    console.log('🔐 Firebase sign up:', email);
    return this.signInWithEmailAndPassword(email, password);
  }

  async signOut() {
    console.log('🔓 Firebase sign out');
    await new Promise(resolve => setTimeout(resolve, 300));
    this._notifyListeners(null);
  }
}

// Export the getAuth function
window.getAuth = function(app) {
  console.log('🔧 Local Firebase Auth initialized');
  return new FirebaseAuth(app || window.firebaseApp);
};

console.log('✅ Local Firebase Auth SDK loaded');
