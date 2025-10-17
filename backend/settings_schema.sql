-- Settings Management Tables for Proposal SOW Builder

-- System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    company_name VARCHAR(255) NOT NULL DEFAULT 'Your Company',
    company_email VARCHAR(255) NOT NULL DEFAULT 'contact@yourcompany.com',
    company_phone VARCHAR(50),
    company_address TEXT,
    company_website VARCHAR(255),
    default_proposal_template VARCHAR(100) DEFAULT 'proposal_standard',
    auto_save_interval INTEGER DEFAULT 30,
    email_notifications BOOLEAN DEFAULT true,
    approval_workflow VARCHAR(50) DEFAULT 'sequential',
    signature_required BOOLEAN DEFAULT true,
    pdf_watermark BOOLEAN DEFAULT false,
    client_portal_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Preferences Table
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id VARCHAR(255) PRIMARY KEY,
    theme VARCHAR(50) DEFAULT 'light',
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(100) DEFAULT 'UTC',
    dashboard_layout VARCHAR(50) DEFAULT 'grid',
    notifications_enabled BOOLEAN DEFAULT true,
    email_digest VARCHAR(50) DEFAULT 'daily',
    auto_logout INTEGER DEFAULT 30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email Settings Table
CREATE TABLE IF NOT EXISTS email_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    smtp_server VARCHAR(255) NOT NULL DEFAULT 'smtp.gmail.com',
    smtp_port INTEGER DEFAULT 587,
    smtp_username VARCHAR(255) NOT NULL DEFAULT '',
    smtp_password VARCHAR(255) NOT NULL DEFAULT '',
    smtp_use_tls BOOLEAN DEFAULT true,
    from_email VARCHAR(255) NOT NULL DEFAULT '',
    from_name VARCHAR(255) NOT NULL DEFAULT 'Proposal System',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- AI Settings Table
CREATE TABLE IF NOT EXISTS ai_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    openai_api_key VARCHAR(255),
    ai_analysis_enabled BOOLEAN DEFAULT true,
    risk_threshold INTEGER DEFAULT 50,
    auto_analysis BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Database Settings Table
CREATE TABLE IF NOT EXISTS database_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    backup_enabled BOOLEAN DEFAULT true,
    backup_frequency VARCHAR(50) DEFAULT 'daily',
    retention_days INTEGER DEFAULT 30,
    auto_cleanup BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification Settings Table
CREATE TABLE IF NOT EXISTS notification_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    proposal_created BOOLEAN DEFAULT true,
    proposal_updated BOOLEAN DEFAULT true,
    proposal_approved BOOLEAN DEFAULT true,
    proposal_signed BOOLEAN DEFAULT true,
    proposal_rejected BOOLEAN DEFAULT true,
    client_feedback BOOLEAN DEFAULT true,
    system_alerts BOOLEAN DEFAULT true,
    email_digest_frequency VARCHAR(50) DEFAULT 'daily',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Security Settings Table
CREATE TABLE IF NOT EXISTS security_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    password_min_length INTEGER DEFAULT 8,
    password_require_special BOOLEAN DEFAULT true,
    password_require_numbers BOOLEAN DEFAULT true,
    password_require_uppercase BOOLEAN DEFAULT true,
    session_timeout INTEGER DEFAULT 30,
    max_login_attempts INTEGER DEFAULT 5,
    lockout_duration INTEGER DEFAULT 15,
    two_factor_enabled BOOLEAN DEFAULT false,
    ip_whitelist TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Integration Settings Table
CREATE TABLE IF NOT EXISTS integration_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    google_workspace_enabled BOOLEAN DEFAULT false,
    microsoft_365_enabled BOOLEAN DEFAULT false,
    slack_enabled BOOLEAN DEFAULT false,
    zoom_enabled BOOLEAN DEFAULT false,
    salesforce_enabled BOOLEAN DEFAULT false,
    webhook_url VARCHAR(500),
    api_rate_limit INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Log Table for Settings Changes
CREATE TABLE IF NOT EXISTS settings_audit_log (
    id SERIAL PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    setting_name VARCHAR(255) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_by VARCHAR(255) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_settings_audit_category ON settings_audit_log(category);
CREATE INDEX IF NOT EXISTS idx_settings_audit_changed_by ON settings_audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_settings_audit_changed_at ON settings_audit_log(changed_at);

-- Insert default settings
INSERT INTO system_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO email_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO ai_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO database_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO notification_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO security_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
INSERT INTO integration_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $func$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$func$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_email_settings_updated_at BEFORE UPDATE ON email_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ai_settings_updated_at BEFORE UPDATE ON ai_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_database_settings_updated_at BEFORE UPDATE ON database_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notification_settings_updated_at BEFORE UPDATE ON notification_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_security_settings_updated_at BEFORE UPDATE ON security_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_integration_settings_updated_at BEFORE UPDATE ON integration_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
