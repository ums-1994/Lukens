def run_prechecks(proposal):
    """
    Run deterministic checks on the proposal.
    """
    issues = []
    risk_score = 0
    
    # Example check: Title
    if not proposal.get('title'):
        issues.append({
            "category": "missing_content",
            "severity": "high",
            "section": "Header",
            "description": "Proposal missing title",
            "recommendation": "Add a title"
        })
        risk_score += 10

    return {
        "risk_score": risk_score,
        "issues": issues,
        "block_release": risk_score > 50
    }

def combine_assessments(precheck, ai_result):
    """
    Combine precheck and AI results.
    """
    combined_issues = precheck.get('issues', []) + ai_result.get('issues', [])
    
    # Simple max score logic or average
    precheck_score = precheck.get('risk_score', 0)
    ai_score = ai_result.get('risk_score', 0)
    
    # Prioritize AI result if available, otherwise fallback
    final_score = max(precheck_score, ai_score)
    
    return {
        "overall_risk_level": ai_result.get('overall_risk_level', 'unknown'),
        "can_release": ai_result.get('can_release', not precheck.get('block_release', False)),
        "risk_score": final_score,
        "issues": combined_issues,
        "summary": ai_result.get('summary', 'Risk assessment complete.')
    }
