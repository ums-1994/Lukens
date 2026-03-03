"""
MiniLM Embedder for Risk Gate Vector Store
Hugging Face sentence-transformers integration for document embeddings
"""

import os
import time
from typing import List, Union, Optional, Tuple, Dict, Any
import numpy as np
from sentence_transformers import SentenceTransformer
import chromadb
from chromadb.utils.embedding_functions import EmbeddingFunction


class MiniLMEmbedder:
    """Hugging Face MiniLM embedding model for risk gate documents"""
    
    def __init__(self, 
                 model_name: str = "sentence-transformers/all-MiniLM-L6-v2",
                 device: str = "cpu",
                 cache_dir: Optional[str] = None):
        """
        Initialize MiniLM embedder
        
        Args:
            model_name: Hugging Face model name
            device: Device to run inference on ('cpu' or 'cuda')
            cache_dir: Directory to cache the model
        """
        self.model_name = model_name
        self.device = device
        self.cache_dir = cache_dir or "./risk_gate/vector_store/model_cache"
        
        # Ensure cache directory exists
        os.makedirs(self.cache_dir, exist_ok=True)
        
        # Initialize model
        self.model = self._load_model()
        
        # Model info
        self.max_seq_length = self.model.max_seq_length
        self.embedding_dimension = self.model.get_sentence_embedding_dimension()
        
        print(f"Loaded MiniLM model: {model_name}")
        print(f"Embedding dimension: {self.embedding_dimension}")
        print(f"Max sequence length: {self.max_seq_length}")
    
    def _load_model(self) -> SentenceTransformer:
        """Load the sentence transformer model"""
        try:
            model = SentenceTransformer(
                self.model_name,
                device=self.device,
                cache_folder=self.cache_dir
            )
            return model
        except Exception as e:
            error_msg = f"Failed to load model {self.model_name}: {str(e)}"
            print(error_msg)
            raise RuntimeError(error_msg)
    
    def embed(self, texts: Union[str, List[str]]) -> Union[np.ndarray, List[np.ndarray]]:
        """
        Generate embeddings for text(s)
        
        Args:
            texts: Single text or list of texts to embed
            
        Returns:
            Embedding(s) as numpy array(s)
        """
        try:
            if isinstance(texts, str):
                # Single text
                embedding = self.model.encode(texts, convert_to_numpy=True)
                return embedding
            else:
                # List of texts
                embeddings = self.model.encode(texts, convert_to_numpy=True)
                return embeddings
                
        except Exception as e:
            error_msg = f"Embedding failed: {str(e)}"
            print(error_msg)
            raise RuntimeError(error_msg)
    
    def embed_batch(self, texts: List[str], batch_size: int = 32, show_progress: bool = False) -> List[np.ndarray]:
        """
        Generate embeddings for a batch of texts
        
        Args:
            texts: List of texts to embed
            batch_size: Batch size for processing
            show_progress: Whether to show progress bar
            
        Returns:
            List of embeddings as numpy arrays
        """
        try:
            embeddings = self.model.encode(
                texts,
                batch_size=batch_size,
                show_progress_bar=show_progress,
                convert_to_numpy=True
            )
            return embeddings.tolist() if isinstance(embeddings, np.ndarray) else embeddings
            
        except Exception as e:
            error_msg = f"Batch embedding failed: {str(e)}"
            print(error_msg)
            raise RuntimeError(error_msg)
    
    def get_embedding_dimension(self) -> int:
        """Get the embedding dimension"""
        return self.embedding_dimension
    
    def get_max_seq_length(self) -> int:
        """Get the maximum sequence length"""
        return self.max_seq_length
    
    def get_chroma_embedding_function(self) -> 'ChromaEmbeddingFunction':
        """Get ChromaDB-compatible embedding function"""
        return ChromaEmbeddingFunction(self)
    
    def similarity_search(self, 
                        query_embedding: np.ndarray, 
                        document_embeddings: List[np.ndarray],
                        top_k: int = 5) -> List[Tuple[int, float]]:
        """
        Find most similar documents using cosine similarity
        
        Args:
            query_embedding: Query embedding
            document_embeddings: List of document embeddings
            top_k: Number of top results to return
            
        Returns:
            List of (index, similarity_score) tuples
        """
        try:
            # Convert to numpy if needed
            if isinstance(document_embeddings, list):
                doc_embeddings_matrix = np.array(document_embeddings)
            else:
                doc_embeddings_matrix = document_embeddings
            
            # Calculate cosine similarity
            similarities = np.dot(doc_embeddings_matrix, query_embedding)
            
            # Get top-k indices
            top_indices = np.argsort(similarities)[::-1][:top_k]
            
            # Return (index, similarity) pairs
            results = [(int(idx), float(similarities[idx])) for idx in top_indices]
            
            return results
            
        except Exception as e:
            error_msg = f"Similarity search failed: {str(e)}"
            print(error_msg)
            return []
    
    def benchmark_embedding(self, sample_texts: List[str], runs: int = 3) -> Dict[str, float]:
        """
        Benchmark embedding performance
        
        Args:
            sample_texts: Sample texts for benchmarking
            runs: Number of benchmark runs
            
        Returns:
            Dict with performance metrics
        """
        try:
            times = []
            
            for _ in range(runs):
                start_time = time.time()
                self.embed_batch(sample_texts)
                end_time = time.time()
                times.append(end_time - start_time)
            
            avg_time = np.mean(times)
            texts_per_second = len(sample_texts) / avg_time
            
            metrics = {
                "avg_time_seconds": avg_time,
                "texts_per_second": texts_per_second,
                "total_texts": len(sample_texts),
                "runs": runs
            }
            
            print(f"Benchmark results: {texts_per_second:.2f} texts/second")
            return metrics
            
        except Exception as e:
            error_msg = f"Benchmark failed: {str(e)}"
            print(error_msg)
            return {"error": error_msg}
    
    def get_model_info(self) -> Dict[str, any]:
        """Get model information"""
        return {
            "model_name": self.model_name,
            "embedding_dimension": self.embedding_dimension,
            "max_seq_length": self.max_seq_length,
            "device": self.device,
            "cache_dir": self.cache_dir
        }


class ChromaEmbeddingFunction(EmbeddingFunction):
    """ChromaDB-compatible embedding function wrapper"""
    
    def __init__(self, embedder: MiniLMEmbedder):
        self.embedder = embedder
    
    def __call__(self, input: List[str]) -> List[List[float]]:
        """
        Generate embeddings for ChromaDB
        
        Args:
            input: List of texts to embed
            
        Returns:
            List of embedding vectors
        """
        try:
            embeddings = self.embedder.embed_batch(input)
            
            # Ensure embeddings are in the right format
            if isinstance(embeddings, np.ndarray):
                return embeddings.tolist()
            elif isinstance(embeddings, list):
                return [emb.tolist() if isinstance(emb, np.ndarray) else emb for emb in embeddings]
            else:
                return embeddings
                
        except Exception as e:
            error_msg = f"Chroma embedding function failed: {str(e)}"
            print(error_msg)
            # Return zero embeddings as fallback
            return [[0.0] * self.embedder.get_embedding_dimension() for _ in input]


# Global embedder instance
_embedder_instance = None

def get_embedder(model_name: str = "sentence-transformers/all-MiniLM-L6-v2") -> MiniLMEmbedder:
    """Get or create global embedder instance"""
    global _embedder_instance
    if _embedder_instance is None:
        _embedder_instance = MiniLMEmbedder(model_name=model_name)
    return _embedder_instance

# Convenience functions
def embed_texts(texts: Union[str, List[str]]) -> Union[np.ndarray, List[np.ndarray]]:
    """Generate embeddings for text(s)"""
    embedder = get_embedder()
    return embedder.embed(texts)

def get_embedding_info() -> Dict[str, any]:
    """Get embedding model information"""
    embedder = get_embedder()
    return embedder.get_model_info()
