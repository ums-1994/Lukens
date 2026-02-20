"""
Risk Gate Vector Store Package
ChromaDB and Hugging Face MiniLM integration for document indexing and similarity search
"""

from .chroma_client import ChromaVectorStore, get_vector_store, index_documents, query_similar
from .embedder import MiniLMEmbedder, get_embedder, embed_texts, get_embedding_info

__all__ = [
    'ChromaVectorStore',
    'get_vector_store', 
    'index_documents',
    'query_similar',
    'MiniLMEmbedder',
    'get_embedder',
    'embed_texts',
    'get_embedding_info'
]

# Package version
__version__ = "1.0.0"

# Package description
__description__ = "Risk Gate Vector Store with ChromaDB and MiniLM embeddings"
