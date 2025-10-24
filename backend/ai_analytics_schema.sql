-- ===========================================================
-- 🤖 AI Usage Analytics Schema
-- ===========================================================
-- Track AI feature usage, content quality, and user feedback
-- ===========================================================

-- 1️⃣ AI Usage Table
CREATE TABLE IF NOT EXISTS ai_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(255),
    endpoint VARCHAR(100) NOT NULL,  -- 'generate', 'improve', 'full_proposal', 'analyze_risks'
    prompt_text TEXT,
    section_type VARCHAR(100),
    response_tokens INTEGER,
    response_time_ms INTEGER,
    was_accepted BOOLEAN DEFAULT NULL,  -- NULL = pending, TRUE = accepted, FALSE = rejected
    proposal_id INTEGER REFERENCES proposals(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2️⃣ AI Content Feedback Table
CREATE TABLE IF NOT EXISTS ai_content_feedback (
    id SERIAL PRIMARY KEY,
    ai_usage_id INTEGER REFERENCES ai_usage(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),  -- 1-5 stars
    feedback_text TEXT,
    quality_score INTEGER,  -- AI's own quality assessment
    was_edited BOOLEAN DEFAULT FALSE,  -- Did user edit AI content?
    edit_percentage DECIMAL(5,2),  -- How much was changed (0-100%)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3️⃣ AI Generated Proposals Tracking
ALTER TABLE proposals 
ADD COLUMN IF NOT EXISTS ai_generated BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS ai_metadata JSONB DEFAULT NULL;

-- 4️⃣ Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_ai_usage_user ON ai_usage(username);
CREATE INDEX IF NOT EXISTS idx_ai_usage_endpoint ON ai_usage(endpoint);
CREATE INDEX IF NOT EXISTS idx_ai_usage_created ON ai_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_usage ON ai_content_feedback(ai_usage_id);
CREATE INDEX IF NOT EXISTS idx_proposals_ai_generated ON proposals(ai_generated);

-- 5️⃣ View for AI Analytics Dashboard
CREATE OR REPLACE VIEW ai_analytics_summary AS
SELECT 
    DATE(created_at) as usage_date,
    endpoint,
    COUNT(*) as total_requests,
    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as accepted_count,
    COUNT(CASE WHEN was_accepted = FALSE THEN 1 END) as rejected_count,
    AVG(response_time_ms) as avg_response_time,
    AVG(response_tokens) as avg_tokens
FROM ai_usage
GROUP BY DATE(created_at), endpoint
ORDER BY usage_date DESC, total_requests DESC;

-- 6️⃣ View for User AI Usage Stats
CREATE OR REPLACE VIEW user_ai_stats AS
SELECT 
    username,
    COUNT(*) as total_ai_requests,
    COUNT(DISTINCT endpoint) as endpoints_used,
    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as content_accepted,
    COUNT(CASE WHEN endpoint = 'full_proposal' THEN 1 END) as full_proposals_generated,
    MAX(created_at) as last_used
FROM ai_usage
WHERE username IS NOT NULL
GROUP BY username
ORDER BY total_ai_requests DESC;

COMMENT ON TABLE ai_usage IS 'Tracks all AI assistant feature usage';
COMMENT ON TABLE ai_content_feedback IS 'User feedback and ratings for AI-generated content';
COMMENT ON VIEW ai_analytics_summary IS 'Daily summary of AI usage metrics';
COMMENT ON VIEW user_ai_stats IS 'Per-user AI usage statistics';

