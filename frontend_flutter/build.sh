#!/bin/bash
# Build script for Flutter web on Render

echo "🔧 Setting up Flutter..."
export PATH="$PATH:/usr/local/flutter/bin"

# Get Flutter if not already available
if ! command -v flutter &> /dev/null; then
    echo "📥 Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
    export PATH="$PATH:/usr/local/flutter/bin"
fi

echo "🔧 Configuring Flutter for web..."
flutter config --enable-web
flutter doctor

echo "📦 Getting dependencies..."
flutter pub get

echo "🏗️ Building Flutter web app..."
# Use the API URL from environment variable or default
API_URL=${REACT_APP_API_URL:-https://lukens-backend.onrender.com}
echo "🌐 Using API URL: $API_URL"

# Build with release mode
flutter build web --release --base-href /

echo "✅ Build complete!"










