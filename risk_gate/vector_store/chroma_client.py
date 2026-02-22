"""
ChromaDB Client for Risk Gate Vector Store
Persistent vector database for document indexing and similarity search
"""

import os
import uuid
from typing import List, Dict, Any, Optional, Tuple
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions

from .embedder import MiniLMEmbedder


class ChromaVectorStore:
    """ChromaDB-based vector store for risk gate documents"""
    
    def __init__(self, 
                 collection_name: str = "risk_gate_documents",
                 persist_directory: str = "./risk_gate/vector_store/chroma_db",
                 embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"):
        """
        Initialize ChromaDB vector store
        
        Args:
            collection_name: Name of the ChromaDB collection
            persist_directory: Directory to persist the database
            embedding_model: Hugging Face embedding model name
        """
        self.collection_name = collection_name
        self.persist_directory = persist_directory
        self.embedding_model = embedding_model
        
        # Initialize embedder
        self.embedder = MiniLMEmbedder(model_name=embedding_model)
        
        # Initialize ChromaDB client
        self.client = self._init_chroma_client()
        self.collection = self._get_or_create_collection()
        
    def _init_chroma_client(self) -> chromadb.Client:
        """Initialize ChromaDB client with persistent storage"""
        # Ensure persist directory exists
        os.makedirs(self.persist_directory, exist_ok=True)
        
        # Create client with persistent storage
        client = chromadb.PersistentClient(
            path=self.persist_directory,
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=False
            )
        )
        
        return client
    
    def _get_or_create_collection(self):
        """Get or create ChromaDB collection with custom embedding function"""
        try:
            # Try to get existing collection
            collection = self.client.get_collection(
                name=self.collection_name,
                embedding_function=self.embedder.get_chroma_embedding_function()
            )
            print(f"Loaded existing collection: {self.collection_name}")
        except Exception:
            # Create new collection if it doesn't exist
            collection = self.client.create_collection(
                name=self.collection_name,
                embedding_function=self.embedder.get_chroma_embedding_function(),
                metadata={"description": "Risk Gate document vectors"}
            )
            print(f"Created new collection: {self.collection_name}")
        
        return collection
    
    def index_documents(self, docs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Index documents in the vector store
        
        Args:
            docs: List of documents with 'content', 'metadata', and optional 'id'
            
        Returns:
            Dict with indexing results
        """
        if not docs:
            return {"indexed_count": 0, "error": "No documents provided"}
        
        try:
            # Prepare documents for indexing
            documents = []
            metadatas = []
            ids = []
            
            for doc in docs:
                # Extract content
                content = doc.get('content', '')
                if not content.strip():
                    continue
                
                # Generate or use provided ID
                doc_id = doc.get('id', str(uuid.uuid4()))
                
                # Prepare metadata
                metadata = doc.get('metadata', {})
                metadata.update({
                    'indexed_at': str(uuid.uuid4()),  # Unique timestamp
                    'content_length': len(content)
                })
                
                documents.append(content)
                metadatas.append(metadata)
                ids.append(doc_id)
            
            if not documents:
                return {"indexed_count": 0, "error": "No valid content found"}
            
            # Add documents to collection
            self.collection.add(
                documents=documents,
                metadatas=metadatas,
                ids=ids
            )
            
            # Get collection stats
            collection_count = self.collection.count()
            
            result = {
                "indexed_count": len(documents),
                "total_documents": collection_count,
                "collection_name": self.collection_name,
                "success": True
            }
            
            print(f"Successfully indexed {len(documents)} documents. Total: {collection_count}")
            return result
            
        except Exception as e:
            error_msg = f"Failed to index documents: {str(e)}"
            print(error_msg)
            return {"indexed_count": 0, "error": error_msg, "success": False}
    
    def query_similar(self, 
                     text: str, 
                     top_k: int = 3,
                     where_filter: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Query for similar documents
        
        Args:
            text: Query text
            top_k: Number of results to return
            where_filter: Optional metadata filter
            
        Returns:
            Dict with query results
        """
        try:
            # Query parameters
            query_params = {
                "query_texts": [text],
                "n_results": top_k
            }
            
            # Add metadata filter if provided
            if where_filter:
                query_params["where"] = where_filter
            
            # Execute query
            results = self.collection.query(**query_params)
            
            # Format results
            formatted_results = []
            if results['documents'] and results['documents'][0]:
                for i, doc in enumerate(results['documents'][0]):
                    result_item = {
                        "content": doc,
                        "metadata": results['metadatas'][0][i] if results['metadatas'] and results['metadatas'][0] else {},
                        "id": results['ids'][0][i] if results['ids'] and results['ids'][0] else "",
                        "distance": results['distances'][0][i] if results['distances'] and results['distances'][0] else 0.0
                    }
                    formatted_results.append(result_item)
            
            query_result = {
                "query": text,
                "results": formatted_results,
                "total_found": len(formatted_results),
                "top_k": top_k,
                "success": True
            }
            
            print(f"Query found {len(formatted_results)} similar documents")
            return query_result
            
        except Exception as e:
            error_msg = f"Query failed: {str(e)}"
            print(error_msg)
            return {"results": [], "error": error_msg, "success": False}
    
    def delete_documents(self, ids: List[str]) -> Dict[str, Any]:
        """
        Delete documents by IDs
        
        Args:
            ids: List of document IDs to delete
            
        Returns:
            Dict with deletion results
        """
        try:
            self.collection.delete(ids=ids)
            
            result = {
                "deleted_count": len(ids),
                "success": True
            }
            
            print(f"Deleted {len(ids)} documents")
            return result
            
        except Exception as e:
            error_msg = f"Deletion failed: {str(e)}"
            print(error_msg)
            return {"deleted_count": 0, "error": error_msg, "success": False}
    
    def get_collection_stats(self) -> Dict[str, Any]:
        """Get collection statistics"""
        try:
            count = self.collection.count()
            
            stats = {
                "collection_name": self.collection_name,
                "total_documents": count,
                "embedding_model": self.embedding_model,
                "persist_directory": self.persist_directory,
                "success": True
            }
            
            return stats
            
        except Exception as e:
            error_msg = f"Failed to get stats: {str(e)}"
            print(error_msg)
            return {"error": error_msg, "success": False}
    
    def clear_collection(self) -> Dict[str, Any]:
        """Clear all documents from the collection"""
        try:
            # Delete the entire collection
            self.client.delete_collection(name=self.collection_name)
            
            # Recreate the collection
            self.collection = self._get_or_create_collection()
            
            result = {
                "action": "collection_cleared",
                "collection_name": self.collection_name,
                "success": True
            }
            
            print(f"Cleared collection: {self.collection_name}")
            return result
            
        except Exception as e:
            error_msg = f"Failed to clear collection: {str(e)}"
            print(error_msg)
            return {"error": error_msg, "success": False}
    
    def update_document(self, doc_id: str, content: str = None, metadata: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Update an existing document
        
        Args:
            doc_id: Document ID to update
            content: New content (optional)
            metadata: New metadata (optional)
            
        Returns:
            Dict with update results
        """
        try:
            update_data = {}
            
            if content is not None:
                update_data["documents"] = [content]
            
            if metadata is not None:
                metadata.update({"updated_at": str(uuid.uuid4())})
                update_data["metadatas"] = [metadata]
            
            if not update_data:
                return {"updated": False, "error": "No updates provided"}
            
            self.collection.update(
                ids=[doc_id],
                **update_data
            )
            
            result = {
                "document_id": doc_id,
                "updated": True,
                "success": True
            }
            
            print(f"Updated document: {doc_id}")
            return result
            
        except Exception as e:
            error_msg = f"Update failed: {str(e)}"
            print(error_msg)
            return {"updated": False, "error": error_msg, "success": False}


# Global instance for easy access
_vector_store_instance = None

def get_vector_store(collection_name: str = "risk_gate_documents") -> ChromaVectorStore:
    """Get or create global vector store instance"""
    global _vector_store_instance
    if _vector_store_instance is None:
        _vector_store_instance = ChromaVectorStore(collection_name=collection_name)
    return _vector_store_instance

# Convenience functions
def index_documents(docs: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Index documents in the vector store
    
    Args:
        docs: List of documents with 'content' and optional 'metadata', 'id'
        
    Returns:
        Dict with indexing results
    """
    vector_store = get_vector_store()
    return vector_store.index_documents(docs)

def query_similar(text: str, top_k: int = 3, where_filter: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Query for similar documents
    
    Args:
        text: Query text
        top_k: Number of results to return
        where_filter: Optional metadata filter
        
    Returns:
        Dict with query results
    """
    vector_store = get_vector_store()
    return vector_store.query_similar(text, top_k, where_filter)
