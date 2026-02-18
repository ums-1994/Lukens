#!/usr/bin/env python3
"""
Simple test script for similarity search functionality
"""

import sys
import os

# Add the project root to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_imports():
    """Test if all imports work"""
    try:
        print("Testing imports...")
        
        # Test basic imports
        from risk_gate.vector_store.similarity_search import get_top_k_templates
        from risk_gate.vector_store.chroma_client import get_vector_store
        from risk_gate.vector_store.embedder import get_embedder
        
        print("✅ All imports successful!")
        return True
        
    except Exception as e:
        print(f"❌ Import failed: {e}")
        return False

def test_basic_functionality():
    """Test basic similarity search functionality"""
    try:
        print("\nTesting basic functionality...")
        
        # Test embedder
        from risk_gate.vector_store.embedder import get_embedder
        embedder = get_embedder()
        print(f"✅ Embedder loaded: {embedder.get_model_info()}")
        
        # Test vector store (will create empty collection)
        from risk_gate.vector_store.chroma_client import get_vector_store
        vector_store = get_vector_store("test_collection")
        stats = vector_store.get_collection_stats()
        print(f"✅ Vector store ready: {stats}")
        
        # Test similarity search (will return empty results since no data)
        from risk_gate.vector_store.similarity_search import get_top_k_templates
        results = get_top_k_templates("test query", k=3, collection_name="test_collection")
        print(f"✅ Similarity search works: {len(results)} results (expected 0)")
        
        return True
        
    except Exception as e:
        print(f"❌ Functionality test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main test function"""
    print("🚀 Risk Gate Vector Store Test")
    print("=" * 40)
    
    # Test imports
    if not test_imports():
        sys.exit(1)
    
    # Test basic functionality
    if not test_basic_functionality():
        sys.exit(1)
    
    print("\n🎉 All tests passed!")
    print("\nNext steps:")
    print("1. Run: python risk_gate/vector_store/index_templates.py --help")
    print("2. Index your Cloudinary templates")
    print("3. Test similarity search with real data")

if __name__ == "__main__":
    main()
