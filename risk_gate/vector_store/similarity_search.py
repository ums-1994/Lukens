"""
Similarity Search for Risk Gate Templates
Find top-k similar templates using vector embeddings
"""

import time
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass

from .chroma_client import get_vector_store, ChromaVectorStore
from .embedder import get_embedder, MiniLMEmbedder
from ..logger import get_risk_logger


@dataclass
class TemplateMatch:
    """Template match result with similarity score"""
    template_id: str
    content: str
    similarity_score: float
    metadata: Dict[str, Any]
    distance: float  # ChromaDB distance (lower = more similar)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "template_id": self.template_id,
            "content": self.content,
            "similarity_score": self.similarity_score,
            "distance": self.distance,
            "metadata": self.metadata
        }


class TemplateSimilaritySearch:
    """Similarity search for proposal templates"""
    
    def __init__(self, 
                 collection_name: str = "proposal_templates",
                 embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2",
                 similarity_threshold: float = 0.3):
        """
        Initialize similarity search
        
        Args:
            collection_name: ChromaDB collection name
            embedding_model: Embedding model name
            similarity_threshold: Minimum similarity threshold for results
        """
        self.collection_name = collection_name
        self.embedding_model = embedding_model
        self.similarity_threshold = similarity_threshold
        
        # Initialize components
        self.logger = get_risk_logger()
        self.vector_store = None
        self.embedder = None
        
        self._initialize_components()
    
    def _initialize_components(self):
        """Initialize vector store and embedder"""
        try:
            self.vector_store = get_vector_store(self.collection_name)
            self.embedder = get_embedder(self.embedding_model)
            
            self.logger.log_event("similarity_search_initialized", {
                "collection_name": self.collection_name,
                "embedding_model": self.embedding_model,
                "similarity_threshold": self.similarity_threshold
            })
            
        except Exception as e:
            self.logger.log_error("similarity_search_init_failed", e)
            raise
    
    def get_top_k_templates(self, 
                          query_text: str, 
                          k: int = 3,
                          filters: Optional[Dict[str, Any]] = None,
                          include_content: bool = True,
                          max_content_length: int = 1000) -> List[TemplateMatch]:
        """
        Get top-k similar templates for query text
        
        Args:
            query_text: Input query text
            k: Number of top results to return
            filters: Optional metadata filters
            include_content: Whether to include full content in results
            max_content_length: Maximum content length to return
            
        Returns:
            List of TemplateMatch objects sorted by similarity
        """
        start_time = time.time()
        
        try:
            self.logger.log_event("similarity_search_started", {
                "query_length": len(query_text),
                "k": k,
                "filters": filters,
                "include_content": include_content
            })
            
            # Validate inputs
            if not query_text or not query_text.strip():
                self.logger.log_event("empty_query", {"query_text": query_text})
                return []
            
            # Query vector store
            query_result = self.vector_store.query_similar(
                text=query_text,
                top_k=k,
                where_filter=filters
            )
            
            if not query_result.get("success", False):
                error = query_result.get("error", "Unknown error")
                self.logger.log_event("query_failed", {"error": error})
                return []
            
            # Convert results to TemplateMatch objects
            matches = []
            for result in query_result.get("results", []):
                try:
                    # Calculate similarity score from distance
                    distance = result.get("distance", 1.0)
                    similarity_score = self._distance_to_similarity(distance)
                    
                    # Apply similarity threshold
                    if similarity_score < self.similarity_threshold:
                        continue
                    
                    # Prepare content
                    content = result.get("content", "")
                    if not include_content:
                        content = "[Content hidden]"
                    elif len(content) > max_content_length:
                        content = content[:max_content_length] + "..."
                    
                    # Create match object
                    match = TemplateMatch(
                        template_id=result.get("id", ""),
                        content=content,
                        similarity_score=similarity_score,
                        distance=distance,
                        metadata=result.get("metadata", {})
                    )
                    
                    matches.append(match)
                    
                except Exception as e:
                    self.logger.log_error("match_conversion_failed", e, {
                        "result": result
                    })
                    continue
            
            # Sort by similarity score (highest first)
            matches.sort(key=lambda x: x.similarity_score, reverse=True)
            
            execution_time = time.time() - start_time
            
            self.logger.log_event("similarity_search_completed", {
                "query_text": query_text[:100] + "..." if len(query_text) > 100 else query_text,
                "results_found": len(matches),
                "execution_time": execution_time,
                "top_similarity": matches[0].similarity_score if matches else 0.0
            })
            
            return matches
            
        except Exception as e:
            self.logger.log_error("similarity_search_failed", e, {
                "query_text": query_text[:100]
            })
            return []
    
    def _distance_to_similarity(self, distance: float) -> float:
        """
        Convert ChromaDB distance to similarity score
        
        For now, use a simple inverse distance approach.
        Lower distance = higher similarity
        """
        # Simple inverse similarity: higher distance = lower similarity
        # This works for most distance metrics (cosine, euclidean, etc.)
        if distance <= 0:
            return 1.0  # Perfect match
        else:
            # Use 1/(1+distance) which gives values in (0, 1]
            similarity = 1.0 / (1.0 + distance)
            return similarity
    
    def search_by_metadata(self,
                          filters: Dict[str, Any],
                          k: int = 10) -> List[TemplateMatch]:
        """
        Search templates by metadata filters only
        
        Args:
            filters: Metadata filters to apply
            k: Maximum number of results
            
        Returns:
            List of TemplateMatch objects
        """
        try:
            # Use a generic query to get all matching documents
            query_result = self.vector_store.query_similar(
                text="template",  # Generic query term
                top_k=k,
                where_filter=filters
            )
            
            matches = []
            for result in query_result.get("results", []):
                distance = result.get("distance", 1.0)
                similarity_score = self._distance_to_similarity(distance)
                
                match = TemplateMatch(
                    template_id=result.get("id", ""),
                    content=result.get("content", ""),
                    similarity_score=similarity_score,
                    distance=distance,
                    metadata=result.get("metadata", {})
                )
                matches.append(match)
            
            return matches
            
        except Exception as e:
            self.logger.log_error("metadata_search_failed", e, {"filters": filters})
            return []
    
    def get_similar_by_id(self, 
                         template_id: str, 
                         k: int = 3) -> List[TemplateMatch]:
        """
        Find templates similar to a specific template by ID
        
        Args:
            template_id: ID of the reference template
            k: Number of similar templates to return
            
        Returns:
            List of TemplateMatch objects
        """
        try:
            # Get the reference template
            query_result = self.vector_store.query_similar(
                text="template content",
                top_k=1,
                where_filter={"template_id": template_id}
            )
            
            if not query_result.get("success", False) or not query_result.get("results"):
                self.logger.log_event("template_not_found", {"template_id": template_id})
                return []
            
            # Use the content of the reference template for similarity search
            reference_content = query_result["results"][0].get("content", "")
            
            if not reference_content:
                self.logger.log_event("empty_template_content", {"template_id": template_id})
                return []
            
            # Find similar templates (excluding the reference itself)
            similar_templates = self.get_top_k_templates(
                query_text=reference_content,
                k=k + 1,  # Get one extra to exclude the reference
                filters={"template_id": {"$ne": template_id}}  # Exclude reference
            )
            
            return similar_templates[:k]  # Return only k results
            
        except Exception as e:
            self.logger.log_error("similar_by_id_failed", e, {"template_id": template_id})
            return []
    
    def hybrid_search(self,
                     query_text: str,
                     keyword_filters: List[str],
                     k: int = 3,
                     keyword_weight: float = 0.3) -> List[TemplateMatch]:
        """
        Hybrid search combining semantic similarity and keyword matching
        
        Args:
            query_text: Input query text
            keyword_filters: List of keywords that must be present
            k: Number of results to return
            keyword_weight: Weight for keyword matching (0-1)
            
        Returns:
            List of TemplateMatch objects with hybrid scores
        """
        try:
            # Get semantic similarity results
            semantic_matches = self.get_top_k_templates(query_text, k * 2)
            
            # Filter by keywords and calculate keyword scores
            hybrid_matches = []
            query_lower = query_text.lower()
            
            for match in semantic_matches:
                content_lower = match.content.lower()
                
                # Calculate keyword match score
                keyword_matches = sum(1 for keyword in keyword_filters if keyword.lower() in content_lower)
                keyword_score = keyword_matches / len(keyword_filters) if keyword_filters else 0.0
                
                # Calculate hybrid score
                semantic_score = match.similarity_score
                hybrid_score = (semantic_score * (1 - keyword_weight)) + (keyword_score * keyword_weight)
                
                # Update match with hybrid score
                match.similarity_score = hybrid_score
                match.metadata["hybrid_score"] = hybrid_score
                match.metadata["semantic_score"] = semantic_score
                match.metadata["keyword_score"] = keyword_score
                match.metadata["keyword_matches"] = keyword_matches
                
                hybrid_matches.append(match)
            
            # Sort by hybrid score and return top k
            hybrid_matches.sort(key=lambda x: x.similarity_score, reverse=True)
            
            return hybrid_matches[:k]
            
        except Exception as e:
            self.logger.log_error("hybrid_search_failed", e, {
                "query_text": query_text[:100],
                "keyword_filters": keyword_filters
            })
            return []
    
    def get_search_statistics(self) -> Dict[str, Any]:
        """Get statistics about the search system"""
        try:
            collection_stats = self.vector_store.get_collection_stats()
            embedder_info = self.embedder.get_model_info()
            
            stats = {
                "collection_stats": collection_stats,
                "embedding_model": embedder_info,
                "similarity_threshold": self.similarity_threshold,
                "collection_name": self.collection_name
            }
            
            return stats
            
        except Exception as e:
            self.logger.log_error("stats_generation_failed", e)
            return {"error": str(e)}
    
    def benchmark_search(self, 
                        test_queries: List[str],
                        k: int = 3) -> Dict[str, Any]:
        """
        Benchmark search performance
        
        Args:
            test_queries: List of test queries
            k: Number of results per query
            
        Returns:
            Performance statistics
        """
        try:
            times = []
            total_results = 0
            
            for query in test_queries:
                start_time = time.time()
                results = self.get_top_k_templates(query, k)
                end_time = time.time()
                
                times.append(end_time - start_time)
                total_results += len(results)
            
            avg_time = np.mean(times)
            avg_results = total_results / len(test_queries)
            queries_per_second = 1.0 / avg_time
            
            benchmark_stats = {
                "total_queries": len(test_queries),
                "avg_time_seconds": avg_time,
                "avg_results_per_query": avg_results,
                "queries_per_second": queries_per_second,
                "total_results": total_results,
                "k": k
            }
            
            self.logger.log_event("search_benchmark_completed", benchmark_stats)
            
            return benchmark_stats
            
        except Exception as e:
            self.logger.log_error("benchmark_failed", e)
            return {"error": str(e)}


# Global search instance
_search_instance = None

def get_template_search(collection_name: str = "proposal_templates") -> TemplateSimilaritySearch:
    """Get or create global template search instance"""
    global _search_instance
    if _search_instance is None:
        _search_instance = TemplateSimilaritySearch(collection_name=collection_name)
    return _search_instance

def get_top_k_templates(query_text: str, 
                       k: int = 3,
                       filters: Optional[Dict[str, Any]] = None,
                       collection_name: str = "proposal_templates") -> List[Dict[str, Any]]:
    """
    Convenience function to get top-k similar templates
    
    Args:
        query_text: Input query text
        k: Number of results to return
        filters: Optional metadata filters
        collection_name: ChromaDB collection name
        
    Returns:
        List of template match dictionaries
    """
    search = get_template_search(collection_name)
    matches = search.get_top_k_templates(query_text, k, filters)
    
    return [match.to_dict() for match in matches]
