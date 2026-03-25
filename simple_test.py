#!/usr/bin/env python3
"""
Simple test without logger dependency
"""

import sys
import os

# Add the project root to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_embedder():
    """Test just the embedder"""
    try:
        print("Testing embedder...")
        
        # Import embedder directly
        from risk_gate.vector_store.embedder import MiniLMEmbedder
        
        # Create embedder instance
        embedder = MiniLMEmbedder()
        print(f"✅ Embedder created successfully!")
        print(f"   Model: {embedder.model_name}")
        print(f"   Dimension: {embedder.embedding_dimension}")
        
        # Test embedding
        test_text = "This is a test sentence for embedding."
        embedding = embedder.embed(test_text)
        print(f"✅ Embedding generated: {len(embedding)} dimensions")
        
        return True
        
    except Exception as e:
        print(f"❌ Embedder test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_basic_similarity():
    """Test basic similarity without ChromaDB"""
    try:
        print("\nTesting basic similarity...")
        
        from risk_gate.vector_store.embedder import MiniLMEmbedder
        
        embedder = MiniLMEmbedder()
        
        # Test texts
        text1 = "Business proposal for client services"
        text2 = "Commercial proposal for business services"
        text3 = "Recipe for chocolate cake"
        
        # Generate embeddings
        emb1 = embedder.embed(text1)
        emb2 = embedder.embed(text2)
        emb3 = embedder.embed(text3)
        
        # Calculate cosine similarity manually
        import numpy as np
        
        def cosine_similarity(a, b):
            return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
        
        sim12 = cosine_similarity(emb1, emb2)
        sim13 = cosine_similarity(emb1, emb3)
        
        print(f"✅ Similarity between similar texts: {sim12:.3f}")
        print(f"✅ Similarity between different texts: {sim13:.3f}")
        
        if sim12 > sim13:
            print("✅ Similarity test passed - similar texts have higher similarity!")
            return True
        else:
            print("❌ Similarity test failed")
            return False
        
    except Exception as e:
        print(f"❌ Similarity test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main test function"""
    print("🚀 Simple Risk Gate Embedding Test")
    print("=" * 40)
    
    # Test embedder
    if not test_embedder():
        sys.exit(1)
    
    # Test similarity
    if not test_basic_similarity():
        sys.exit(1)
    
    print("\n🎉 All embedding tests passed!")
    print("The core embedding functionality is working correctly.")

if __name__ == "__main__":
    main()
