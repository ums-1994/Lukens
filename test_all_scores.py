#!/usr/bin/env python3
"""
Test all similarity scores
"""

from risk_gate.vector_store.chroma_client import get_vector_store
from risk_gate.vector_store.embedder import get_embedder

def test_all_similarities():
    """Test similarity scores for all documents"""
    print("Testing similarity scores for all indexed documents...")
    
    # Get vector store and embedder
    store = get_vector_store("proposal_templates")
    embedder = get_embedder()
    
    # Get all documents from collection
    collection = store.collection
    all_docs = collection.get()
    
    # Embed our query
    query = "business proposal"
    query_embedding = embedder.embed([query])[0]
    
    # Query for all documents (no threshold)
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=3,
        include=['documents', 'metadatas', 'distances']
    )
    
    print(f"\nQuery: '{query}'")
    print(f"Found {len(results['ids'][0])} documents:")
    
    for i, (doc_id, metadata, distance) in enumerate(zip(
        results['ids'][0], 
        results['metadatas'][0], 
        results['distances'][0]
    )):
        # Try different similarity calculations
        cosine_similarity = 1 - distance  # Standard cosine
        euclidean_similarity = 1 / (1 + distance)  # For Euclidean distance
        squared_cosine_similarity = 1 - (distance ** 0.5)  # For squared cosine distance
        
        print(f"\n{i+1}. Template ID: {metadata.get('template_id', doc_id)}")
        print(f"   File Type: {metadata.get('format', 'unknown')}")
        print(f"   Raw Distance: {distance:.4f}")
        print(f"   Cosine Similarity (1-distance): {cosine_similarity:.4f}")
        print(f"   Squared Cosine Similarity (1-sqrt(dist)): {squared_cosine_similarity:.4f}")
        print(f"   Euclidean Similarity (1/(1+dist)): {euclidean_similarity:.4f}")
        print(f"   Above 0.3 Threshold (Squared Cosine): {squared_cosine_similarity >= 0.3}")
        print(f"   Content Preview: {results['documents'][0][i][:100]}...")

if __name__ == "__main__":
    test_all_similarities()
