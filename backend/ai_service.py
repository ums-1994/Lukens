"""
AI Service for Proposal & SOW Builder
Integrates with OpenRouter API for AI-powered features:
- Content generation and improvement
- Risk analysis and compliance checks
- Governance validation
"""

import os
import json
import requests
from typing import Dict, List, Optional, Any
from pydantic import BaseModel
from dotenv import load_dotenv

from api.utils.ai_safety import AISafetyError, enforce_safe_for_external_ai, sanitize_for_external_ai
from api.utils.gemini_client import GeminiClient, GeminiSchemaError

# Load environment variables
load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "anthropic/claude-3.5-sonnet")
DEFAULT_CURRENCY = os.getenv("DEFAULT_CURRENCY", "ZAR")  # Default to South African Rands
DEFAULT_CURRENCY_SYMBOL = os.getenv("DEFAULT_CURRENCY_SYMBOL", "R")  # Default to R

AI_PROVIDER = os.getenv("AI_PROVIDER", "openrouter").strip().lower()


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
        else:
            if not self.api_key:
                raise ValueError("OPENROUTER_API_KEY not found in environment variables")
        
        if self.provider == "gemini":
            print("✅ Using AI provider: gemini")
            print(f"✅ Using model: {os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')}")
            print(f"💰 Currency set to: {self.currency} ({self.currency_symbol})")
        else:
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
        Analyze proposal for compound risks (Wildcard Challenge)
        Detects missing sections, incomplete content, and compliance issues
        """
        safety_result = sanitize_for_external_ai(proposal_data)
        if safety_result.blocked:
            raise AISafetyError(
                "Blocked outbound AI risk analysis due to sensitive data detected.",
                reasons=safety_result.block_reasons,
            )

        prompt = f"""You are an expert proposal reviewer for Khonology. Analyze this proposal for risks and compliance issues.

Proposal Data:
{json.dumps(safety_result.sanitized, indent=2)}

Analyze for:
1. Missing or incomplete mandatory sections (Executive Summary, Scope & Deliverables, Delivery Approach, Assumptions, Risks, References, Team Bios)
2. Incomplete client details or engagement metadata
3. Vague or unclear deliverables
4. Missing risk assessments or assumptions
5. Incomplete team bios or references
6. Compliance issues with branding/standards
7. Any altered clauses that need review

Provide a JSON response with:
{
  "overall_risk_level": "low|medium|high|critical",
  "can_release": true/false,
  "risk_score": 0-100,
  "issues": [
    {
      "category": "missing_section|incomplete_content|compliance|clarity",
      "severity": "low|medium|high|critical",
      "section": "section name",
      "description": "detailed issue description",
      "recommendation": "how to fix"
    }
  ],
  "summary": "brief summary of all issues",
  "required_actions": ["action 1", "action 2"]
}

Be thorough and flag even small deviations that could compound into larger risks."""

        messages = [
            {"role": "system", "content": "You are an expert proposal risk analyzer. Always respond with valid JSON."},
            {"role": "user", "content": prompt}
        ]

        if self.provider == "gemini":
            if not self._gemini_client:
                raise Exception("Gemini client not initialized")
            try:
                analysis = self._gemini_client.generate_json(prompt, RiskAnalysis)
                return analysis.model_dump()
            except GeminiSchemaError as e:
                return {
                    "overall_risk_level": "medium",
                    "can_release": False,
                    "risk_score": 50,
                    "issues": [{
                        "category": "analysis_error",
                        "severity": "medium",
                        "section": "AI Analysis",
                        "description": str(e),
                        "recommendation": "Manual review required"
                    }],
                    "summary": "AI analysis completed but response format was unexpected",
                    "required_actions": ["Manual review recommended"]
                }

        response = self._make_request(messages, temperature=0.3)

        try:
            start_idx = response.find('{')
            end_idx = response.rfind('}') + 1
            json_str = response[start_idx:end_idx]
            return json.loads(json_str)
        except json.JSONDecodeError:
            return {
                "overall_risk_level": "medium",
                "can_release": False,
                "risk_score": 50,
                "issues": [{
                    "category": "analysis_error",
                    "severity": "medium",
                    "section": "AI Analysis",
                    "description": "Could not parse AI response",
                    "recommendation": "Manual review required"
                }],
                "summary": "AI analysis completed but response format was unexpected",
                "required_actions": ["Manual review recommended"]
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