#!/bin/bash
# Build script for Render deployment

echo "🔧 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install DocuSign requirements if present
if [ -f requirements_docusign.txt ]; then
    echo "📦 Installing DocuSign dependencies..."
    pip install -r requirements_docusign.txt
fi

echo "✅ Build complete!"








