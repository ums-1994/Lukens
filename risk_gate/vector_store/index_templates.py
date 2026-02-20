"""
Index Local Templates into ChromaDB
Script to load templates from local folder, generate embeddings, and insert into vector store
"""

import os
import time
import argparse
from typing import List, Dict, Any, Optional
from datetime import datetime

# Import risk gate components
try:
    from ..template_loader import load_proposal_templates, get_template_loader
    from ..logger import get_risk_logger
except ImportError:
    # Fallback for direct script execution
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from risk_gate.template_loader import load_proposal_templates, get_template_loader
    from risk_gate.logger import get_risk_logger

from .chroma_client import get_vector_store, ChromaVectorStore
from .embedder import get_embedder


class TemplateIndexer:
    """Indexes Cloudinary templates into ChromaDB vector store"""
    
    def __init__(self, 
                 collection_name: str = "proposal_templates",
                 template_folder: str = "templates",
                 embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2",
                 chroma_persist_dir: str = "./risk_gate/vector_store/chroma_db",
                 batch_size: int = 32,
                 overwrite: bool = False):
        """
        Initialize template indexer
        
        Args:
            collection_name: ChromaDB collection name
            template_folder: Local folder containing templates
            embedding_model: Embedding model name
            chroma_persist_dir: ChromaDB persistence directory
            batch_size: Batch size for processing
            overwrite: Whether to overwrite existing collection
        """
        self.collection_name = collection_name
        self.template_folder = template_folder
        self.embedding_model = embedding_model
        self.chroma_persist_dir = chroma_persist_dir
        self.batch_size = batch_size
        self.overwrite = overwrite
        
        # Initialize components
        self.logger = get_risk_logger()
        self.vector_store = None
        self.embedder = None
        self.template_loader = None
        
    def initialize_components(self):
        """Initialize all components"""
        try:
            # Initialize vector store
            self.vector_store = ChromaVectorStore(
                collection_name=self.collection_name,
                persist_directory=self.chroma_persist_dir,
                embedding_model=self.embedding_model
            )
            
            # Clear collection if overwrite is enabled
            if self.overwrite:
                self.logger.log_event("clearing_collection", {
                    "collection_name": self.collection_name
                })
                self.vector_store.clear_collection()
            
            # Initialize embedder
            self.embedder = get_embedder(self.embedding_model)
            
            # Initialize template loader
            self.template_loader = get_template_loader(folder=self.template_folder)
            
            self.logger.log_event("components_initialized", {
                "collection_name": self.collection_name,
                "embedding_model": self.embedding_model,
                "template_folder": self.template_folder
            })
            
        except Exception as e:
            self.logger.log_error("initialization_failed", e)
            raise
    
    def load_templates(self) -> List[Dict[str, Any]]:
        """Load templates from local folder"""
        try:
            self.logger.log_event("loading_templates", {
                "folder": self.template_folder
            })
            
            templates = self.template_loader.load_proposal_templates()
            
            self.logger.log_event("templates_loaded", {
                "count": len(templates),
                "folder": self.template_folder
            })
            
            return templates
            
        except Exception as e:
            self.logger.log_error("template_loading_failed", e)
            return []
    
    def prepare_documents(self, templates: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Prepare templates for indexing"""
        documents = []
        
        for template in templates:
            try:
                # Validate template data
                if not template.get("text") or len(template["text"].strip()) < 10:
                    self.logger.log_event("skipping_empty_template", {
                        "template_id": template.get("id")
                    })
                    continue
                
                # Prepare document for ChromaDB
                doc = {
                    "content": template["text"],
                    "id": template["id"],
                    "metadata": {
                        "source": "local",
                        "folder": self.template_folder,
                        "template_id": template["id"],
                        "content_length": len(template["text"]),
                        "indexed_at": datetime.now().isoformat(),
                        **template.get("metadata", {})
                    }
                }
                
                documents.append(doc)
                
            except Exception as e:
                self.logger.log_error("document_preparation_failed", e, {
                    "template_id": template.get("id")
                })
                continue
        
        self.logger.log_event("documents_prepared", {
            "total_templates": len(templates),
            "valid_documents": len(documents)
        })
        
        return documents
    
    def index_documents_batch(self, documents: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Index documents in batches"""
        total_indexed = 0
        total_failed = 0
        indexing_results = []
        
        # Process in batches
        for i in range(0, len(documents), self.batch_size):
            batch = documents[i:i + self.batch_size]
            batch_num = (i // self.batch_size) + 1
            total_batches = (len(documents) + self.batch_size - 1) // self.batch_size
            
            try:
                self.logger.log_event("processing_batch", {
                    "batch_num": batch_num,
                    "total_batches": total_batches,
                    "batch_size": len(batch)
                })
                
                # Index batch
                result = self.vector_store.index_documents(batch)
                
                if result.get("success", False):
                    batch_indexed = result.get("indexed_count", 0)
                    total_indexed += batch_indexed
                    
                    indexing_results.append({
                        "batch_num": batch_num,
                        "indexed_count": batch_indexed,
                        "success": True
                    })
                    
                    self.logger.log_event("batch_completed", {
                        "batch_num": batch_num,
                        "indexed_count": batch_indexed
                    })
                else:
                    total_failed += len(batch)
                    indexing_results.append({
                        "batch_num": batch_num,
                        "error": result.get("error", "Unknown error"),
                        "success": False
                    })
                    
                    self.logger.log_event("batch_failed", {
                        "batch_num": batch_num,
                        "error": result.get("error")
                    })
                
                # Small delay to prevent overwhelming the system
                time.sleep(0.1)
                
            except Exception as e:
                total_failed += len(batch)
                self.logger.log_error("batch_processing_failed", e, {
                    "batch_num": batch_num
                })
                indexing_results.append({
                    "batch_num": batch_num,
                    "error": str(e),
                    "success": False
                })
        
        return {
            "total_indexed": total_indexed,
            "total_failed": total_failed,
            "total_processed": len(documents),
            "batch_results": indexing_results
        }
    
    def run_indexing(self) -> Dict[str, Any]:
        """Run the complete indexing process"""
        start_time = time.time()
        
        try:
            self.logger.log_event("indexing_started", {
                "collection_name": self.collection_name,
                "template_folder": self.template_folder,
                "overwrite": self.overwrite
            })
            
            # Initialize components
            self.initialize_components()
            
            # Load templates
            templates = self.load_templates()
            if not templates:
                return {
                    "success": False,
                    "error": "No templates found",
                    "total_indexed": 0
                }
            
            # Prepare documents for indexing
            documents = self.prepare_documents(templates)
            if not documents:
                return {
                    "success": False,
                    "error": "No valid documents to index",
                    "total_indexed": 0
                }
            
            # Index documents in batches
            indexing_result = self.index_documents_batch(documents)
            
            # Get final collection stats
            collection_stats = self.vector_store.get_collection_stats()
            
            total_time = time.time() - start_time
            
            final_result = {
                "success": True,
                "total_indexed": indexing_result["total_indexed"],
                "total_failed": indexing_result["total_failed"],
                "total_processed": indexing_result["total_processed"],
                "collection_stats": collection_stats,
                "execution_time": total_time,
                "batch_results": indexing_result["batch_results"],
                "templates_loaded": len(templates),
                "documents_prepared": len(documents)
            }
            
            self.logger.log_event("indexing_completed", final_result)
            
            return final_result
            
        except Exception as e:
            self.logger.log_error("indexing_failed", e)
            return {
                "success": False,
                "error": str(e),
                "total_indexed": 0,
                "execution_time": time.time() - start_time
            }
    
    def verify_indexing(self) -> Dict[str, Any]:
        """Verify that templates were indexed correctly"""
        try:
            # Get collection stats
            stats = self.vector_store.get_collection_stats()
            
            # Test query with a sample search
            test_query = "proposal template"
            query_result = self.vector_store.query_similar(test_query, top_k=3)
            
            verification_result = {
                "collection_stats": stats,
                "test_query": test_query,
                "test_results": query_result.get("results", []),
                "verification_success": query_result.get("success", False)
            }
            
            self.logger.log_event("indexing_verified", verification_result)
            
            return verification_result
            
        except Exception as e:
            self.logger.log_error("verification_failed", e)
            return {
                "verification_success": False,
                "error": str(e)
            }


def main():
    """Main function for command line usage"""
    parser = argparse.ArgumentParser(description="Index local templates into ChromaDB")
    
    # Template folder configuration
    parser.add_argument("--folder", default="templates", 
                       help="Local folder containing templates")
    
    # ChromaDB configuration
    parser.add_argument("--collection", default="proposal_templates",
                       help="ChromaDB collection name")
    parser.add_argument("--persist-dir", default="./risk_gate/vector_store/chroma_db",
                       help="ChromaDB persistence directory")
    
    # Processing configuration
    parser.add_argument("--batch-size", type=int, default=32,
                       help="Batch size for processing")
    parser.add_argument("--overwrite", action="store_true",
                       help="Overwrite existing collection")
    parser.add_argument("--embedding-model", 
                       default="sentence-transformers/all-MiniLM-L6-v2",
                       help="Embedding model name")
    
    # Actions
    parser.add_argument("--verify-only", action="store_true",
                       help="Only verify existing indexing")
    
    args = parser.parse_args()
    
    # Create indexer
    indexer = TemplateIndexer(
        collection_name=args.collection,
        template_folder=args.folder,
        embedding_model=args.embedding_model,
        chroma_persist_dir=args.persist_dir,
        batch_size=args.batch_size,
        overwrite=args.overwrite
    )
    
    if args.verify_only:
        # Only verify existing indexing
        print("Verifying existing indexing...")
        result = indexer.verify_indexing()
        print(f"Verification result: {result}")
    else:
        # Run full indexing process
        print("Starting template indexing...")
        result = indexer.run_indexing()
        
        if result["success"]:
            print(f"✅ Indexing completed successfully!")
            print(f"📊 Total indexed: {result['total_indexed']}")
            print(f"⏱️  Execution time: {result['execution_time']:.2f}s")
            print(f"📚 Collection size: {result['collection_stats'].get('total_documents', 0)}")
            
            # Verify indexing
            print("\nVerifying indexing...")
            verification = indexer.verify_indexing()
            if verification["verification_success"]:
                print("✅ Verification successful!")
            else:
                print("❌ Verification failed!")
        else:
            print(f"❌ Indexing failed: {result['error']}")


if __name__ == "__main__":
    main()
