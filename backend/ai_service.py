"""
AI Service for Proposal & SOW Builder
Integrates with OpenRouter API for AI-powered features:
- Content generation and improvement
- Risk analysis and compliance checks
- Governance validation
"""

import os
import json
import re
import requests
from typing import Dict, List, Optional, Any
from pydantic import BaseModel
from dotenv import load_dotenv

from api.utils.ai_safety import (
    AISafetyError,
    enforce_safe_for_external_ai,
    sanitize_for_external_ai,
)
from api.utils.gemini_client import GeminiClient, GeminiSchemaError

# Pydantic models for AI responses
class RiskIssue(BaseModel):
    category: str
    severity: str
    section: str
    description: str
    recommendation: str

class RiskAnalysis(BaseModel):
    overall_risk_level: str
    can_release: bool
    risk_score: int
    issues: List[RiskIssue]
    summary: str
    required_actions: List[str]

# Load environment variables
load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "anthropic/claude-3.5-sonnet")
DEFAULT_CURRENCY = os.getenv("DEFAULT_CURRENCY", "ZAR")  # Default to South African Rands
DEFAULT_CURRENCY_SYMBOL = os.getenv("DEFAULT_CURRENCY_SYMBOL", "R")  # Default to R

AI_PROVIDER = os.getenv("AI_PROVIDER", "openrouter").strip().lower()

# HuggingFace Risk Gate config — env key is Risk_Gate_engine_API (legacy) or
# RISK_GATE_API_URL (canonical).  Accept both so either .env works.
HF_RISK_GATE_URL = (
    os.getenv("RISK_GATE_API_URL")
    or os.getenv("Risk_Gate_engine_API")
    or os.getenv("HUGGINGFACE_RISK_URL")
    or ""
).rstrip("/")

HF_TOKEN = os.getenv("HF_TOKEN", "")


class AIService:
    """Service for AI-powered proposal analysis and generation"""
    
    def __init__(self):
        self.provider = AI_PROVIDER
        self.api_key = OPENROUTER_API_KEY
        self.base_url = OPENROUTER_BASE_URL
        self.model = OPENROUTER_MODEL
        self.currency = DEFAULT_CURRENCY  # Default: South African Rands
        self.currency_symbol = DEFAULT_CURRENCY_SYMBOL  # Default: R

        self._gemini_client: GeminiClient | None = None

        if self.provider == "gemini":
            self._gemini_client = GeminiClient()
        elif self.provider == "huggingface":
            # HuggingFace provider — no OpenRouter key required
            if not HF_RISK_GATE_URL:
                print("⚠️  AI_PROVIDER=huggingface but no HuggingFace URL configured "
                      "(set Risk_Gate_engine_API in .env)")
            else:
                print(f"[OK] Using AI provider: huggingface -> {HF_RISK_GATE_URL}")
        else:
            if not self.api_key:
                raise ValueError("OPENROUTER_API_KEY not found in environment variables")
        
        if self.provider == "gemini":
            print("✅ Using AI provider: gemini")
            print(f"✅ Using model: {os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')}")
            print(f"💰 Currency set to: {self.currency} ({self.currency_symbol})")
        elif self.provider != "huggingface":
            if self.api_key:
                print(f"✅ OpenRouter API Key loaded: {self.api_key[:10]}...{self.api_key[-4:]}")
                print(f"✅ Using model: {self.model}")
                print(f"💰 Currency set to: {self.currency} ({self.currency_symbol})")
            else:
                print("❌ OpenRouter API Key is empty!")

    def _make_request(self, messages: List[Dict[str, str]], temperature: float = 0.7, max_tokens: int = 2000) -> str:
        """Make a request to OpenRouter API (sanitized-only payload)"""
        if self.provider == "gemini":
            if not self._gemini_client:
                raise Exception("Gemini client not initialized")

            # Convert chat-style messages into a single prompt for Gemini.
            safe_messages = enforce_safe_for_external_ai(messages)
            prompt = "\n\n".join(
                f"{m.get('role', 'user').upper()}: {m.get('content', '')}" for m in safe_messages
            )
            return self._gemini_client.generate_text(
                prompt,
                temperature=temperature,
                max_output_tokens=max_tokens,
            )

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "http://localhost:8000",  # Required by OpenRouter
            "X-Title": "Proposal & SOW Builder"
        }

        # Enforce that we never send sensitive data to third-party AI providers.
        # We sanitize all outbound message content and block if secrets are detected.
        sanitized_messages = enforce_safe_for_external_ai(messages)

        payload = {
            "model": self.model,
            "messages": sanitized_messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }

        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=payload,
                timeout=60
            )
            response.raise_for_status()

            result = response.json()
            return result["choices"][0]["message"]["content"]

        except AISafetyError:
            raise
        except requests.exceptions.RequestException as e:
            raise Exception(f"OpenRouter API request failed: {str(e)}")

    def analyze_proposal_risks(self, proposal_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Analyze proposal for compound risks.
        Routes to HuggingFace Risk Gate when AI_PROVIDER=huggingface,
        otherwise uses the legacy external Risk Gate API.
        """
        safety_result = sanitize_for_external_ai(proposal_data)
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI risk analysis due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        if self.provider == "huggingface":
            return self._analyze_via_huggingface(proposal_data)

        # Legacy path: external Risk Gate API
        risk_gate_api_url = (
            os.getenv("RISK_GATE_API_URL")
            or os.getenv("Risk_Gate_engine_API")
            or ""
        ).rstrip("/")
        if not risk_gate_api_url:
            raise ValueError(
                "No Risk Gate API URL configured. "
                "Set Risk_Gate_engine_API (or RISK_GATE_API_URL) in .env."
            )

        headers = {"Content-Type": "application/json"}
        payload = {
            "proposal_title": proposal_data.get("title", "Untitled Proposal"),
            "client_info": proposal_data.get("client", {}),
            "sections": proposal_data.get("sections", [])
        }

        try:
            response = requests.post(
                f"{risk_gate_api_url}/ai/analyze-proposal",
                headers=headers,
                json=payload,
                timeout=120
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error calling external Risk Gate API: {e}")
            return self._fallback_response(str(e))

    def _analyze_via_huggingface(self, proposal_data: Dict[str, Any]) -> Dict[str, Any]:
        """Send proposal to the HuggingFace Risk Gate space and normalise the response."""
        if not HF_RISK_GATE_URL:
            raise ValueError(
                "HuggingFace Risk Gate URL not configured. "
                "Set Risk_Gate_engine_API in .env."
            )

        # Prefer proposal.content.sections (editor-stored); fallback to top-level sections
        sections_dict = {}
        content_raw = proposal_data.get("content")
        if content_raw:
            try:
                content_obj = content_raw if isinstance(content_raw, dict) else json.loads(content_raw)
                if isinstance(content_obj, dict):
                    nested = content_obj.get("sections", [])
                    if isinstance(nested, list):
                        for s in nested:
                            if isinstance(s, dict) and s.get("title"):
                                sections_dict[s["title"]] = s.get("content", "")
                    elif isinstance(nested, dict):
                        sections_dict.update(nested)
            except (TypeError, json.JSONDecodeError):
                pass

        # Overlay top-level sections if no content.sections or for backward compatibility
        raw_sections = proposal_data.get("sections", {})
        if isinstance(raw_sections, list):
            for i, s in enumerate(raw_sections):
                if isinstance(s, dict) and s.get("title"):
                    sections_dict[s.get("title", f"section_{i}")] = s.get("content", "")
        elif isinstance(raw_sections, dict):
            sections_dict.update(raw_sections)

        # Also include top-level section fields that callers sometimes pass directly
        for key in ("executive_summary", "scope", "scope_deliverables", "scope_of_work",
                    "deliverables", "payment_terms", "termination_clause",
                    "company_profile", "team", "pricing", "timeline", "risks", "assumptions"):
            val = proposal_data.get(key, "")
            if val and key not in sections_dict:
                sections_dict[key] = str(val)

        # Normalise section titles to canonical HF keys.
        # IMPORTANT SAFEGUARD:
        # - Do NOT attempt to split "Scope & Deliverables" content. If that is
        #   the only source text, we send the SAME text for both scope_of_work
        #   and deliverables to preserve backwards compatibility.
        canonical: Dict[str, str] = {}
        other_sections: Dict[str, str] = {}

        def _norm_title(title: str) -> str:
            t = str(title or "").lower().strip()
            # Treat underscores and whitespace the same
            t = re.sub(r"[_\s]+", " ", t)
            t = t.replace("&", "and")
            t = re.sub(r"\s+", " ", t)
            return t

        combined_scope_deliverables_text: str | None = None

        for raw_title, text in sections_dict.items():
            if not text:
                continue
            title = str(raw_title or "").strip()
            norm = _norm_title(title)

            if "executive summary" in norm or norm == "executive_summary":
                canonical["executive_summary"] = text
            elif "scope of work" in norm or norm == "scope_of_work":
                canonical["scope_of_work"] = text
            elif ("scope" in norm and "deliverable" in norm):
                combined_scope_deliverables_text = text
            elif "deliverable" in norm and "scope" not in norm:
                canonical["deliverables"] = text
            elif "payment terms" in norm or ("payment" in norm and "terms" in norm):
                canonical["payment_terms"] = text
            elif "termination clause" in norm or "termination" in norm:
                canonical["termination_clause"] = text
            else:
                # Preserve all other sections under a slug-style key so HF
                # can still see full context if it wants to.
                other_sections.setdefault(title, text)

        # If we have a combined "Scope & Deliverables" section and no separate
        # dedicated Scope of Work / Deliverables, map the SAME text to both
        # canonical keys (no parsing / splitting).
        if combined_scope_deliverables_text:
            if "scope_of_work" not in canonical:
                canonical["scope_of_work"] = combined_scope_deliverables_text
            if "deliverables" not in canonical:
                canonical["deliverables"] = combined_scope_deliverables_text

        # Final sections map for HF: preserve other sections and inject
        # canonical keys used by the Risk Gate engine.
        hf_sections: Dict[str, str] = dict(other_sections)
        hf_sections.update(canonical)

        payload = {
            "proposal_title": (
                proposal_data.get("title")
                or proposal_data.get("proposalTitle")
                or "Untitled Proposal"
            ),
            "client_name": (
                proposal_data.get("client_name")
                or proposal_data.get("clientName")
                or proposal_data.get("client", {}).get("name", "")
                if isinstance(proposal_data.get("client"), dict)
                else proposal_data.get("client", "")
            ),
            "opportunity_name": (
                proposal_data.get("opportunity_name")
                or proposal_data.get("opportunityName")
                or proposal_data.get("title")
                or "Proposal"
            ),
            "template_type": (
                proposal_data.get("template_type")
                or proposal_data.get("templateType")
                or proposal_data.get("templateId")
                or "proposal"
            ),
            # The Risk Gate engine consumes a sections dict. We send the
            # canonical keys (executive_summary, scope_of_work, deliverables,
            # payment_terms, termination_clause) plus any other sections.
            "sections": hf_sections,
            # Convenience top-level aliases for explicit keys the engine
            # may read directly.
            "executive_summary": canonical.get("executive_summary", ""),
            "scope_of_work": canonical.get("scope_of_work", ""),
            "deliverables": canonical.get("deliverables", ""),
            "payment_terms": canonical.get("payment_terms", ""),
            "termination_clause": canonical.get("termination_clause", ""),
        }

        headers = {"Content-Type": "application/json"}
        if HF_TOKEN:
            headers["Authorization"] = f"Bearer {HF_TOKEN}"

        print(f"[HF] Calling HuggingFace Risk Gate: {HF_RISK_GATE_URL}/analyze-proposal")
        try:
            response = requests.post(
                f"{HF_RISK_GATE_URL}/analyze-proposal",
                headers=headers,
                json=payload,
                timeout=120,
            )
            response.raise_for_status()
            result = response.json()

            # Post-process recommendations to avoid obvious false positives
            # when sections/clauses are clearly present on our side.
            try:
                recos = result.get("recommendations") or []
                if isinstance(recos, list):
                    has_exec = bool(canonical.get("executive_summary", "").strip())
                    has_scope = bool(canonical.get("scope_of_work", "").strip())
                    has_deliv = bool(canonical.get("deliverables", "").strip())
                    has_pay = bool(canonical.get("payment_terms", "").strip())
                    has_term = bool(canonical.get("termination_clause", "").strip())

                    def _keep(rec: Any) -> bool:
                        if not isinstance(rec, str):
                            return True
                        lower = rec.lower()
                        if has_exec and "add executive summary section" in lower:
                            return False
                        if has_scope and "add scope of work section" in lower:
                            return False
                        if has_deliv and "add deliverables section" in lower:
                            return False
                        if has_pay and "add payment terms clause" in lower:
                            return False
                        if has_term and "add termination clause" in lower:
                            return False
                        return True

                    filtered = [r for r in recos if _keep(r)]
                    result["recommendations"] = filtered
            except Exception:
                # Never let post-processing break the main analysis path.
                pass

            print(
                f"[OK] HuggingFace Risk Gate response: "
                f"risk_level={result.get('risk_level')}, "
                f"risk_score={result.get('risk_score')}"
            )
            return result
        except requests.exceptions.RequestException as e:
            print(f"[ERR] HuggingFace Risk Gate error: {e}")
            return self._fallback_response(str(e))

    @staticmethod
    def _fallback_response(error_detail: str) -> Dict[str, Any]:
        """Safe fallback when the external risk engine is unreachable."""
        # IMPORTANT SAFEGUARD:
        # - Do NOT generate synthetic high-risk scores or issues.
        # - Do NOT overwrite previously successful results in the database;
        #   callers must treat this as a transient failure signal.
        return {
            "risk_level": "unknown",
            "risk_score": None,
            "issues": [],
            "recommendations": [],
            "inference_status": "failed",
            "error": str(error_detail),
        }
    
    def generate_proposal_section(self, section_type: str, context: Dict[str, Any]) -> str:
        """
        Generate content for a specific proposal section
        """
        section_prompts = {
            "executive_summary": "Write a compelling executive summary that highlights the client's needs, our proposed solution, and key benefits.",
            "scope_deliverables": "Define clear scope and deliverables based on the project details. Be specific and measurable.",
            "delivery_approach": "Describe our delivery methodology, timeline, and approach to ensure project success.",
            "assumptions": "List key assumptions that underpin this proposal, including client responsibilities and prerequisites.",
            "risks": "Identify potential risks and our mitigation strategies.",
            "company_profile": "Write a professional company profile highlighting our expertise and capabilities.",
            "introduction": "Write an engaging introduction that sets the context and purpose of the proposal.",
            "solution_overview": "Describe the proposed solution and how it addresses the client's needs.",
            "timeline": "Create a detailed timeline with phases and milestones.",
            "budget": f"Present the budget breakdown in a clear and professional manner. Use South African Rands (ZAR) with the {self.currency_symbol} symbol for all pricing.",
            "pricing_budget": f"Create a detailed pricing breakdown. Use South African Rands (ZAR) with the {self.currency_symbol} symbol for all amounts. Include line items, subtotals, and total.",
            "team": "Describe the team members and their relevant expertise.",
            "conclusion": "Write a strong closing that reinforces value and encourages action."
        }
        
        section_prompt = section_prompts.get(section_type, "Generate professional content for this section.")
        
        safe_context = enforce_safe_for_external_ai(context)

        prompt = f"""You are writing a proposal section for Khonology, a South African company.

Section Type: {section_type}
Task: {section_prompt}

Context:
{json.dumps(safe_context, indent=2)}

IMPORTANT: All monetary amounts must be in South African Rands (ZAR) using the {self.currency_symbol} symbol (e.g., {self.currency_symbol}50,000).
Do NOT use dollars ($), euros (€), or any other currency.

Write professional, clear, and compelling content. Use proper formatting with paragraphs and bullet points where appropriate.
Keep it concise but comprehensive (200-400 words)."""

        messages = [
            {"role": "system", "content": "You are an expert proposal writer for a professional services firm."},
            {"role": "user", "content": prompt}
        ]
        
        return self._make_request(messages, temperature=0.7, max_tokens=1000)
    
    def generate_full_proposal(self, context: Dict[str, Any]) -> Dict[str, str]:
        """
        Generate a complete multi-section proposal
        """
        safe_context = enforce_safe_for_external_ai(context)

        prompt = f"""You are writing a complete business proposal for Khonology, a South African company.

Context:
{json.dumps(safe_context, indent=2)}

Generate a comprehensive proposal with the following sections:

1. Executive Summary
2. Introduction & Background
3. Understanding of Requirements
4. Proposed Solution
5. Scope & Deliverables
6. Delivery Approach & Methodology
7. Timeline & Milestones
8. Team & Expertise
9. Budget & Pricing
10. Assumptions & Dependencies
11. Risks & Mitigation
12. Terms & Conditions

IMPORTANT: All monetary amounts MUST be in South African Rands (ZAR) using the {self.currency_symbol} symbol (e.g., {self.currency_symbol}150,000, {self.currency_symbol}2.5 million).
Do NOT use dollars ($), euros (€), or any other currency.

For each section, write professional, detailed content (150-300 words per section).
Use proper formatting with headings, paragraphs, and bullet points.

Return a JSON object with section titles as keys and content as values:
{
  "Executive Summary": "content here...",
  "Introduction & Background": "content here...",
  ...
}"""

        messages = [
            {"role": "system", "content": "You are an expert proposal writer. Always respond with valid JSON containing all sections."},
            {"role": "user", "content": prompt}
        ]
        
        response = self._make_request(messages, temperature=0.7, max_tokens=4000)
        
        try:
            # Extract JSON from response
            start_idx = response.find('{')
            end_idx = response.rfind('}') + 1
            json_str = response[start_idx:end_idx]
            return json.loads(json_str)
        except json.JSONDecodeError:
            # Fallback if JSON parsing fails
            return {
                "Executive Summary": response[:500] if len(response) > 500 else response,
                "Content": response[500:] if len(response) > 500 else "Please try again."
            }
    
    def improve_content(self, content: str, section_type: str) -> Dict[str, Any]:
        """
        Analyze and suggest improvements for existing content
        """
        safe_content = enforce_safe_for_external_ai(content)

        prompt = f"""You are an expert proposal editor for Khonology, a South African company. Review this content and suggest improvements.

Section Type: {section_type}
Current Content:
{safe_content}

IMPORTANT: If the content contains pricing/monetary amounts, ensure they are in South African Rands (ZAR) using the {self.currency_symbol} symbol.
Convert any dollars ($), euros (€), or other currencies to Rands (e.g., ${self.currency_symbol}150,000).

Analyze for:
1. Clarity and readability
2. Professional tone
3. Completeness
4. Grammar and style
5. Persuasiveness
6. Currency usage (must be ZAR/{self.currency_symbol})

Provide a JSON response with:
{{
  "quality_score": 0-100,
  "strengths": ["strength 1", "strength 2"],
  "improvements": [
    {{
      "issue": "what needs improvement",
      "suggestion": "how to improve it",
      "priority": "low|medium|high"
    }}
  ],
  "improved_version": "rewritten content with improvements applied",
  "summary": "brief summary of changes"
}}"""

        messages = [
            {"role": "system", "content": "You are an expert proposal editor. Always respond with valid JSON."},
            {"role": "user", "content": prompt}
        ]
        
        response = self._make_request(messages, temperature=0.5, max_tokens=2000)
        
        try:
            start_idx = response.find('{')
            end_idx = response.rfind('}') + 1
            json_str = response[start_idx:end_idx]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return {
                "quality_score": 70,
                "strengths": ["Content is present"],
                "improvements": [],
                "improved_version": content,
                "summary": "Could not analyze content"
            }
    
    def check_compliance(self, proposal_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Check proposal compliance with Khonology standards
        """
        safety_result = sanitize_for_external_ai(proposal_data)
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI compliance check due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        prompt = f"""You are a compliance checker for Khonology proposals. Review this proposal for compliance.

Proposal Data:
{json.dumps(safety_result.sanitized, indent=2)}

Check for:
1. All mandatory sections present and complete
2. Professional tone and branding consistency
3. Proper formatting and structure
4. Client details properly filled
5. Legal and compliance requirements
6. Completeness of team bios and references

Provide a JSON response with:
{
  "compliant": true/false,
  "compliance_score": 0-100,
  "passed_checks": ["check 1", "check 2"],
  "failed_checks": [
    {
      "check": "check name",
      "severity": "low|medium|high",
      "description": "what failed",
      "fix": "how to fix"
    }
  ],
  "ready_for_approval": true/false,
  "summary": "overall compliance status"
}"""

        messages = [
            {"role": "system", "content": "You are a compliance checker. Always respond with valid JSON."},
            {"role": "user", "content": prompt}
        ]
        
        response = self._make_request(messages, temperature=0.3, max_tokens=1500)
        
        try:
            start_idx = response.find('{')
            end_idx = response.rfind('}') + 1
            json_str = response[start_idx:end_idx]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return {
                "compliant": False,
                "compliance_score": 50,
                "passed_checks": [],
                "failed_checks": [],
                "ready_for_approval": False,
                "summary": "Could not complete compliance check"
            }
    
    def generate_risk_summary(self, proposal_data: Dict[str, Any]) -> str:
        """
        Generate a comprehensive risk summary for dashboard display
        """
        safety_result = sanitize_for_external_ai(proposal_data)
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI risk summary due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        prompt = f"""Generate a brief executive summary of risks for this proposal.

Proposal Data:
{json.dumps(safety_result.sanitized, indent=2)}

Write a 2-3 sentence summary highlighting the most critical risks or issues that need attention before release.
If the proposal looks good, provide positive feedback."""

        messages = [
            {"role": "system", "content": "You are a proposal risk analyst."},
            {"role": "user", "content": prompt}
        ]
        
        return self._make_request(messages, temperature=0.5, max_tokens=300)
    
    def suggest_next_steps(self, proposal_data: Dict[str, Any], current_stage: str) -> List[str]:
        """
        Suggest next steps based on proposal state and current stage
        """
        safety_result = sanitize_for_external_ai(proposal_data)
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI next-steps generation due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        prompt = f"""Based on this proposal's current state and stage, suggest 3-5 actionable next steps.

Current Stage: {current_stage}
Proposal Data:
{json.dumps(safety_result.sanitized, indent=2)}

Provide a JSON array of specific, actionable next steps:
["step 1", "step 2", "step 3"]"""

        messages = [
            {"role": "system", "content": "You are a proposal workflow advisor. Always respond with a JSON array."},
            {"role": "user", "content": prompt}
        ]
        
        response = self._make_request(messages, temperature=0.6, max_tokens=500)
        
        try:
            start_idx = response.find('[')
            end_idx = response.rfind(']') + 1
            json_str = response[start_idx:end_idx]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return ["Complete all mandatory sections", "Review for accuracy", "Submit for approval"]


# Singleton instance
ai_service = AIService()