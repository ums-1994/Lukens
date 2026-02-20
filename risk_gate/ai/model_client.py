"""
HF Model Client for Risk Gate AI
Lightweight Hugging Face text generation with retry logic and caching
"""

import os
import json
import logging
from typing import Optional, Dict, Any
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline
import torch
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import requests.exceptions

logger = logging.getLogger(__name__)


class HFModelClient:
    """Hugging Face model client with caching and retry logic"""
    
    def __init__(self, model_name: str = "TinyLlama/TinyLlama-1.1B-Chat-v1.0", hf_token: Optional[str] = None):
        self.model_name = model_name
        self.hf_token = hf_token or os.getenv('HF_TOKEN')
        self._tokenizer = None
        self._model = None
        self._generator = None
        self._device = "cuda" if torch.cuda.is_available() else "cpu"
        self.max_length = 512
        self.max_new_tokens = 256
        
    @property
    def tokenizer(self):
        """Lazy-load tokenizer"""
        if self._tokenizer is None:
            try:
                logger.info(f"Loading tokenizer for {self.model_name}")
                self._tokenizer = AutoTokenizer.from_pretrained(
                    self.model_name,
                    use_auth_token=self.hf_token,
                    trust_remote_code=True
                )
                if self._tokenizer.pad_token is None:
                    self._tokenizer.pad_token = self._tokenizer.eos_token
                logger.info("Tokenizer loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load tokenizer: {str(e)}")
                raise
        return self._tokenizer
    
    @property
    def model(self):
        """Lazy-load model"""
        if self._model is None:
            try:
                logger.info(f"Loading model {self.model_name} on {self._device}")
                self._model = AutoModelForCausalLM.from_pretrained(
                    self.model_name,
                    use_auth_token=self.hf_token,
                    torch_dtype=torch.float16 if self._device == "cuda" else torch.float32,
                    device_map="auto" if self._device == "cuda" else None,
                    trust_remote_code=True
                )
                if self._device == "cpu":
                    self._model = self._model.to(self._device)
                self._model.eval()
                logger.info("Model loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load model: {str(e)}")
                raise
        return self._model
    
    @property
    def generator(self):
        """Lazy-load pipeline generator"""
        if self._generator is None:
            try:
                logger.info(f"Creating text generation pipeline for {self.model_name}")
                self._generator = pipeline(
                    "text-generation",
                    model=self.model,
                    tokenizer=self.tokenizer,
                    device=0 if self._device == "cuda" else -1,
                    torch_dtype=torch.float16 if self._device == "cuda" else torch.float32
                )
                logger.info("Pipeline created successfully")
            except Exception as e:
                logger.error(f"Failed to create pipeline: {str(e)}")
                raise
        return self._generator
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        retry=retry_if_exception_type((requests.exceptions.RequestException, OSError))
    )
    def generate_text(self, prompt: str, max_new_tokens: Optional[int] = None) -> str:
        """
        Generate text using the HF model
        
        Args:
            prompt: Input prompt for generation
            max_new_tokens: Optional override for max new tokens
            
        Returns:
            Generated text response
        """
        try:
            # Use provided max_new_tokens or default
            tokens = max_new_tokens or self.max_new_tokens
            
            # Use pipeline for generation
            outputs = self.generator(
                prompt,
                max_new_tokens=tokens,
                temperature=0.7,
                do_sample=True,
                pad_token_id=self.tokenizer.eos_token_id,
                eos_token_id=self.tokenizer.eos_token_id,
                num_return_sequences=1,
                return_full_text=False
            )
            
            # Extract generated text
            generated_text = outputs[0]['generated_text'].strip()
            
            return generated_text
            
        except Exception as e:
            logger.error(f"Error generating text: {str(e)}")
            raise
    
    def is_loaded(self) -> bool:
        """Check if model and tokenizer are loaded"""
        return self._tokenizer is not None and self._model is not None and self._generator is not None
    
    def unload(self):
        """Unload model and tokenizer to free memory"""
        if self._generator is not None:
            del self._generator
            self._generator = None
        
        if self._model is not None:
            del self._model
            self._model = None
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        
        if self._tokenizer is not None:
            del self._tokenizer
            self._tokenizer = None
        
        logger.info("Model, tokenizer, and pipeline unloaded")


# Global instance for reuse
_model_client = None


def get_model_client() -> HFModelClient:
    """Get or create global model client instance"""
    global _model_client
    if _model_client is None:
        _model_client = HFModelClient()
    return _model_client
