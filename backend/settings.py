from fastapi import APIRouter

router = APIRouter()


@router.get('/ping')
def ping():
    return {'status': 'ok', 'source': 'settings_router'}
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import psycopg2
import psycopg2.extras
import os
from datetime import datetime
import json

router = APIRouter()

# Database connection helper
def get_db_connection():
    host = os.getenv("DB_HOST", "localhost")
    port = int(os.getenv("DB_PORT", "5432"))
    name = os.getenv("DB_NAME", "proposal_sow_builder")
    user = os.getenv("DB_USER", "postgres")
    pwd = os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=name,
        user=user,
        password=pwd,
    )

# Pydantic models
class SystemSettings(BaseModel):
    company_name: str = Field(..., description="Company name")
    company_email: str = Field(..., description="Company email")
    company_phone: Optional[str] = Field(None, description="Company phone")
    company_address: Optional[str] = Field(None, description="Company address")
    company_website: Optional[str] = Field(None, description="Company website")
    default_proposal_template: str = Field("proposal_standard", description="Default proposal template")
    auto_save_interval: int = Field(30, description="Auto-save interval in seconds")
    email_notifications: bool = Field(True, description="Enable email notifications")
    approval_workflow: str = Field("sequential", description="Approval workflow type")
    signature_required: bool = Field(True, description="Require digital signatures")
    pdf_watermark: bool = Field(False, description="Add watermark to PDFs")
    client_portal_enabled: bool = Field(True, description="Enable client portal")

class UserPreferences(BaseModel):
    theme: str = Field("light", description="UI theme preference")
    language: str = Field("en", description="Language preference")
    timezone: str = Field("UTC", description="Timezone preference")
    dashboard_layout: str = Field("grid", description="Dashboard layout preference")
    notifications_enabled: bool = Field(True, description="Enable notifications")
    email_digest: str = Field("daily", description="Email digest frequency")
    auto_logout: int = Field(30, description="Auto-logout timeout in minutes")

class EmailSettings(BaseModel):
    smtp_server: str = Field(..., description="SMTP server")
    smtp_port: int = Field(587, description="SMTP port")
    smtp_username: str = Field(..., description="SMTP username")
    smtp_password: str = Field(..., description="SMTP password")
    smtp_use_tls: bool = Field(True, description="Use TLS")
    from_email: str = Field(..., description="From email address")
    from_name: str = Field(..., description="From name")

class AISettings(BaseModel):
    openai_api_key: Optional[str] = Field(None, description="OpenAI API key")
    ai_analysis_enabled: bool = Field(True, description="Enable AI analysis")
    risk_threshold: int = Field(50, description="Risk threshold for AI warnings")
    auto_analysis: bool = Field(False, description="Enable automatic AI analysis")

class DatabaseSettings(BaseModel):
    backup_enabled: bool = Field(True, description="Enable database backups")
    backup_frequency: str = Field("daily", description="Backup frequency")
    retention_days: int = Field(30, description="Backup retention in days")
    auto_cleanup: bool = Field(True, description="Enable automatic cleanup")

# Settings update models
class SettingsUpdate(BaseModel):
    category: str = Field(..., description="Settings category")
    settings: Dict[str, Any] = Field(..., description="Settings to update")

# API Endpoints

@router.get("/settings")
def get_all_settings():
    """Get all system settings"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                # Get system settings
                cur.execute("SELECT * FROM system_settings WHERE id = 1")
                system_settings = cur.fetchone()
                
                # Get user preferences (for current user - you might want to add user_id)
                cur.execute("SELECT * FROM user_preferences WHERE user_id = 'default_user'")
                user_preferences = cur.fetchone()
                
                # Get email settings
                cur.execute("SELECT * FROM email_settings WHERE id = 1")
                email_settings = cur.fetchone()
                
                # Get AI settings
                cur.execute("SELECT * FROM ai_settings WHERE id = 1")
                ai_settings = cur.fetchone()
                
                # Get database settings
                cur.execute("SELECT * FROM database_settings WHERE id = 1")
                database_settings = cur.fetchone()
                
                return {
                    "system": dict(system_settings) if system_settings else {},
                    "user_preferences": dict(user_preferences) if user_preferences else {},
                    "email": dict(email_settings) if email_settings else {},
                    "ai": dict(ai_settings) if ai_settings else {},
                    "database": dict(database_settings) if database_settings else {}
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch settings: {str(e)}")

@router.get("/settings/{category}")
def get_settings_category(category: str):
    """Get settings for a specific category"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                if category == "system":
                    cur.execute("SELECT * FROM system_settings WHERE id = 1")
                elif category == "user_preferences":
                    cur.execute("SELECT * FROM user_preferences WHERE user_id = 'default_user'")
                elif category == "email":
                    cur.execute("SELECT * FROM email_settings WHERE id = 1")
                elif category == "ai":
                    cur.execute("SELECT * FROM ai_settings WHERE id = 1")
                elif category == "database":
                    cur.execute("SELECT * FROM database_settings WHERE id = 1")
                else:
                    raise HTTPException(status_code=400, detail="Invalid category")
                
                result = cur.fetchone()
                if not result:
                    return {}
                return dict(result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch {category} settings: {str(e)}")

@router.put("/settings/{category}")
def update_settings_category(category: str, settings: Dict[str, Any]):
    """Update settings for a specific category"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                if category == "system":
                    # Update system settings
                    cur.execute("""
                        INSERT INTO system_settings (id, company_name, company_email, company_phone, 
                                                   company_address, company_website, default_proposal_template,
                                                   auto_save_interval, email_notifications, approval_workflow,
                                                   signature_required, pdf_watermark, client_portal_enabled, updated_at)
                        VALUES (1, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            company_name = EXCLUDED.company_name,
                            company_email = EXCLUDED.company_email,
                            company_phone = EXCLUDED.company_phone,
                            company_address = EXCLUDED.company_address,
                            company_website = EXCLUDED.company_website,
                            default_proposal_template = EXCLUDED.default_proposal_template,
                            auto_save_interval = EXCLUDED.auto_save_interval,
                            email_notifications = EXCLUDED.email_notifications,
                            approval_workflow = EXCLUDED.approval_workflow,
                            signature_required = EXCLUDED.signature_required,
                            pdf_watermark = EXCLUDED.pdf_watermark,
                            client_portal_enabled = EXCLUDED.client_portal_enabled,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        settings.get("company_name", ""),
                        settings.get("company_email", ""),
                        settings.get("company_phone"),
                        settings.get("company_address"),
                        settings.get("company_website"),
                        settings.get("default_proposal_template", "proposal_standard"),
                        settings.get("auto_save_interval", 30),
                        settings.get("email_notifications", True),
                        settings.get("approval_workflow", "sequential"),
                        settings.get("signature_required", True),
                        settings.get("pdf_watermark", False),
                        settings.get("client_portal_enabled", True),
                        datetime.now()
                    ))
                
                elif category == "user_preferences":
                    # Update user preferences
                    cur.execute("""
                        INSERT INTO user_preferences (user_id, theme, language, timezone, dashboard_layout,
                                                    notifications_enabled, email_digest, auto_logout, updated_at)
                        VALUES ('default_user', %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (user_id) DO UPDATE SET
                            theme = EXCLUDED.theme,
                            language = EXCLUDED.language,
                            timezone = EXCLUDED.timezone,
                            dashboard_layout = EXCLUDED.dashboard_layout,
                            notifications_enabled = EXCLUDED.notifications_enabled,
                            email_digest = EXCLUDED.email_digest,
                            auto_logout = EXCLUDED.auto_logout,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        settings.get("theme", "light"),
                        settings.get("language", "en"),
                        settings.get("timezone", "UTC"),
                        settings.get("dashboard_layout", "grid"),
                        settings.get("notifications_enabled", True),
                        settings.get("email_digest", "daily"),
                        settings.get("auto_logout", 30),
                        datetime.now()
                    ))
                
                elif category == "email":
                    # Update email settings
                    cur.execute("""
                        INSERT INTO email_settings (id, smtp_server, smtp_port, smtp_username, smtp_password,
                                                  smtp_use_tls, from_email, from_name, updated_at)
                        VALUES (1, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            smtp_server = EXCLUDED.smtp_server,
                            smtp_port = EXCLUDED.smtp_port,
                            smtp_username = EXCLUDED.smtp_username,
                            smtp_password = EXCLUDED.smtp_password,
                            smtp_use_tls = EXCLUDED.smtp_use_tls,
                            from_email = EXCLUDED.from_email,
                            from_name = EXCLUDED.from_name,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        settings.get("smtp_server", ""),
                        settings.get("smtp_port", 587),
                        settings.get("smtp_username", ""),
                        settings.get("smtp_password", ""),
                        settings.get("smtp_use_tls", True),
                        settings.get("from_email", ""),
                        settings.get("from_name", ""),
                        datetime.now()
                    ))
                
                elif category == "ai":
                    # Update AI settings
                    cur.execute("""
                        INSERT INTO ai_settings (id, openai_api_key, ai_analysis_enabled, risk_threshold,
                                               auto_analysis, updated_at)
                        VALUES (1, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            openai_api_key = EXCLUDED.openai_api_key,
                            ai_analysis_enabled = EXCLUDED.ai_analysis_enabled,
                            risk_threshold = EXCLUDED.risk_threshold,
                            auto_analysis = EXCLUDED.auto_analysis,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        settings.get("openai_api_key"),
                        settings.get("ai_analysis_enabled", True),
                        settings.get("risk_threshold", 50),
                        settings.get("auto_analysis", False),
                        datetime.now()
                    ))
                
                elif category == "database":
                    # Update database settings
                    cur.execute("""
                        INSERT INTO database_settings (id, backup_enabled, backup_frequency, retention_days,
                                                     auto_cleanup, updated_at)
                        VALUES (1, %s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            backup_enabled = EXCLUDED.backup_enabled,
                            backup_frequency = EXCLUDED.backup_frequency,
                            retention_days = EXCLUDED.retention_days,
                            auto_cleanup = EXCLUDED.auto_cleanup,
                            updated_at = EXCLUDED.updated_at
                    """, (
                        settings.get("backup_enabled", True),
                        settings.get("backup_frequency", "daily"),
                        settings.get("retention_days", 30),
                        settings.get("auto_cleanup", True),
                        datetime.now()
                    ))
                
                else:
                    raise HTTPException(status_code=400, detail="Invalid category")
                
                conn.commit()
                return {"message": f"{category} settings updated successfully"}
                
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update {category} settings: {str(e)}")

@router.post("/settings/reset/{category}")
def reset_settings_category(category: str):
    """Reset settings for a specific category to defaults"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                if category == "system":
                    # Reset to default system settings
                    cur.execute("""
                        INSERT INTO system_settings (id, company_name, company_email, company_phone, 
                                                   company_address, company_website, default_proposal_template,
                                                   auto_save_interval, email_notifications, approval_workflow,
                                                   signature_required, pdf_watermark, client_portal_enabled, updated_at)
                        VALUES (1, 'Your Company', 'contact@yourcompany.com', NULL, NULL, NULL, 
                               'proposal_standard', 30, true, 'sequential', true, false, true, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            company_name = 'Your Company',
                            company_email = 'contact@yourcompany.com',
                            company_phone = NULL,
                            company_address = NULL,
                            company_website = NULL,
                            default_proposal_template = 'proposal_standard',
                            auto_save_interval = 30,
                            email_notifications = true,
                            approval_workflow = 'sequential',
                            signature_required = true,
                            pdf_watermark = false,
                            client_portal_enabled = true,
                            updated_at = %s
                    """, (datetime.now(), datetime.now()))
                
                elif category == "user_preferences":
                    # Reset to default user preferences
                    cur.execute("""
                        INSERT INTO user_preferences (user_id, theme, language, timezone, dashboard_layout,
                                                    notifications_enabled, email_digest, auto_logout, updated_at)
                        VALUES ('default_user', 'light', 'en', 'UTC', 'grid', true, 'daily', 30, %s)
                        ON CONFLICT (user_id) DO UPDATE SET
                            theme = 'light',
                            language = 'en',
                            timezone = 'UTC',
                            dashboard_layout = 'grid',
                            notifications_enabled = true,
                            email_digest = 'daily',
                            auto_logout = 30,
                            updated_at = %s
                    """, (datetime.now(), datetime.now()))
                
                # Add similar reset logic for other categories...
                
                conn.commit()
                return {"message": f"{category} settings reset to defaults"}
                
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reset {category} settings: {str(e)}")

@router.get("/settings/export")
def export_settings():
    """Export all settings as JSON"""
    try:
        settings = get_all_settings()
        return {"settings": settings, "exported_at": datetime.now().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to export settings: {str(e)}")

@router.post("/settings/import")
def import_settings(settings_data: Dict[str, Any]):
    """Import settings from JSON"""
    try:
        for category, settings in settings_data.items():
            if category in ["system", "user_preferences", "email", "ai", "database"]:
                update_settings_category(category, settings)
        return {"message": "Settings imported successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to import settings: {str(e)}")
