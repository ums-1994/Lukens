"""
Local Template Loader for Risk Gate
Loads and extracts text from local proposal template files
"""

import os
import io
from typing import List, Dict, Any, Optional
from PyPDF2 import PdfReader
from PIL import Image
import pytesseract

from .logger import get_risk_logger


class LocalTemplateLoader:
    """Loader for local proposal template files"""
    
    def __init__(self, 
                 folder: str = "templates",
                 ocr_enabled: bool = True):
        """
        Initialize local template loader
        
        Args:
            folder: Local folder containing templates
            ocr_enabled: Whether to enable OCR for image templates
        """
        self.folder = folder
        self.ocr_enabled = ocr_enabled
        self.logger = get_risk_logger()
        
        # Supported file types
        self.supported_text_types = ['txt', 'md', 'docx']
        self.supported_pdf_types = ['pdf']
        self.supported_image_types = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff']
        
    def load_proposal_templates(self) -> List[Dict[str, Any]]:
        """
        Load all local template files and extract text
        
        Returns:
            List of {id, text, metadata} objects
        """
        try:
            self.logger.log_event("template_loading_started", {
                "folder": self.folder,
                "ocr_enabled": self.ocr_enabled
            })
            
            # Get all files from local folder
            files = self._get_local_files()
            
            if not files:
                self.logger.log_event("no_templates_found", {"folder": self.folder})
                return []
            
            templates = []
            
            for file_path in files:
                try:
                    template = self._process_template(file_path)
                    if template:
                        templates.append(template)
                        self.logger.log_event("template_processed", {
                            "template_id": template["id"],
                            "file_path": str(file_path)
                        })
                except Exception as e:
                    self.logger.log_error("template_processing_error", e, {
                        "file_path": str(file_path)
                    })
            
            self.logger.log_event("template_loading_completed", {
                "total_files": len(files),
                "successful_templates": len(templates),
                "folder": self.folder
            })
            
            return templates
            
        except Exception as e:
            self.logger.log_error("template_loading_failed", e)
            return []
    
    def _get_local_files(self) -> List[str]:
        """Get all files from local folder"""
        try:
            import glob
            
            if not os.path.exists(self.folder):
                self.logger.log_event("folder_not_found", {"folder": self.folder})
                return []
            
            # Get all files in the folder
            all_files = []
            for ext in self.supported_text_types + self.supported_pdf_types + self.supported_image_types:
                pattern = os.path.join(self.folder, f"**/*.{ext}")
                files = glob.glob(pattern, recursive=True)
                all_files.extend(files)
            
            self.logger.log_event("local_files_found", {
                "total_files": len(all_files),
                "folder": self.folder
            })
            
            return all_files
            
        except Exception as e:
            self.logger.log_error("local_files_fetch_failed", e)
            return []
    
    def _process_template(self, file_path: str) -> Optional[Dict[str, Any]]:
        """Process a single template file"""
        file_name = os.path.basename(file_path)
        file_ext = os.path.splitext(file_name)[1].lower().lstrip('.')
        
        # Determine file type
        if file_ext in self.supported_pdf_types:
            file_type = "pdf"
        elif file_ext in self.supported_text_types:
            file_type = "text"
        elif file_ext in self.supported_image_types:
            file_type = "image"
        else:
            file_type = "unknown"
        
        # Extract text from file
        extracted_text = self._extract_text_from_file(file_path, file_type, file_ext)
        
        if not extracted_text or len(extracted_text.strip()) < 10:
            self.logger.log_event("text_extraction_failed", {
                "file_path": file_path,
                "file_type": file_type,
                "format": file_ext
            })
            return None
        
        # Create template object
        template = {
            "id": file_name,
            "text": extracted_text,
            "metadata": {
                "file_name": file_name,
                "file_path": file_path,
                "file_type": file_type,
                "format": file_ext,
                "size": os.path.getsize(file_path) if os.path.exists(file_path) else 0,
                "folder": self.folder,
                "text_length": len(extracted_text)
            }
        }
        
        return template
    
    def _extract_text_from_file(self, file_path: str, file_type: str, file_ext: str) -> Optional[str]:
        """Extract text from local file"""
        try:
            if file_type == "pdf":
                return self._extract_pdf_text(file_path)
            elif file_type == "text":
                return self._extract_text_file_content(file_path)
            elif file_type == "image":
                return self._extract_image_text(file_path)
            else:
                self.logger.log_event("unsupported_file_type", {
                    "file_path": file_path,
                    "file_type": file_type
                })
                return None
        except Exception as e:
            self.logger.log_error("text_extraction_failed", e, {
                "file_path": file_path
            })
            return None
    
    def _extract_pdf_text(self, file_path: str) -> Optional[str]:
        """Extract text from PDF file"""
        try:
            with open(file_path, 'rb') as file:
                pdf_reader = PdfReader(file)
                
                text_content = []
                
                for page_num, page in enumerate(pdf_reader.pages):
                    try:
                        page_text = page.extract_text()
                        if page_text:
                            text_content.append(f"--- Page {page_num + 1} ---\n{page_text}")
                    except Exception as e:
                        self.logger.log_event("pdf_page_extraction_failed", {
                            "page_num": page_num,
                            "error": str(e)
                        })
                        continue
                
                return "\n\n".join(text_content) if text_content else None
                
        except Exception as e:
            self.logger.log_error("pdf_extraction_failed", e)
            return None
    
    def _extract_text_file_content(self, file_path: str) -> Optional[str]:
        """Extract text from text file"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
                return file.read()
        except Exception as e:
            self.logger.log_error("text_file_extraction_failed", e)
            return None
    
    def _extract_image_text(self, file_path: str) -> Optional[str]:
        """Extract text from image using OCR"""
        try:
            if not self.ocr_enabled:
                return None
                
            # Open image
            image = Image.open(file_path)
            
            # Convert to RGB if necessary
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Extract text using Tesseract OCR
            text = pytesseract.image_to_string(image)
            
            return text.strip() if text else None
            
        except Exception as e:
            self.logger.log_error("ocr_extraction_failed", e)
            return None
    
    def get_template_by_id(self, template_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific template by ID (filename)"""
        try:
            # Look for file with matching name
            for ext in self.supported_text_types + self.supported_pdf_types + self.supported_image_types:
                file_path = os.path.join(self.folder, f"{template_id}.{ext}")
                if os.path.exists(file_path):
                    template = self._process_template(file_path)
                    return template
            
            return None
            
        except Exception as e:
            self.logger.log_error("template_fetch_failed", e, {"template_id": template_id})
            return None
    
    def refresh_templates(self) -> List[Dict[str, Any]]:
        """Refresh all templates from local folder"""
        return self.load_proposal_templates()
    
    def get_loading_stats(self) -> Dict[str, Any]:
        """Get statistics about template loading"""
        try:
            files = self._get_local_files()
            
            stats = {
                "total_files": len(files),
                "folder": self.folder,
                "supported_types": {
                    "text": self.supported_text_types,
                    "pdf": self.supported_pdf_types,
                    "image": self.supported_image_types
                },
                "ocr_enabled": self.ocr_enabled
            }
            
            # Count by type
            type_counts = {}
            for file_path in files:
                file_ext = os.path.splitext(file_path)[1].lower().lstrip('.')
                if file_ext in self.supported_pdf_types:
                    type_counts["pdf"] = type_counts.get("pdf", 0) + 1
                elif file_ext in self.supported_text_types:
                    type_counts["text"] = type_counts.get("text", 0) + 1
                elif file_ext in self.supported_image_types:
                    type_counts["image"] = type_counts.get("image", 0) + 1
            
            stats["type_counts"] = type_counts
            return stats
            
        except Exception as e:
            self.logger.log_error("stats_fetch_failed", e)
            return {}


# Global loader instance
_template_loader_instance = None

def get_template_loader(folder: str = "templates") -> LocalTemplateLoader:
    """Get or create global template loader instance"""
    global _template_loader_instance
    if _template_loader_instance is None:
        _template_loader_instance = LocalTemplateLoader(folder=folder)
    return _template_loader_instance

def load_proposal_templates(folder: str = "templates") -> List[Dict[str, Any]]:
    """
    Load all proposal templates from local folder
    
    Args:
        folder: Local folder containing templates
        
    Returns:
        List of {id, text, metadata} objects
    """
    loader = get_template_loader(folder)
    return loader.load_proposal_templates()
