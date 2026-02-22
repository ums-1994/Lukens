#!/usr/bin/env python3
"""
Test similarity search results
"""

from risk_gate.vector_store.similarity_search import get_top_k_templates

def test_search():
    """Test similarity search with detailed results"""
    print("Testing similarity search...")
    
    # Search for business proposal
    results = get_top_k_templates('business proposal', k=3)
    
    print(f"\nFound {len(results)} results:")
    for i, result in enumerate(results):
        print(f"\n{i+1}. Template ID: {result.get('template_id', 'unknown')}")
        print(f"   Similarity Score: {result.get('similarity_score', 0):.3f}")
        print(f"   Content Length: {len(result.get('content', ''))}")
        print(f"   File Type: {result.get('metadata', {}).get('format', 'unknown')}")
    
    # Also check collection stats
    from risk_gate.vector_store.chroma_client import get_vector_store
    store = get_vector_store()
    stats = store.get_collection_stats()
    print(f"\nCollection Stats: {stats}")

if __name__ == "__main__":
    test_search()
