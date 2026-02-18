#!/usr/bin/env python3
"""
Test with lower threshold to see actual results
"""

from risk_gate.vector_store.similarity_search import get_top_k_templates

def test_low_threshold():
    """Test with very low threshold to see all results"""
    print("Testing with low threshold...")
    
    # Temporarily modify the threshold
    from risk_gate.vector_store.similarity_search import TemplateSimilaritySearch
    search = TemplateSimilaritySearch()
    search.similarity_threshold = 0.0  # No threshold
    
    # Search for business proposal
    results = search.get_top_k_templates('business proposal', k=3)
    
    print(f"\nFound {len(results)} results with no threshold:")
    for i, result in enumerate(results):
        print(f"\n{i+1}. Template ID: {result.template_id}")
        print(f"   Similarity Score: {result.similarity_score:.4f}")
        print(f"   Content Length: {len(result.content)}")
        print(f"   File Type: {result.metadata.get('format', 'unknown')}")

if __name__ == "__main__":
    test_low_threshold()
