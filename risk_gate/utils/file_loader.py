"""
File Loader Module
Loads and processes incoming proposal text
"""

import os
from typing import Dict, Any, Optional
import logging


class FileLoader:
    """Handles loading and preprocessing of proposal text"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def load_proposal_text(self, file_path: str) -> Dict[str, Any]:
        """
        Load proposal text from file
        
        Args:
            file_path: Path to proposal file
            
        Returns:
            Dict with loaded text and metadata
        """
        try:
            if not os.path.exists(file_path):
                return {
                    'success': False,
                    'error': f'File not found: {file_path}',
                    'text': '',
                    'metadata': {}
                }
            
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extract basic metadata
            file_size = os.path.getsize(file_path)
            word_count = len(content.split())
            
            metadata = {
                'file_path': file_path,
                'file_size': file_size,
                'word_count': word_count,
                'line_count': len(content.splitlines())
            }
            
            self.logger.info(f"Loaded proposal: {file_path} ({word_count} words)")
            
            return {
                'success': True,
                'text': content,
                'metadata': metadata
            }
            
        except Exception as e:
            self.logger.error(f"Error loading file {file_path}: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'text': '',
                'metadata': {}
            }
    
    def load_proposal_text_direct(self, text: str) -> Dict[str, Any]:
        """
        Load proposal text directly from string
        
        Args:
            text: Raw proposal text
            
        Returns:
            Dict with loaded text and metadata
        """
        try:
            word_count = len(text.split())
            metadata = {
                'source': 'direct_input',
                'word_count': word_count,
                'line_count': len(text.splitlines())
            }
            
            self.logger.info(f"Loaded proposal text directly ({word_count} words)")
            
            return {
                'success': True,
                'text': text,
                'metadata': metadata
            }
            
        except Exception as e:
            self.logger.error(f"Error loading direct text: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'text': '',
                'metadata': {}
            }
    
    def preprocess_text(self, text: str) -> str:
        """
        Basic text preprocessing
        
        Args:
            text: Raw text
            
        Returns:
            Preprocessed text
        """
        # Normalize whitespace
        text = ' '.join(text.split())
        
        # Remove excessive line breaks
        text = text.replace('\n\n\n', '\n\n')
        
        return text.strip()
