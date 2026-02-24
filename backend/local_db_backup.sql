--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: client_role_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.client_role_enum AS ENUM (
    'Client',
    'Approver',
    'Admin',
    'Financial Manager'
);


ALTER TYPE public.client_role_enum OWNER TO postgres;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END; $$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

--
-- Name: update_content_modules_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_content_modules_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_content_modules_updated_at() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.activity_log (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    user_id integer,
    action_type character varying(100) NOT NULL,
    action_description text NOT NULL,
    metadata jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.activity_log OWNER TO postgres;

--
-- Name: activity_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.activity_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.activity_log_id_seq OWNER TO postgres;

--
-- Name: activity_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.activity_log_id_seq OWNED BY public.activity_log.id;


--
-- Name: ai_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_settings (
    id integer DEFAULT 1 NOT NULL,
    openai_api_key character varying(255),
    ai_analysis_enabled boolean DEFAULT true,
    risk_threshold integer DEFAULT 50,
    auto_analysis boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.ai_settings OWNER TO postgres;

--
-- Name: approvals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.approvals (
    id integer NOT NULL,
    proposal_id integer,
    sow_id integer,
    approver_id character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    comments text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT approvals_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT check_proposal_or_sow CHECK ((((proposal_id IS NOT NULL) AND (sow_id IS NULL)) OR ((proposal_id IS NULL) AND (sow_id IS NOT NULL))))
);


ALTER TABLE public.approvals OWNER TO postgres;

--
-- Name: approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.approvals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.approvals_id_seq OWNER TO postgres;

--
-- Name: approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.approvals_id_seq OWNED BY public.approvals.id;


--
-- Name: client_dashboard_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.client_dashboard_tokens (
    id integer NOT NULL,
    token text NOT NULL,
    client_id integer NOT NULL,
    proposal_id integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.client_dashboard_tokens OWNER TO postgres;

--
-- Name: client_dashboard_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.client_dashboard_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.client_dashboard_tokens_id_seq OWNER TO postgres;

--
-- Name: client_dashboard_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.client_dashboard_tokens_id_seq OWNED BY public.client_dashboard_tokens.id;


--
-- Name: client_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.client_notes (
    id integer NOT NULL,
    client_id integer NOT NULL,
    note_text text NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.client_notes OWNER TO postgres;

--
-- Name: client_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.client_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.client_notes_id_seq OWNER TO postgres;

--
-- Name: client_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.client_notes_id_seq OWNED BY public.client_notes.id;


--
-- Name: client_onboarding_invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.client_onboarding_invitations (
    id integer NOT NULL,
    access_token character varying(255) NOT NULL,
    invited_email character varying(255) NOT NULL,
    invited_by integer NOT NULL,
    expected_company character varying(255),
    status character varying(50) DEFAULT 'pending'::character varying,
    invited_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    completed_at timestamp without time zone,
    expires_at timestamp without time zone,
    client_id integer,
    email_verified_at timestamp without time zone,
    verification_code_hash character varying(255),
    code_expires_at timestamp without time zone,
    verification_attempts integer DEFAULT 0,
    last_code_sent_at timestamp without time zone
);


ALTER TABLE public.client_onboarding_invitations OWNER TO postgres;

--
-- Name: client_onboarding_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.client_onboarding_invitations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.client_onboarding_invitations_id_seq OWNER TO postgres;

--
-- Name: client_onboarding_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.client_onboarding_invitations_id_seq OWNED BY public.client_onboarding_invitations.id;


--
-- Name: client_proposals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.client_proposals (
    id integer NOT NULL,
    client_id integer NOT NULL,
    proposal_id integer NOT NULL,
    relationship_type character varying(50) DEFAULT 'primary'::character varying,
    linked_by integer,
    linked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.client_proposals OWNER TO postgres;

--
-- Name: client_proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.client_proposals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.client_proposals_id_seq OWNER TO postgres;

--
-- Name: client_proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.client_proposals_id_seq OWNED BY public.client_proposals.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    email character varying(150) NOT NULL,
    organization character varying(150),
    role public.client_role_enum,
    token uuid NOT NULL,
    is_active boolean,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    company_name character varying(255) NOT NULL,
    contact_person character varying(255)
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clients_id_seq OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: collaboration_invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.collaboration_invitations (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    invited_email character varying(255) NOT NULL,
    invited_by integer NOT NULL,
    access_token character varying(500) NOT NULL,
    permission_level character varying(50) DEFAULT 'comment'::character varying,
    status character varying(50) DEFAULT 'pending'::character varying,
    invited_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    accessed_at timestamp without time zone,
    expires_at timestamp without time zone,
    is_external boolean DEFAULT false
);


ALTER TABLE public.collaboration_invitations OWNER TO postgres;

--
-- Name: collaboration_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.collaboration_invitations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.collaboration_invitations_id_seq OWNER TO postgres;

--
-- Name: collaboration_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.collaboration_invitations_id_seq OWNED BY public.collaboration_invitations.id;


--
-- Name: collaborators; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.collaborators (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    email character varying(255) NOT NULL,
    user_id integer,
    invited_by integer NOT NULL,
    permission_level character varying(50) DEFAULT 'comment'::character varying,
    status character varying(50) DEFAULT 'active'::character varying,
    joined_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at timestamp without time zone
);


ALTER TABLE public.collaborators OWNER TO postgres;

--
-- Name: collaborators_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.collaborators_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.collaborators_id_seq OWNER TO postgres;

--
-- Name: collaborators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.collaborators_id_seq OWNED BY public.collaborators.id;


--
-- Name: comment_mentions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comment_mentions (
    id integer NOT NULL,
    comment_id integer NOT NULL,
    mentioned_user_id integer NOT NULL,
    mentioned_by_user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_read boolean DEFAULT false
);


ALTER TABLE public.comment_mentions OWNER TO postgres;

--
-- Name: comment_mentions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.comment_mentions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.comment_mentions_id_seq OWNER TO postgres;

--
-- Name: comment_mentions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.comment_mentions_id_seq OWNED BY public.comment_mentions.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    content text NOT NULL,
    author_id character varying(255) NOT NULL,
    resource_type character varying(50) NOT NULL,
    resource_id character varying(255) NOT NULL,
    parent_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_edited boolean DEFAULT false,
    is_deleted boolean DEFAULT false,
    mentions character varying(255)[] DEFAULT '{}'::character varying[],
    CONSTRAINT comments_resource_type_check CHECK (((resource_type)::text = ANY ((ARRAY['proposal'::character varying, 'sow'::character varying, 'workspace'::character varying, 'team'::character varying])::text[])))
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- Name: content; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content (
    id integer NOT NULL,
    key character varying(255) NOT NULL,
    label character varying(500) NOT NULL,
    content text,
    category character varying(100) DEFAULT 'Templates'::character varying,
    is_folder boolean DEFAULT false,
    parent_id integer,
    public_id character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_deleted boolean DEFAULT false
);


ALTER TABLE public.content OWNER TO postgres;

--
-- Name: content_blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content_blocks (
    id integer NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    content text,
    is_folder boolean DEFAULT false,
    parent_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    category text DEFAULT 'Templates'::text,
    public_id text
);


ALTER TABLE public.content_blocks OWNER TO postgres;

--
-- Name: content_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.content_blocks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.content_blocks_id_seq OWNER TO postgres;

--
-- Name: content_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.content_blocks_id_seq OWNED BY public.content_blocks.id;


--
-- Name: content_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.content_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.content_id_seq OWNER TO postgres;

--
-- Name: content_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.content_id_seq OWNED BY public.content.id;


--
-- Name: content_library; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content_library (
    id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    category character varying(100),
    tags text[],
    is_template boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.content_library OWNER TO postgres;

--
-- Name: content_library_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.content_library_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.content_library_id_seq OWNER TO postgres;

--
-- Name: content_library_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.content_library_id_seq OWNED BY public.content_library.id;


--
-- Name: content_modules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.content_modules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    body text NOT NULL,
    version integer DEFAULT 1,
    created_by uuid,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    is_editable boolean DEFAULT false
);


ALTER TABLE public.content_modules OWNER TO postgres;

--
-- Name: database_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.database_settings (
    id integer DEFAULT 1 NOT NULL,
    backup_enabled boolean DEFAULT true,
    backup_frequency character varying(50) DEFAULT 'daily'::character varying,
    retention_days integer DEFAULT 30,
    auto_cleanup boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.database_settings OWNER TO postgres;

--
-- Name: document_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.document_comments (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    comment_text text NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    section_index integer,
    highlighted_text text,
    status character varying(50) DEFAULT 'open'::character varying,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    resolved_by integer,
    resolved_at timestamp without time zone,
    parent_id integer,
    block_type character varying(50),
    block_id character varying(255),
    section_name character varying(255)
);


ALTER TABLE public.document_comments OWNER TO postgres;

--
-- Name: document_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.document_comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.document_comments_id_seq OWNER TO postgres;

--
-- Name: document_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.document_comments_id_seq OWNED BY public.document_comments.id;


--
-- Name: email_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.email_settings (
    id integer DEFAULT 1 NOT NULL,
    smtp_server character varying(255) DEFAULT 'smtp.gmail.com'::character varying NOT NULL,
    smtp_port integer DEFAULT 587,
    smtp_username character varying(255) DEFAULT ''::character varying NOT NULL,
    smtp_password character varying(255) DEFAULT ''::character varying NOT NULL,
    smtp_use_tls boolean DEFAULT true,
    from_email character varying(255) DEFAULT ''::character varying NOT NULL,
    from_name character varying(255) DEFAULT 'Proposal System'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.email_settings OWNER TO postgres;

--
-- Name: email_verification_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.email_verification_events (
    id integer NOT NULL,
    invitation_id integer NOT NULL,
    email character varying(255) NOT NULL,
    event_type character varying(50) NOT NULL,
    event_detail text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.email_verification_events OWNER TO postgres;

--
-- Name: email_verification_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.email_verification_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.email_verification_events_id_seq OWNER TO postgres;

--
-- Name: email_verification_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.email_verification_events_id_seq OWNED BY public.email_verification_events.id;


--
-- Name: module_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.module_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    module_id uuid,
    version integer NOT NULL,
    snapshot text NOT NULL,
    created_by uuid,
    created_at timestamp without time zone DEFAULT now(),
    note text
);


ALTER TABLE public.module_versions OWNER TO postgres;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id integer NOT NULL,
    title character varying(255) NOT NULL,
    message text NOT NULL,
    type character varying(50) NOT NULL,
    resource_type character varying(50) NOT NULL,
    resource_id character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    read_at timestamp with time zone,
    is_read boolean DEFAULT false,
    action_url text,
    metadata jsonb DEFAULT '{}'::jsonb,
    proposal_id integer,
    notification_type character varying(100)
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: proposal_client_activity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_client_activity (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    client_id integer,
    event_type character varying(50) NOT NULL,
    metadata jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.proposal_client_activity OWNER TO postgres;

--
-- Name: proposal_client_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposal_client_activity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposal_client_activity_id_seq OWNER TO postgres;

--
-- Name: proposal_client_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposal_client_activity_id_seq OWNED BY public.proposal_client_activity.id;


--
-- Name: proposal_client_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_client_session (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    client_id integer,
    session_start timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    session_end timestamp without time zone,
    total_seconds integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.proposal_client_session OWNER TO postgres;

--
-- Name: proposal_client_session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposal_client_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposal_client_session_id_seq OWNER TO postgres;

--
-- Name: proposal_client_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposal_client_session_id_seq OWNED BY public.proposal_client_session.id;


--
-- Name: proposal_feedback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_feedback (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    client_id integer NOT NULL,
    feedback_text text,
    rating integer,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT proposal_feedback_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.proposal_feedback OWNER TO postgres;

--
-- Name: proposal_feedback_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposal_feedback_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposal_feedback_id_seq OWNER TO postgres;

--
-- Name: proposal_feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposal_feedback_id_seq OWNED BY public.proposal_feedback.id;


--
-- Name: proposal_signatures; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_signatures (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    envelope_id character varying(255),
    signer_name character varying(255) NOT NULL,
    signer_email character varying(255) NOT NULL,
    signer_title character varying(255),
    status character varying(50) DEFAULT 'sent'::character varying,
    signing_url text,
    sent_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    signed_at timestamp without time zone,
    declined_at timestamp without time zone,
    decline_reason text,
    signed_document_url text,
    created_by integer
);


ALTER TABLE public.proposal_signatures OWNER TO postgres;

--
-- Name: proposal_signatures_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposal_signatures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposal_signatures_id_seq OWNER TO postgres;

--
-- Name: proposal_signatures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposal_signatures_id_seq OWNED BY public.proposal_signatures.id;


--
-- Name: proposal_system_feedback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_system_feedback (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.proposal_system_feedback OWNER TO postgres;

--
-- Name: proposal_system_proposals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_system_proposals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(500) NOT NULL,
    client_name character varying(255),
    dtype character varying(50) DEFAULT 'Proposal'::character varying,
    status character varying(50) DEFAULT 'Draft'::character varying,
    sections jsonb,
    mandatory_sections jsonb,
    approval jsonb,
    readiness_score numeric(5,2) DEFAULT 0.0,
    readiness_issues jsonb,
    signed_at timestamp with time zone,
    signed_by character varying(255),
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.proposal_system_proposals OWNER TO postgres;

--
-- Name: proposal_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    company character varying(255),
    role character varying(50) DEFAULT 'user'::character varying,
    is_active boolean DEFAULT true,
    email_verified boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.proposal_users OWNER TO postgres;

--
-- Name: proposal_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposal_versions (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    version_number integer NOT NULL,
    content text NOT NULL,
    created_by character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    change_description character varying(500)
);


ALTER TABLE public.proposal_versions OWNER TO postgres;

--
-- Name: proposal_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposal_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposal_versions_id_seq OWNER TO postgres;

--
-- Name: proposal_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposal_versions_id_seq OWNED BY public.proposal_versions.id;


--
-- Name: proposals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proposals (
    id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    content text,
    status character varying(50) DEFAULT 'draft'::character varying,
    client_name character varying(255),
    client_email character varying(255),
    budget numeric(12,2),
    timeline_days integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT proposals_status_check CHECK ((((status)::text = ANY ((ARRAY['draft'::character varying, 'Draft'::character varying, 'submitted'::character varying, 'Submitted'::character varying, 'approved'::character varying, 'Approved'::character varying, 'rejected'::character varying, 'Rejected'::character varying, 'archived'::character varying, 'Archived'::character varying, 'Pending CEO Approval'::character varying, 'Sent to Client'::character varying, 'Sent for Signature'::character varying, 'In Review'::character varying, 'Signed'::character varying, 'signed'::character varying, 'Client Signed'::character varying, 'Client Approved'::character varying, 'Client Declined'::character varying])::text[])) OR (status IS NULL)))
);


ALTER TABLE public.proposals OWNER TO postgres;

--
-- Name: proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proposals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposals_id_seq OWNER TO postgres;

--
-- Name: proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proposals_id_seq OWNED BY public.proposals.id;


--
-- Name: section_locks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.section_locks (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    section_id character varying(255) NOT NULL,
    locked_by integer NOT NULL,
    locked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone
);


ALTER TABLE public.section_locks OWNER TO postgres;

--
-- Name: section_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.section_locks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.section_locks_id_seq OWNER TO postgres;

--
-- Name: section_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.section_locks_id_seq OWNED BY public.section_locks.id;


--
-- Name: settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.settings (
    id integer NOT NULL,
    key character varying(255) NOT NULL,
    value text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.settings OWNER TO postgres;

--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.settings_id_seq OWNER TO postgres;

--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: sows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sows (
    id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    content text,
    status character varying(50) DEFAULT 'draft'::character varying,
    client_name character varying(255),
    client_email character varying(255),
    project_scope text,
    deliverables text,
    timeline character varying(255),
    budget numeric(12,2),
    payment_terms character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sows_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'approved'::character varying, 'rejected'::character varying, 'archived'::character varying])::text[])))
);


ALTER TABLE public.sows OWNER TO postgres;

--
-- Name: sows_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sows_id_seq OWNER TO postgres;

--
-- Name: sows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sows_id_seq OWNED BY public.sows.id;


--
-- Name: suggested_changes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suggested_changes (
    id integer NOT NULL,
    proposal_id integer NOT NULL,
    section_id character varying(255),
    suggested_by integer NOT NULL,
    suggestion_text text NOT NULL,
    original_text text,
    status character varying(50) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    resolved_at timestamp without time zone,
    resolved_by integer,
    resolution_action character varying(50)
);


ALTER TABLE public.suggested_changes OWNER TO postgres;

--
-- Name: suggested_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.suggested_changes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.suggested_changes_id_seq OWNER TO postgres;

--
-- Name: suggested_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.suggested_changes_id_seq OWNED BY public.suggested_changes.id;


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_settings (
    id integer DEFAULT 1 NOT NULL,
    company_name character varying(255) DEFAULT 'Your Company'::character varying NOT NULL,
    company_email character varying(255) DEFAULT 'contact@yourcompany.com'::character varying NOT NULL,
    company_phone character varying(50),
    company_address text,
    company_website character varying(255),
    default_proposal_template character varying(100) DEFAULT 'proposal_standard'::character varying,
    auto_save_interval integer DEFAULT 30,
    email_notifications boolean DEFAULT true,
    approval_workflow character varying(50) DEFAULT 'sequential'::character varying,
    signature_required boolean DEFAULT true,
    pdf_watermark boolean DEFAULT false,
    client_portal_enabled boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.system_settings OWNER TO postgres;

--
-- Name: team_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team_members (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    team_id uuid NOT NULL,
    user_id character varying(255) NOT NULL,
    role character varying(50) DEFAULT 'member'::character varying NOT NULL,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT team_members_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'member'::character varying])::text[])))
);


ALTER TABLE public.team_members OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teams (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    created_by character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    settings jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true
);


ALTER TABLE public.teams OWNER TO postgres;

--
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates (
    id integer NOT NULL,
    key text NOT NULL,
    dtype text NOT NULL,
    name text NOT NULL,
    sections text[] NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT templates_dtype_check CHECK ((dtype = ANY (ARRAY['Proposal'::text, 'SOW'::text, 'RFI'::text])))
);


ALTER TABLE public.templates OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.templates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.templates_id_seq OWNER TO postgres;

--
-- Name: templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_id_seq OWNED BY public.templates.id;


--
-- Name: user_email_verification_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_email_verification_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    used_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_email_verification_tokens OWNER TO postgres;

--
-- Name: user_email_verification_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_email_verification_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_email_verification_tokens_id_seq OWNER TO postgres;

--
-- Name: user_email_verification_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_email_verification_tokens_id_seq OWNED BY public.user_email_verification_tokens.id;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_preferences (
    user_id character varying(255) NOT NULL,
    theme character varying(50) DEFAULT 'light'::character varying,
    language character varying(10) DEFAULT 'en'::character varying,
    timezone character varying(100) DEFAULT 'UTC'::character varying,
    dashboard_layout character varying(50) DEFAULT 'grid'::character varying,
    notifications_enabled boolean DEFAULT true,
    email_digest character varying(50) DEFAULT 'daily'::character varying,
    auto_logout integer DEFAULT 30,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_preferences OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    full_name character varying(255),
    role character varying(50) DEFAULT 'user'::character varying,
    department character varying(255),
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_email_verified boolean DEFAULT true
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: verification_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verification_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token character varying(255) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.verification_tokens OWNER TO postgres;

--
-- Name: verification_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.verification_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.verification_tokens_id_seq OWNER TO postgres;

--
-- Name: verification_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verification_tokens_id_seq OWNED BY public.verification_tokens.id;


--
-- Name: verify_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verify_tokens (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp without time zone NOT NULL
);


ALTER TABLE public.verify_tokens OWNER TO postgres;

--
-- Name: verify_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.verify_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.verify_tokens_id_seq OWNER TO postgres;

--
-- Name: verify_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.verify_tokens_id_seq OWNED BY public.verify_tokens.id;


--
-- Name: workspace_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workspace_documents (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    workspace_id uuid NOT NULL,
    document_id character varying(255) NOT NULL,
    document_type character varying(50) NOT NULL,
    added_by character varying(255) NOT NULL,
    added_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT workspace_documents_document_type_check CHECK (((document_type)::text = ANY ((ARRAY['proposal'::character varying, 'sow'::character varying, 'template'::character varying, 'content'::character varying, 'file'::character varying])::text[])))
);


ALTER TABLE public.workspace_documents OWNER TO postgres;

--
-- Name: workspace_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workspace_members (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    workspace_id uuid NOT NULL,
    user_id character varying(255) NOT NULL,
    permission character varying(50) DEFAULT 'read'::character varying NOT NULL,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT workspace_members_permission_check CHECK (((permission)::text = ANY ((ARRAY['read'::character varying, 'edit'::character varying, 'admin'::character varying])::text[])))
);


ALTER TABLE public.workspace_members OWNER TO postgres;

--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.workspaces (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    team_id uuid NOT NULL,
    created_by character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    settings jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true
);


ALTER TABLE public.workspaces OWNER TO postgres;

--
-- Name: activity_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity_log ALTER COLUMN id SET DEFAULT nextval('public.activity_log_id_seq'::regclass);


--
-- Name: approvals id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.approvals ALTER COLUMN id SET DEFAULT nextval('public.approvals_id_seq'::regclass);


--
-- Name: client_dashboard_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_dashboard_tokens ALTER COLUMN id SET DEFAULT nextval('public.client_dashboard_tokens_id_seq'::regclass);


--
-- Name: client_notes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_notes ALTER COLUMN id SET DEFAULT nextval('public.client_notes_id_seq'::regclass);


--
-- Name: client_onboarding_invitations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_onboarding_invitations ALTER COLUMN id SET DEFAULT nextval('public.client_onboarding_invitations_id_seq'::regclass);


--
-- Name: client_proposals id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals ALTER COLUMN id SET DEFAULT nextval('public.client_proposals_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: collaboration_invitations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaboration_invitations ALTER COLUMN id SET DEFAULT nextval('public.collaboration_invitations_id_seq'::regclass);


--
-- Name: collaborators id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators ALTER COLUMN id SET DEFAULT nextval('public.collaborators_id_seq'::regclass);


--
-- Name: comment_mentions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comment_mentions ALTER COLUMN id SET DEFAULT nextval('public.comment_mentions_id_seq'::regclass);


--
-- Name: content id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content ALTER COLUMN id SET DEFAULT nextval('public.content_id_seq'::regclass);


--
-- Name: content_blocks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_blocks ALTER COLUMN id SET DEFAULT nextval('public.content_blocks_id_seq'::regclass);


--
-- Name: content_library id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_library ALTER COLUMN id SET DEFAULT nextval('public.content_library_id_seq'::regclass);


--
-- Name: document_comments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments ALTER COLUMN id SET DEFAULT nextval('public.document_comments_id_seq'::regclass);


--
-- Name: email_verification_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_verification_events ALTER COLUMN id SET DEFAULT nextval('public.email_verification_events_id_seq'::regclass);


--
-- Name: proposal_client_activity id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_activity ALTER COLUMN id SET DEFAULT nextval('public.proposal_client_activity_id_seq'::regclass);


--
-- Name: proposal_client_session id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_session ALTER COLUMN id SET DEFAULT nextval('public.proposal_client_session_id_seq'::regclass);


--
-- Name: proposal_feedback id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_feedback ALTER COLUMN id SET DEFAULT nextval('public.proposal_feedback_id_seq'::regclass);


--
-- Name: proposal_signatures id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_signatures ALTER COLUMN id SET DEFAULT nextval('public.proposal_signatures_id_seq'::regclass);


--
-- Name: proposal_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_versions ALTER COLUMN id SET DEFAULT nextval('public.proposal_versions_id_seq'::regclass);


--
-- Name: proposals id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals ALTER COLUMN id SET DEFAULT nextval('public.proposals_id_seq'::regclass);


--
-- Name: section_locks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.section_locks ALTER COLUMN id SET DEFAULT nextval('public.section_locks_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: sows id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sows ALTER COLUMN id SET DEFAULT nextval('public.sows_id_seq'::regclass);


--
-- Name: suggested_changes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_changes ALTER COLUMN id SET DEFAULT nextval('public.suggested_changes_id_seq'::regclass);


--
-- Name: templates id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates ALTER COLUMN id SET DEFAULT nextval('public.templates_id_seq'::regclass);


--
-- Name: user_email_verification_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_email_verification_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_email_verification_tokens_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: verification_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens ALTER COLUMN id SET DEFAULT nextval('public.verification_tokens_id_seq'::regclass);


--
-- Name: verify_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verify_tokens ALTER COLUMN id SET DEFAULT nextval('public.verify_tokens_id_seq'::regclass);


--
-- Data for Name: activity_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.activity_log (id, proposal_id, user_id, action_type, action_description, metadata, created_at) FROM stdin;
1	34	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 13, "section_index": null}	2025-10-28 18:20:52.107097
2	35	22	signature_requested	Proposal sent to Unathi for signature	{"envelope_id": "ca48a921-a856-40f7-ab4b-2f2ed735021a", "signer_email": "umsibanda.1994@gmail.com"}	2025-10-29 21:11:53.621789
3	35	22	signature_requested	Proposal sent to Unathi for signature	{"envelope_id": "87ed819e-39f5-4502-95d5-3eda19a3df6e", "signer_email": "umsibanda.1994@gmail.com"}	2025-10-29 21:26:49.466005
4	36	22	signature_requested	Proposal sent to unathiInc for signature	{"envelope_id": "a1d598e4-a8ec-4eb1-af81-59266eae3a3d", "signer_email": "umsibanda.1994@gmail.com"}	2025-10-31 13:33:23.224552
8	41	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 21, "section_index": null}	2025-11-07 14:03:02.005715
9	42	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 22, "section_index": null}	2025-11-07 14:15:10.613361
10	43	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 24, "section_index": null}	2025-11-07 15:09:54.835787
11	43	22	signature_requested	Proposal sent to Unathi for signature	{"envelope_id": "6cae8671-5c4b-4128-9082-0c37c7b8a134", "signer_email": "umsibanda.1994@gmail.com"}	2025-11-09 21:02:00.333802
12	44	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 26, "section_index": null}	2025-11-10 20:32:03.614376
13	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 27, "section_index": null}	2025-11-10 20:34:54.323735
14	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 28, "section_index": null}	2025-11-10 20:55:02.857749
15	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 29, "section_index": null}	2025-11-10 21:09:51.762206
16	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 30, "section_index": null}	2025-11-10 21:49:24.814923
17	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 31, "section_index": null}	2025-11-10 22:10:21.42732
18	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 32, "section_index": null}	2025-11-10 22:20:24.864311
19	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 33, "section_index": null}	2025-11-10 22:54:31.012408
20	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 34, "section_index": null}	2025-11-11 11:59:21.48029
21	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 35, "section_index": null}	2025-11-11 11:59:36.970644
22	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 36, "section_index": null}	2025-11-11 12:13:12.195658
23	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 37, "section_index": null}	2025-11-11 12:24:05.818595
24	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 38, "section_index": null}	2025-11-11 12:40:47.272385
25	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 39, "section_index": null}	2025-11-11 13:00:29.419911
26	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 40, "section_index": null}	2025-11-11 13:27:28.494369
27	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 41, "section_index": null}	2025-11-11 13:38:19.656539
28	44	16	comment_added	Sipho Nkosi added a comment	{"comment_id": 42, "section_index": null}	2025-11-11 13:58:52.349361
29	47	13	comment_added	Unathi Sibanda added a comment	{"comment_id": 43, "section_index": null}	2025-11-13 10:10:59.334543
30	47	22	comment_added	Zukhanye Baloyi added a comment	{"comment_id": 44, "section_index": null}	2025-11-13 10:11:57.732396
31	68	15	signature_requested	Proposal sent to Dhlamini Corp for signature	{"envelope_id": "064b1637-daff-86bb-80f1-a01b32bf13ac", "signer_email": "sheziluthando513@gmail.com"}	2025-11-19 17:05:03.865793
32	67	15	comment_added	Added a comment	{"parent_id": 50, "comment_id": 51}	2025-11-21 18:02:06.950431
33	67	15	comment_resolved	Resolved comment #50	{"comment_id": 50}	2025-11-21 18:25:21.537818
34	67	15	comment_added	Added a comment	{"parent_id": 49, "comment_id": 52}	2025-11-21 18:26:21.937787
35	67	15	comment_resolved	Resolved comment #49	{"comment_id": 49}	2025-11-21 18:26:38.188076
36	67	15	comment_added	Added a comment	{"parent_id": 53, "comment_id": 54}	2025-11-22 17:16:51.288041
37	73	16	comment_added	Added a comment	{"parent_id": null, "comment_id": 56}	2025-11-26 16:55:05.254601
38	73	15	signature_requested	Proposal sent to Sibanda.ICT for signature	{"envelope_id": "64d31762-afd9-8dc1-80b8-7ff5a6bf1aac", "signer_email": "umsibanda.1994@gmail.com"}	2025-11-26 16:59:44.7951
39	74	15	signature_requested	Proposal sent to BrandBrands for signature	{"envelope_id": "e82b1d21-b33b-8057-8025-1ecc58b11b24", "signer_email": "umsibanda.1994@gmail.com"}	2025-11-27 15:31:34.20518
40	75	15	comment_added	Added a comment	{"parent_id": null, "comment_id": 57}	2025-11-27 16:06:26.2935
41	75	\N	signature_completed	Proposal signed via DocuSign (envelope: 47ad17fd-4181-884f-8055-0ac57ec10350)	{"envelope_id": "47ad17fd-4181-884f-8055-0ac57ec10350"}	2025-12-03 15:27:30.960733
42	78	\N	signature_completed	Proposal signed via DocuSign (envelope: f40b1847-2dab-8340-8051-9f9324c50338)	{"envelope_id": "f40b1847-2dab-8340-8051-9f9324c50338"}	2025-12-03 21:13:30.60043
43	77	\N	signature_completed	Proposal signed via DocuSign (envelope: dff41e77-8ede-80b2-813e-315127c603ad)	{"envelope_id": "dff41e77-8ede-80b2-813e-315127c603ad"}	2025-12-03 21:37:59.257741
44	79	\N	signature_completed	Proposal signed via DocuSign (envelope: 0b5f1865-49a8-85a5-8035-2561d6ce035c)	{"envelope_id": "0b5f1865-49a8-85a5-8035-2561d6ce035c"}	2025-12-04 09:31:21.452343
\.


--
-- Data for Name: ai_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ai_settings (id, openai_api_key, ai_analysis_enabled, risk_threshold, auto_analysis, created_at, updated_at) FROM stdin;
1	\N	t	50	f	2025-10-08 23:30:44.680422	2025-10-08 23:30:44.680422
\.


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.approvals (id, proposal_id, sow_id, approver_id, status, comments, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: client_dashboard_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.client_dashboard_tokens (id, token, client_id, proposal_id, expires_at, used_at, created_at) FROM stdin;
\.


--
-- Data for Name: client_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.client_notes (id, client_id, note_text, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: client_onboarding_invitations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.client_onboarding_invitations (id, access_token, invited_email, invited_by, expected_company, status, invited_at, completed_at, expires_at, client_id, email_verified_at, verification_code_hash, code_expires_at, verification_attempts, last_code_sent_at) FROM stdin;
1	xEjpz5doAq_fbOYAw2b6be1dMIo9PyQm2_veIIO8ggY	umsibanda.1994@gmail.com	65	Wiseman Tech	pending	2025-11-13 18:09:13.642727	\N	2025-11-20 18:09:13.642462	\N	\N	\N	\N	0	\N
2	bvQN2b4tRPBsomZin4lCJMjHLAxaoiDf_xJfkV-vNJ4	sheziluthando513@gmail.com	22	WisemanInc	pending	2025-11-13 20:42:27.834085	\N	2025-11-20 20:42:27.833821	\N	\N	\N	\N	0	\N
4	zyxb35-I2ngvv81dG-mgKo5_wf-sR_3BUqcPL59WCh0	sheziluthando513@gmail.com	15	SheziICT	pending	2025-11-14 17:32:23.398018	\N	2025-11-21 17:32:23.192953	\N	2025-11-18 17:30:00.506761	113aea89e31859a4e2a92cb1a9efdc422004661f78335b3db33ca7a03f3a1d32	2025-11-18 17:42:52.943223	0	2025-11-18 17:27:52.935955
\.


--
-- Data for Name: client_proposals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.client_proposals (id, client_id, proposal_id, relationship_type, linked_by, linked_at) FROM stdin;
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name, email, organization, role, token, is_active, created_at, updated_at, company_name, contact_person) FROM stdin;
\.


--
-- Data for Name: collaboration_invitations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.collaboration_invitations (id, proposal_id, invited_email, invited_by, access_token, permission_level, status, invited_at, accessed_at, expires_at, is_external) FROM stdin;
31	42	learner.hackathon@gmail.com	22	dQkmN4aAECbFW936dQ6zXqBFz_u2Vq8Ayo6vQm96NOQ	view	pending	2025-11-07 14:20:57.2333	\N	2026-02-05 14:20:57.23945	f
12	29	umsibanda.1994@gmail.com	22	gpBcrCrlJsW3nFdt98vBKJ0a5RQOldoFo-4qjKuqPGQ	comment	accepted	2025-10-27 13:28:15.849711	2025-10-27 13:29:08.285016	2025-11-26 13:28:15.851592	f
13	29	umsibanda.1994@gmail.com	22	KySMm6oKVub6PGDZFMbMaKbiunCjdH27I4DLcaVDR1Q	comment	accepted	2025-10-27 13:33:26.64195	2025-10-27 13:34:06.302537	2025-11-26 13:33:26.644083	f
14	28	sheziluthando513@gmail.com	22	jI604eKU3IYuaeKpwe8AWlVkfnkzlj9hIJiOSQD1X94	comment	accepted	2025-10-27 13:55:00.054781	2025-10-27 13:55:35.409632	2025-11-26 13:55:00.057177	f
15	31	umsibanda.1994@gmail.com	22	sU01a_9OyWU6h5pNxsMW8eOvvk6WsVQbotqaKs-bK1Y	comment	accepted	2025-10-27 15:53:30.95464	2025-10-27 16:10:26.67464	2025-11-26 15:53:30.956732	f
16	32	sheziluthando513@gmail.com	22	xhXvwp6Ad_tR3vlwhtWL_cKScLQgkFNxMLxtbog2lvg	comment	accepted	2025-10-27 16:49:27.794305	2025-10-27 16:50:35.842291	2025-11-26 16:49:27.796125	f
17	33	umsibanda.1994@gmail.com	22	8o_wpcPvOdBMY7O7cdcS-xMahpDFwWHMynZqNrh3l0Y	view	accepted	2025-10-28 14:39:07.941618	2025-10-28 14:39:55.465365	2026-01-26 14:39:07.947717	f
32	43	umsibanda.1994@gmail.com	22	85KeT0yV4HE4a7fBA5iknYtjMmKa7Ju653rK_AeKG_4	comment	accepted	2025-11-07 15:09:18.21282	2025-11-07 15:10:49.130598	2025-12-07 15:09:18.217469	f
33	43	learner.hackathon@gmail.com	22	o1xamiPdn3JFMmXEIhn_8HtuDQpsKIFvtmur5XQ1e0Q	view	pending	2025-11-07 15:14:18.920763	\N	2026-02-05 15:14:18.926929	f
21	34	hackathon.learner@gmail.com	22	vOhoXzzDlGGuPjdxgN8-uM6WbFOWTJNssHxaIdtMbvU	view	accepted	2025-10-28 18:23:07.243882	2025-10-28 18:23:41.743892	2026-01-26 18:23:07.250756	f
20	34	sheziluthando513@gmail.com	22	w9pRtt8NLx0tsr22NeEsXYChivQXoi8sb2KP4JBJgj8	suggest	accepted	2025-10-28 18:18:47.653991	2025-10-28 18:31:16.578597	2025-11-27 18:18:47.656969	f
22	35	umsibanda.1994@gmail.com	22	z3ngayPo1W2f-mxRW5Nmz434rVoBd-67YoXQOnIuAB8	view	accepted	2025-10-29 18:50:06.937267	2025-10-29 18:57:37.36326	2026-01-27 18:50:06.949241	f
23	36	umsibanda.1994@gmail.com	22	MBPTRbe8xvavf4CtbO0UHL0JfgO2LiI0zmaAyCb2UwY	view	pending	2025-10-30 12:10:46.106213	\N	2026-01-28 12:10:46.116839	f
34	41	umsibanda.1994@gmail.com	22	AajxUJTNUF3056IpA35WXXOW5Xw52Oqsy7xco6YXK9w	view	accepted	2025-11-09 20:36:37.37577	2025-11-09 20:37:43.119252	2026-02-07 20:36:37.384355	f
28	40	umsibanda.1994@gmail.com	22	RcmfFYI5QKeup8jrW4deKUNmx80Lgx5qDA67pKbEk8A	edit	pending	2025-11-07 13:59:36.776961	\N	2025-12-07 13:59:36.77862	f
30	42	umsibanda.1994@gmail.com	22	xYH30Zo7vi0UTEA0-YiLUcuqcc6upJJhskZxlT4QZgs	comment	accepted	2025-11-07 14:13:46.538182	2025-11-07 14:14:38.829204	2025-12-07 14:13:46.53979	f
35	40	umsibanda.1994@gmail.com	22	97kxH6pSgjdPZ0plOn8MhNtC5xHJSoK182IQPACBd80	view	accepted	2025-11-09 20:50:49.090826	2025-11-09 20:53:52.234733	2026-02-07 20:50:49.091978	f
36	45	umsibanda.1994@gmail.com	22	1m3Ysk5yzdNipb83PFPEVY9YrZM2RY97G0FKBaF4f8k	view	accepted	2025-11-09 21:07:37.087888	2025-11-09 21:08:09.802612	2026-02-07 21:07:37.089661	f
37	44	umsibanda.1994@gmail.com	22	6CuW8OoOXm-OYjcLT5jzKNflU1GBbOEmVBbSk_ZfX00	comment	pending	2025-11-10 15:42:35.600829	\N	2025-12-10 15:42:35.60905	f
39	44	sheziluthando513@gmail.com	22	VYBv5l0MnF92gw2JwpdwffHx690wQgnbFF707ndsswY	comment	accepted	2025-11-10 16:00:54.287938	2025-11-10 16:01:39.949171	2025-12-10 16:00:54.289894	f
40	44	umsibanda.1994@gmail.com	22	RStwEDzm8D5ztwCCEm25WdN4I120a7F4PRcLLFpy9bA	view	pending	2025-11-11 16:35:19.866641	\N	2026-02-09 16:35:19.867571	f
41	46	umsibanda.1994@gmail.com	22	8OG1U3vuNaxFQPNQwJxP9qpqbBKB89pVLAG2kkq9zak	view	pending	2025-11-12 22:18:37.549768	\N	2026-02-10 22:18:37.550662	f
42	47	umsibanda.1994@gmail.com	22	ppTgwrguTIdyG2vT-SbcgJ7xN9HemCRcIaF3puVwK3Q	comment	accepted	2025-11-13 10:09:04.849266	2025-11-13 10:09:50.16103	2025-12-13 10:09:04.850708	f
43	47	umsibanda.1994@gmail.com	22	N-kV6yvRWanwxN-4uwvG6koE3z0Uqg8-ha8SMPIRKlg	view	accepted	2025-11-13 10:17:41.700241	2025-11-13 10:19:01.287332	2026-02-11 10:17:41.701107	f
48	49	umsibanda.1994@gmail.com	15	ezpXVGrnh4K8yII8-FWodsdC9lYk4erlgeW5xN7h7H4	comment	accepted	2025-11-17 22:44:06.278087	2025-11-17 22:45:18.105797	2025-12-17 22:44:06.296329	f
49	49	umsibanda.1994@gmail.com	15	1lfW_jgzmLxUeguLySVhF8frHfCXBJ63kip4tOngikg	comment	pending	2025-11-17 23:46:45.84653	\N	2025-12-17 23:46:45.862179	f
51	64	sheziluthando513@gmail.com	16	8-fyF0aYS_0XHTmEr9KdDmMP9iV_q7tTJnpTlw1NN6c	view	pending	2025-11-19 15:10:24.439203	\N	\N	f
52	65	umsibanda.1994@gmail.com	16	9-Gd5WICYI2ayW_OFIqdqaCIddfxqy0DQHjest8rdIc	view	pending	2025-11-19 15:28:12.352425	\N	\N	f
54	66	sheziluthando513@gmail.com	16	5wmg9bhMjZvZWnhw1k0o87tC_0B9qqJYlMe2V19wI-E	view	pending	2025-11-19 16:44:31.939192	\N	\N	f
55	68	sheziluthando513@gmail.com	16	JDjDyEMi1seL32wQpQUAZ6IIhO_bvqdvKGKtjzaSb20	view	pending	2025-11-19 17:02:17.227084	\N	\N	f
73	73	umsibanda.1994@gmail.com	16	HPFGK3MBvMTZM-HwO7AQY5yBpyPBn4SSkzK0jrwz3_M	view	pending	2025-11-26 16:55:14.22374	\N	\N	f
74	74	umsibanda.1994@gmail.com	16	p6QiL4herzStbGRctqyWqAEu_-4GEHhrc4n7qO4EQSM	view	pending	2025-11-26 17:26:32.464892	\N	\N	f
75	75	sheziluthando513@gmail.com	15	pL4BhDbY2WMjofa_VszVHgzxcJ3o8ChtI_E7Cle4vKQ	edit	pending	2025-11-27 16:06:47.457659	\N	\N	f
66	67	umsibanda.1994@gmail.com	15	K-8g7r4TX2sJAq0B0qhHHWgPGEf6IRD2a628MisdXls	edit	active	2025-11-22 17:12:07.004121	2025-11-22 18:03:51.909813	\N	f
67	67	sheziluthando513@gmail.com	15	RYugmbQfE-00Bh0TMBzlQXV_S2Lk43lG9zgryJk2g_U	edit	active	2025-11-22 18:04:48.613821	2025-11-22 18:05:43.908488	\N	f
68	67	sheziluthando513@gmail.com	16	Bb0FnN3DTRtdPKvyPKg_uQAa8L2lnRmPhwPdpebUenU	view	pending	2025-11-25 12:13:51.051321	\N	\N	f
69	69	sheziluthando513@gmail.com	16	QEpzG_j29hvAcCPF27IUOlwphVlexSPSCPd4GQbnJ94	view	pending	2025-11-26 10:00:27.462272	\N	\N	f
70	70	umsibanda.1994@gmail.com	16	DrikwcNTstIM6xDmXGJEX8ScvN8Op_64q21akL_jGDg	view	pending	2025-11-26 10:15:00.259466	\N	\N	f
71	71	sheziluthando513@gmail.com	16	jSbcuVlxYW7-Bu_cj0qvDdG0GiyRMCycKZh_7jV5BZs	view	pending	2025-11-26 10:35:13.321855	\N	\N	f
72	72	umsibanda.1994@gmail.com	16	VcjchdMXdCus6Kvshuy1CcdBdaa4Ht4D8CRd6rPtGZk	view	pending	2025-11-26 16:00:17.646935	\N	\N	f
76	76	umsibanda.1994@gmail.com	16	dds8PYKy5KcbGD6HpKM7YU008CPELlsQwmjoyrPfiNk	view	pending	2025-12-01 14:29:30.046876	\N	\N	f
77	75	sibandanobunzima@gmail.com	16	lCdS1Jf2qLl6W8ZqzzhognmUzdm8J4rBgUZLPYgTpig	view	pending	2025-12-03 15:14:59.043884	\N	\N	f
78	77	sibandanobunzima@gmail.com	16	sDzLYkOqwEQca-gp7198YcQiAieEkc1roSxODRf0BTo	view	pending	2025-12-03 20:14:33.370924	\N	\N	f
79	78	umsibanda.1994@gmail.com	16	mrMgmdHgH5ABy4adE7iShkQazNLGmseavKGYRSZ_sqM	view	pending	2025-12-03 21:11:42.682154	\N	\N	f
80	79	sibandanobunzima@gmail.com	16	Jz1EiLE9byyAURMwNWBBGnQ-Ub38qo_KAkz_RdxnIEQ	view	pending	2025-12-04 09:29:26.480663	\N	\N	f
\.


--
-- Data for Name: collaborators; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.collaborators (id, proposal_id, email, user_id, invited_by, permission_level, status, joined_at, last_accessed_at) FROM stdin;
1	67	umsibanda.1994@gmail.com	\N	15	edit	active	2025-11-22 17:12:59.094811	2025-11-22 18:03:51.909813
5	67	sheziluthando513@gmail.com	\N	15	edit	active	2025-11-22 18:05:43.908488	2025-11-22 18:05:43.908488
\.


--
-- Data for Name: comment_mentions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.comment_mentions (id, comment_id, mentioned_user_id, mentioned_by_user_id, created_at, is_read) FROM stdin;
1	27	22	16	2025-11-10 20:34:54.613713	f
2	28	22	16	2025-11-10 20:55:03.029582	f
3	29	22	16	2025-11-10 21:09:51.958734	f
4	30	22	16	2025-11-10 21:49:25.010433	f
5	31	22	16	2025-11-10 22:10:21.64577	f
6	32	22	16	2025-11-10 22:20:25.067506	f
7	33	22	16	2025-11-10 22:54:31.309185	f
8	34	13	16	2025-11-11 11:59:21.748854	f
9	35	22	16	2025-11-11 11:59:37.227333	f
10	36	22	16	2025-11-11 12:13:12.429819	f
11	37	22	16	2025-11-11 12:24:06.030682	f
12	38	22	16	2025-11-11 12:40:47.527153	f
13	39	22	16	2025-11-11 13:00:29.748368	f
14	40	22	16	2025-11-11 13:27:28.744383	f
15	41	22	16	2025-11-11 13:38:23.587603	f
16	42	22	16	2025-11-11 13:58:56.977935	f
17	43	22	13	2025-11-13 10:11:02.860063	f
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.comments (id, content, author_id, resource_type, resource_id, parent_id, created_at, updated_at, is_edited, is_deleted, mentions) FROM stdin;
\.


--
-- Data for Name: content; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.content (id, key, label, content, category, is_folder, parent_id, public_id, created_at, updated_at, is_deleted) FROM stdin;
9	abstract_red_circular	Abstract Red Circular Pattern	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760890158/proposal_builder/images/wcbprrnpmyg2phe4wtio.png	Images	f	\N	proposal_builder/images/wcbprrnpmyg2phe4wtio	2025-10-23 14:03:07.810237	2025-10-23 14:03:07.810282	f
10	background_image_2	Background Image 2	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png	Images	f	\N	proposal_builder/images/qboeusv10uhgozkcbbkc	2025-10-23 14:03:07.8173	2025-10-23 14:03:07.817304	f
11	background_image_3	Background Image 3	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg	Images	f	\N	proposal_builder/images/dcizyxk2xie2bhzoyail	2025-10-23 14:03:07.818482	2025-10-23 14:03:07.818485	f
6	texture_pattern_1	Texture Pattern 1	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/food/spices.jpg	Images	f	\N	texture_pattern_1	2025-10-23 13:07:00.888906	2025-10-23 13:07:00.888908	t
5	city_skyline	City Skyline	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/girl-urban-view.jpg	Images	f	\N	city_skyline	2025-10-23 13:07:00.887971	2025-10-23 13:07:00.887973	t
4	modern_workspace	Modern Workspace	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/beach-boat.jpg	Images	f	\N	modern_workspace	2025-10-23 13:07:00.887196	2025-10-23 13:07:00.887198	t
3	business_meeting	Business Meeting	https://res.cloudinary.com/demo/image/upload/v1652366604/samples/people/kitchen-bar.jpg	Images	f	\N	business_meeting	2025-10-23 13:07:00.886346	2025-10-23 13:07:00.886348	t
2	professional_office	Professional Office	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/architecture-signs.jpg	Images	f	\N	professional_office	2025-10-23 13:07:00.885397	2025-10-23 13:07:00.885401	t
1	abstract_blue_bg	Abstract Blue Background	https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg	Images	f	\N	abstract_blue_bg	2025-10-23 13:07:00.870902	2025-10-23 13:07:00.870938	t
7	corporate_background	Corporate Background	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg	Images	f	\N	corporate_background	2025-10-23 13:07:00.889754	2025-10-23 13:07:00.889756	t
8	minimal_gradient	Minimal Gradient	https://res.cloudinary.com/demo/image/upload/v1652345874/samples/bike.jpg	Images	f	\N	minimal_gradient	2025-10-23 13:07:00.890597	2025-10-23 13:07:00.890599	t
111	template_proposal_module_7_delivery_approach	Proposal Template - Module 7: Delivery Approach	<!-- tags: ["template", "proposal", "delivery", "approach", "module"] -->\n<h1>Delivery Approach</h1>\n<p>Khonology follows a structured delivery methodology combining Agile, Lean, and governance best practices.</p>\n\n<h2>Key Features</h2>\n<ul>\n    <li>Iterative sprint cycles</li>\n    <li>Frequent stakeholder engagement</li>\n    <li>Automated governance checkpoints</li>\n    <li>Traceability from requirements → delivery → reporting</li>\n</ul>	Templates	f	\N	\N	2025-11-17 20:47:02.848181	2025-12-07 17:15:10.044863	f
114	template_proposal_module_10_governance_model	Proposal Template - Module 10: Governance Model	<!-- tags: ["template", "proposal", "governance", "model", "module"] -->\n<h1>Governance Model</h1>\n\n<h2>Governance Structure</h2>\n<ul>\n    <li>Engagement Lead</li>\n    <li>Product Owner (Client)</li>\n    <li>Delivery Team</li>\n    <li>QA & Compliance Group</li>\n</ul>\n\n<h2>Tools</h2>\n<ul>\n    <li>Jira</li>\n    <li>Teams/Email</li>\n    <li>Automated reporting dashboard</li>\n</ul>\n\n<h2>Cadence</h2>\n<ul>\n    <li>Daily standups</li>\n    <li>Weekly status updates</li>\n    <li>Monthly executive review</li>\n</ul>	Templates	f	\N	\N	2025-11-17 20:47:02.852028	2025-12-07 17:15:10.048464	f
115	template_proposal_module_11_company_profile	Proposal Template - Module 11: Company Profile	<!-- tags: ["template", "proposal", "company", "profile", "module"] -->\n<h1>Appendix – Company Profile</h1>\n\n<h2>About Khonology</h2>\n<p>Khonology is a South African-based digital consulting and technology delivery company specialising in:</p>\n<ul>\n    <li>Enterprise automation</li>\n    <li>Digital transformation</li>\n    <li>ESG reporting</li>\n    <li>Data engineering & cloud</li>\n    <li>Business analysis and enterprise delivery</li>\n</ul>\n\n<p>We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.</p>	Templates	f	\N	\N	2025-11-17 20:47:02.85345	2025-12-07 17:15:10.049659	f
15	company_profile_khonology_background	Khonology Company Background	<!-- tags: ["company", "profile", "background", "khonology"] -->\n<h1>Our Purpose</h1>\n<p>Khonology is a B-BBEE Level 2 South African digital services company. Khonology is a true African success story and has been the recipient of several awards. We provide world-class business solutions with the vision of empowering Africa. <br><br>\nKhonology is who we are, technology is what we do, and Africa is whom we serve.</p>\n<h2>Our Services</h2>\n<p>Our service offering is focused on end-to-end application development, application support, testing, and strong data competency (data engineering and data analytics). Our vision is to become Africa's leading digital enabler. <br><br>\nKhonology aspires to continue to rise into Africa’s leading data and digital enabler that empowers our continent’s businesses and people to unlock their full potential through technology.</p>\n<h2>Recent Clients</h2>\n<ul>\n    <li>InfoCare</li>\n    <li>Standard Bank</li>\n    <li>Rand Merchant Bank</li>\n    <li>Auditor General of South Africa</li>\n    <li>SA Taxi Finance Company</li>\n    <li>NatWest Bank (UK)</li>\n    <li>ADB Safegate (Belgium)</li>\n</ul>\n<h2>Awards &amp; Recognition</h2>\n<ul>\n    <li>2023 TopCo Award for Best Fintech Company</li>\n    <li>2023 Top Empowerment Digital Transformation Award of the Year</li>\n    <li>2022 DataMagazine.UK Top 44 Most Innovative Cloud Data Services Start-ups &amp; Companies in South Africa</li>\n    <li>2022 DataMagazine.UK Top 14 Most Innovative Cloud Data Services Start-ups &amp; Companies in Johannesburg</li>\n    <li>2022/23 Prestige Awards: Digital Services Company of the Year</li>\n</ul>\n<h2>Digital Products Delivered</h2>\n<h3>PowerPulse</h3>\n<p>A digital platform connecting accredited energy solution providers to deliver cost-saving and sustainable energy solutions for businesses and homes.</p>\n<h3>CreditConnect</h3>\n<p>A digital bond market platform offering institutional investors and issuers an intelligent, transparent, and efficient trading experience.</p>\n<h3>Automated Term Sheet</h3>\n<p>A digital term sheet generation platform enabling RMB to standardise loan terms, accelerate deal processing, and reduce human error.</p>	Company Profile	f	\N	\N	2025-11-14 13:15:14.197267	2025-12-07 17:15:10.015703	f
106	template_proposal_module_2_executive_summary	Proposal Template - Module 2: Executive Summary	<!-- tags: ["template", "proposal", "executive", "summary", "module"] -->\n<h1>Executive Summary</h1>\n<h2>Purpose of This Proposal</h2>\n<p>This proposal outlines Khonology's recommended approach, delivery methodology, timelines, governance, and expected outcomes for the {{Project Name}} initiative.</p>\n\n<h2>What We Bring</h2>\n<ul>\n    <li>Strong expertise in digital transformation and enterprise delivery</li>\n    <li>Deep experience in banking, insurance, ESG reporting, and financial services</li>\n    <li>Proven capability across data engineering, cloud, automation, and governance</li>\n    <li>A people-first consulting culture focused on delivery excellence</li>\n</ul>\n\n<h2>Expected Outcomes</h2>\n<ul>\n    <li>Streamlined processes</li>\n    <li>Robust governance</li>\n    <li>Improved operational visibility</li>\n    <li>Higher efficiency and reduced risk</li>\n    <li>A scalable delivery architecture to support strategic goals</li>\n</ul>	Templates	f	\N	\N	2025-11-17 20:47:02.840256	2025-12-07 17:15:10.036691	f
107	template_proposal_module_3_problem_statement	Proposal Template - Module 3: Problem Statement	<!-- tags: ["template", "proposal", "problem", "statement", "module"] -->\n<h1>Problem Statement</h1>\n<h2>Current State Challenges</h2>\n<p>{{Client Name}} is experiencing the following challenges:</p>\n<ul>\n    <li>Limited visibility into operational performance</li>\n    <li>Manual processes creating inefficiencies</li>\n    <li>High reporting complexity</li>\n    <li>Lack of integrated workflows or automated governance</li>\n    <li>Upcoming deadlines causing pressure on compliance and reporting</li>\n</ul>\n\n<h2>Opportunity</h2>\n<p>With a modern delivery framework, workflows, and reporting structures, {{Client Name}} can unlock operational excellence and achieve strategic growth objectives.</p>	Templates	f	\N	\N	2025-11-17 20:47:02.842162	2025-12-07 17:15:10.039804	f
110	template_proposal_module_6_team_bios	Proposal Template - Module 6: Team & Bios	<!-- tags: ["template", "proposal", "team", "bios", "module"] -->\n<h1>Team & Bios</h1>\n\n<h2>Engagement Lead – {{Name}}</h2>\n<p>Responsible for oversight, governance, and stakeholder engagement.</p>\n\n<h2>Technical Lead – {{Name}}</h2>\n<p>Owns architecture, technical design, integration, and delivery.</p>\n\n<h2>Business Analyst – {{Name}}</h2>\n<p>Facilitates workshops, documents requirements, and translations.</p>\n\n<h2>QA/Test Analyst – {{Name}}</h2>\n<p>Ensures solution quality and manages UAT cycles.</p>	Templates	f	\N	\N	2025-11-17 20:47:02.846888	2025-12-07 17:15:10.043653	f
16	team_khonology_leadership_bios	Khonology Leadership Team	<!-- tags: ["team", "bios", "leadership", "khonology"] -->\n<h1>Organisational Structure</h1>\n<h2>Leadership</h2>\n<h3>Dapo Adeyemo – CEO – Co-founder</h3>\n<p>Dapo leads the strategic direction of Khonology and oversees company vision and growth.</p>\n<h3>Mosa Nyamande – Head of Delivery – Co-founder</h3>\n<p>Mosa drives delivery excellence, project execution, and operational transformation across engagements.</p>\n<h3>Africa Nkosi – Sales &amp; Marketing – Co-founder</h3>\n<p>Africa leads business development, client engagement, and market positioning initiatives.</p>\n<h3>Michael Roberts – Chairman – Co-founder</h3>\n<p>Michael provides governance oversight, strategic leadership, and senior advisory guidance.</p>\n<h2>Management Team</h2>\n<h3>Lezanne Kruger – Finance Manager</h3>\n<p>Responsible for financial operations, accounting, and commercial management.</p>\n<h3>Lerato Thekiso – Legal Partner</h3>\n<p>Supports Khonology's legal compliance, contract frameworks, and governance operations.</p>	Team	f	\N	\N	2025-11-14 13:15:14.219781	2025-12-07 17:15:10.018284	f
17	case_study_powerpulse	Case Study: PowerPulse Energy Platform	<!-- tags: ["case", "energy", "marketplace", "powerpulse"] -->\n<h1>Digital Energy Marketplace Transformation</h1>\n<p>Khonology played a critical role in the modernisation of PowerPulse, a digital marketplace enabling customers to access accredited energy solution providers.</p>\n<h2>What We Delivered</h2>\n<ul>\n    <li>Digital workflow automation</li>\n    <li>Supplier onboarding &amp; governance</li>\n    <li>Client energy assessment journeys</li>\n    <li>Performance dashboards &amp; analytics</li>\n</ul>\n<h2>Impact</h2>\n<ul>\n    <li>Accelerated go-live by 42%</li>\n    <li>Reduced operational bottlenecks</li>\n    <li>Improved customer energy cost decisioning</li>\n</ul>	Case Studies	f	\N	\N	2025-11-14 13:15:14.221414	2025-12-07 17:15:10.019641	f
18	case_study_creditconnect	Case Study: CreditConnect Bond Trading Platform	<!-- tags: ["case", "finance", "creditconnect", "trading"] -->\n<h1>Institutional Bond Trading Modernisation</h1>\n<p>Khonology delivered CreditConnect, a digital trading interface for institutional investors and issuers seeking improved transparency in bond markets.</p>\n<h2>Core Features Developed</h2>\n<ul>\n    <li>Real-time credit pricing</li>\n    <li>Deal room negotiation workflows</li>\n    <li>Automated issuance orchestration</li>\n</ul>\n<h2>Impact</h2>\n<ul>\n    <li>Shortened deal cycle times</li>\n    <li>Improved liquidity insights</li>\n    <li>Digitised historically manual bond processes</li>\n</ul>	Case Studies	f	\N	\N	2025-11-14 13:15:14.222479	2025-12-07 17:15:10.021041	f
112	template_proposal_module_8_pricing_table	Proposal Template - Module 8: Pricing Table	<!-- tags: ["template", "proposal", "pricing", "table", "module"] -->\n<h1>Pricing Table</h1>\n<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">\n    <thead>\n        <tr style="background: #f5f5f5;">\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Service Component</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Quantity</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Rate</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Total</th>\n        </tr>\n    </thead>\n    <tbody>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Assessment & Discovery</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">2 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Build & Configuration</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">4 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">UAT & Release</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">2 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Training & Handover</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Rate}}</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">R {{Total}}</td>\n        </tr>\n    </tbody>\n</table>\n<blockquote style="background: #f9f9f9; border-left: 4px solid #E9293A; padding: 15px; margin: 20px 0;">\n    <p><strong>Total Estimated Cost:</strong> R {{Total}}</p>\n    <p style="margin: 5px 0 0 0; font-size: 14px; color: #666;"><em>Final costs will be confirmed after detailed scoping.</em></p>\n</blockquote>	Templates	f	\N	\N	2025-11-17 20:47:02.849359	2025-12-07 17:15:10.045978	f
113	template_proposal_module_9_risks_mitigation	Proposal Template - Module 9: Risks & Mitigation	<!-- tags: ["template", "proposal", "risks", "mitigation", "module"] -->\n<h1>Risks & Mitigation</h1>\n<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">\n    <thead>\n        <tr style="background: #f5f5f5;">\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Risk</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Impact</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Likelihood</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Mitigation</th>\n        </tr>\n    </thead>\n    <tbody>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Limited stakeholder availability</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">High</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Align early calendars</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Data quality issues</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">High</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">High</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Early validation</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Changing scope</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Governance checkpoints</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;">Lack of documentation</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Medium</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">High</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Early analysis and mapping</td>\n        </tr>\n    </tbody>\n</table>	Templates	f	\N	\N	2025-11-17 20:47:02.850742	2025-12-07 17:15:10.047183	f
21	methodology_build	Build & Implementation	<!-- tags: ["delivery", "build", "methodology"] -->\n<h1>Build &amp; Implementation</h1>\n<p>Khonology delivers solutions using Agile, ensuring rapid iterations, continuous feedback, and predictable delivery timelines.</p>\n<h2>Activities</h2>\n<ul>\n    <li>Architecture and design</li>\n    <li>Development and integration</li>\n    <li>Data migration and enrichment</li>\n    <li>User acceptance testing preparation</li>\n</ul>	Methodology	f	\N	\N	2025-11-14 13:15:14.226445	2025-12-07 17:15:10.025555	f
19	case_study_term_sheet_rmb	Case Study: Automated Term Sheet (RMB)	<!-- tags: ["case", "rmb", "loans", "automation"] -->\n<h1>Loan Term Sheet Automation</h1>\n<p>Working with Rand Merchant Bank (RMB), Khonology created an automated term sheet generator that standardised lending structures.</p>\n<h2>Outcome</h2>\n<ul>\n    <li>Accelerated deal generation speed</li>\n    <li>Reduced legal review rework</li>\n    <li>Decreased human error in loan terms</li>\n</ul>	Case Studies	f	\N	\N	2025-11-14 13:15:14.223604	2025-12-07 17:15:10.022334	f
20	methodology_discovery	Discovery & Requirements	<!-- tags: ["methodology", "discovery", "analysis"] -->\n<h1>Discovery &amp; Requirements</h1>\n<p>In the Discovery phase, Khonology engages with stakeholders to validate objectives, define success metrics, and understand current-state challenges.</p>\n<h2>Activities</h2>\n<ul>\n    <li>Stakeholder interviews</li>\n    <li>Process mapping</li>\n    <li>Requirements documentation</li>\n    <li>Solution feasibility analysis</li>\n</ul>	Methodology	f	\N	\N	2025-11-14 13:15:14.225031	2025-12-07 17:15:10.024077	f
22	methodology_quality	Quality Assurance	<!-- tags: ["qa", "testing", "quality"] -->\n<h1>Quality Assurance</h1>\n<p>Khonology applies rigorous quality standards to ensure solutions meet functional and non-functional requirements.</p>\n<h2>Testing Coverage</h2>\n<ul>\n    <li>Functional testing</li>\n    <li>Performance validation</li>\n    <li>Integration testing</li>\n    <li>User acceptance testing (UAT)</li>\n</ul>	Methodology	f	\N	\N	2025-11-14 13:15:14.227709	2025-12-07 17:15:10.026772	f
23	methodology_golive	Go-Live & Support	<!-- tags: ["golive", "support", "methodology"] -->\n<h1>Go-Live &amp; Support</h1>\n<p>Khonology ensures a smooth production rollout supported by hypercare and operational enablement.</p>\n<h2>Includes</h2>\n<ul>\n    <li>Release management</li>\n    <li>Post-deployment support</li>\n    <li>Knowledge transfer</li>\n    <li>Operational handover</li>\n</ul>	Methodology	f	\N	\N	2025-11-14 13:15:14.228985	2025-12-07 17:15:10.027903	f
24	template_proposal_cover	Proposal Cover	<!-- tags: ["template", "proposal", "cover"] -->\n<div style="padding:40px; text-align:center;">\n    <h1 style="font-size:40px; font-weight:700;">Khonology Proposal</h1>\n    <p style="font-size:18px;">Empowering Africa through Technology</p>\n    <div style="margin-top:50px;">\n        <p><strong>Client:</strong> {{client_name}}</p>\n        <p><strong>Date:</strong> {{date}}</p>\n        <p><strong>Prepared By:</strong> Khonology</p>\n    </div>\n</div>	Templates	f	\N	\N	2025-11-14 13:15:14.230821	2025-12-07 17:15:10.029003	f
25	template_sow_header	SOW Header	<!-- tags: ["template", "sow", "header"] -->\n<h1>Statement of Work</h1>\n<p>This Statement of Work outlines the scope, deliverables, responsibilities, and timelines for the engagement between Khonology and {{client_name}}.</p>	Templates	f	\N	\N	2025-11-14 13:15:14.232596	2025-12-07 17:15:10.03014	f
26	template_rfi_header	RFI Response Header	<!-- tags: ["template", "rfi", "header"] -->\n<h1>RFI Response</h1>\n<p>Khonology appreciates the opportunity to respond to your Request for Information. This document provides a structured overview of our capabilities, experience, and delivery approach.</p>	Templates	f	\N	\N	2025-11-14 13:15:14.233835	2025-12-07 17:15:10.031205	f
27	assumptions_standard	Standard Project Assumptions	<!-- tags: ["assumptions", "project", "standards"] -->\n<h1>Project Assumptions</h1>\n<ul>\n    <li>Client resources will be available as needed.</li>\n    <li>All milestones are dependent on timely client feedback.</li>\n    <li>Dependencies on external vendors are managed by the client.</li>\n    <li>Scope changes may impact timelines and commercial estimates.</li>\n</ul>	Assumptions	f	\N	\N	2025-11-14 13:15:14.234858	2025-12-07 17:15:10.032404	f
28	risks_standard	Standard Delivery Risks	<!-- tags: ["risks", "delivery", "project"] -->\n<h1>Project Risks</h1>\n<ul>\n    <li>Delays in decision-making may impact timelines.</li>\n    <li>Third-party dependency failures can cause bottlenecks.</li>\n    <li>Scope ambiguity increases rework risk.</li>\n    <li>Insufficient user adoption may affect long-term value.</li>\n</ul>	Risks	f	\N	\N	2025-11-14 13:15:14.23615	2025-12-07 17:15:10.033438	f
29	pricing_commercial_terms	Commercial Terms	<!-- tags: ["pricing", "commercial", "terms"] -->\n<h1>Commercial Terms</h1>\n<ul>\n    <li>Rates exclude VAT unless otherwise stated.</li>\n    <li>Travel is charged at cost if required.</li>\n    <li>Invoices are payable within 30 days.</li>\n    <li>Changes to scope may result in revised costing.</li>\n</ul>	Pricing	f	\N	\N	2025-11-14 13:15:14.237071	2025-12-07 17:15:10.034416	f
105	template_proposal_module_1_cover	Proposal Template - Module 1: Cover Page	<!-- tags: ["template", "proposal", "cover", "module"] -->\n<h1>Consulting & Technology Delivery Proposal</h1>\n<div style="margin: 30px 0;">\n    <p><strong>Client:</strong> {{Client Name}}</p>\n    <p><strong>Prepared For:</strong> {{Client Stakeholder}}</p>\n    <p><strong>Prepared By:</strong> Khonology Team</p>\n    <p><strong>Date:</strong> {{Date}}</p>\n</div>\n<div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">\n    <h2>Cover Summary</h2>\n    <p>Khonology proposes a customised consulting and technology delivery engagement to support {{Client Name}} in achieving operational excellence, digital transformation, and data-driven decision-making.</p>\n</div>	Templates	f	\N	\N	2025-11-17 20:47:02.836306	2025-12-07 17:15:10.03561	f
108	template_proposal_module_4_scope_of_work	Proposal Template - Module 4: Scope of Work	<!-- tags: ["template", "proposal", "scope", "work", "module"] -->\n<h1>Scope of Work</h1>\n<p>Khonology proposes the following Scope of Work:</p>\n\n<h2>1. Discovery & Assessment</h2>\n<ul>\n    <li>Requirements gathering</li>\n    <li>Stakeholder workshops</li>\n    <li>Current-state assessment</li>\n</ul>\n\n<h2>2. Solution Design</h2>\n<ul>\n    <li>Technical architecture</li>\n    <li>Workflow design</li>\n    <li>Data models and integration approach</li>\n</ul>\n\n<h2>3. Build & Configuration</h2>\n<ul>\n    <li>Product configuration</li>\n    <li>UI/UX setup</li>\n    <li>Data pipeline setup</li>\n    <li>Reporting components</li>\n</ul>\n\n<h2>4. Implementation & Testing</h2>\n<ul>\n    <li>UAT support</li>\n    <li>QA testing</li>\n    <li>Release preparation</li>\n</ul>\n\n<h2>5. Training & Knowledge Transfer</h2>\n<ul>\n    <li>System training</li>\n    <li>Documentation handover</li>\n</ul>	Templates	f	\N	\N	2025-11-17 20:47:02.843369	2025-12-07 17:15:10.041302	f
109	template_proposal_module_5_project_timeline	Proposal Template - Module 5: Project Timeline	<!-- tags: ["template", "proposal", "timeline", "project", "module"] -->\n<h1>Project Timeline</h1>\n<table style="width: 100%; border-collapse: collapse; margin: 20px 0;">\n    <thead>\n        <tr style="background: #f5f5f5;">\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Phase</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Duration</th>\n            <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">Description</th>\n        </tr>\n    </thead>\n    <tbody>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Discovery</strong></td>\n            <td style="padding: 12px; border: 1px solid #ddd;">1–2 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Requirements & assessment</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Design</strong></td>\n            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Architecture & workflow design</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Build</strong></td>\n            <td style="padding: 12px; border: 1px solid #ddd;">2–4 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Development & configuration</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;"><strong>UAT</strong></td>\n            <td style="padding: 12px; border: 1px solid #ddd;">1–2 Weeks</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Testing & validation</td>\n        </tr>\n        <tr>\n            <td style="padding: 12px; border: 1px solid #ddd;"><strong>Go-Live</strong></td>\n            <td style="padding: 12px; border: 1px solid #ddd;">1 Week</td>\n            <td style="padding: 12px; border: 1px solid #ddd;">Deployment & full handover</td>\n        </tr>\n    </tbody>\n</table>	Templates	f	\N	\N	2025-11-17 20:47:02.845498	2025-12-07 17:15:10.042534	f
\.


--
-- Data for Name: content_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.content_blocks (id, key, label, content, is_folder, parent_id, created_at, updated_at, category, public_id) FROM stdin;
34	khono_image	Khono Image		t	\N	2025-10-17 19:01:01.369767	2025-10-17 19:01:01.369767	Images	\N
37	nathi_design_1	Nathi_design_1.png	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760886157/proposal_builder/images/bvanlnubwbmizmfq5hsx.png	f	\N	2025-10-19 17:02:37.918864	2025-10-19 17:02:37.918864	Images	proposal_builder/images/bvanlnubwbmizmfq5hsx
38	logo	logo.png	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760886211/proposal_builder/images/ditrfwfrshryr6sydmuv.png	f	\N	2025-10-19 17:03:32.233709	2025-10-19 17:03:32.233709	Images	proposal_builder/images/ditrfwfrshryr6sydmuv
39	khono	khono.png	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760887564/proposal_builder/images/ethf4omu3gryjqinjlud.png	f	\N	2025-10-19 17:26:05.288094	2025-10-19 17:26:05.288094	Images	proposal_builder/images/ethf4omu3gryjqinjlud
41	nathi_design_3	Nathi_design_3.png	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760890158/proposal_builder/images/wcbprrnpmyg2phe4wtio.png	f	34	2025-10-19 18:09:19.373986	2025-10-19 18:09:19.373986	Images	proposal_builder/images/wcbprrnpmyg2phe4wtio
42	wallpaper_	Wallpaper .pdf	https://res.cloudinary.com/dhy0jccgg/image/upload/v1760891047/proposal_builder/images/nejogarlilm8e77c3uaq.pdf	f	\N	2025-10-19 18:24:08.036506	2025-10-19 18:24:08.036506	Sections	proposal_builder/images/nejogarlilm8e77c3uaq
43	team_bio	Team Bio.docx	https://res.cloudinary.com/dhy0jccgg/raw/upload/v1760957416/proposal_builder/templates/r6gre2tnh1sveujvqmyh.tmp	f	\N	2025-10-20 12:50:17.740848	2025-10-20 12:50:17.740848	Sections	proposal_builder/templates/r6gre2tnh1sveujvqmyh.tmp
44	organizational_structure	Organizational_Structure.docx	https://res.cloudinary.com/dhy0jccgg/raw/upload/v1760958014/proposal_builder/templates/k96yqws1ndckezictsvi.tmp	f	\N	2025-10-20 13:00:16.193019	2025-10-20 13:00:16.193019	Sections	proposal_builder/templates/k96yqws1ndckezictsvi.tmp
45	company_background	Company background.docx	https://res.cloudinary.com/dhy0jccgg/raw/upload/v1760958025/proposal_builder/templates/yhx4gj70lfxt9elqlifp.tmp	f	\N	2025-10-20 13:00:26.412828	2025-10-20 13:00:26.412828	Sections	proposal_builder/templates/yhx4gj70lfxt9elqlifp.tmp
\.


--
-- Data for Name: content_library; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.content_library (id, user_id, title, content, category, tags, is_template, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: content_modules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.content_modules (id, title, category, body, version, created_by, created_at, updated_at, is_editable) FROM stdin;
d4b78b2f-8cf3-4ab0-8bb5-3ca9355ee856	Khonology Company Profile	Company Profile	Khonology is a digital-services company founded in 2013, a B-BBEE Level 2 provider. Our vision is to Digitise Africa by providing end-to-end digital solutions: application development, data engineering, AI, regulatory reporting, and workflow automation. We focus on transforming client experience through data-led insights and systemised delivery frameworks.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	f
4220821d-9e16-4c54-ac28-0786e732e9ae	Vision & Mission Statement	Company Profile	Vision: Digitise Africa. We believe in unlocking value through digital transformation, enabling agility and insight in decision-making. Mission: deliver data-driven, scalable, and human-centred digital solutions.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	f
55ca7c6c-d796-4be6-bcd6-3e5aea2c7623	Leadership Team Bio: Dapo Adeyemo (CEO)	Team Bio	Dapo Adeyemo is Co-founder and CEO of Khonology. With a strong background in business leadership and technology strategy, he leads vision and strategic partnerships, overseeing client delivery and innovation.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	t
0bdee407-2ef8-4853-a479-f469714f558b	Leadership Team Bio: Africa Nkosi (Head of Sales & Marketing)	Team Bio	Africa Nkosi co-founded Khonology and leads Sales & Marketing. Her expertise is in business growth, go-to-market strategies, and client relations, ensuring Khonologys solutions are market-fit.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	t
df710a8c-fbff-4765-b348-d5daa044f8a1	Standard Khonology Terms & Conditions	Legal / Terms	These terms outline Khonologys standard conditions for digital services, covering scope, payment, confidentiality, and liability. All proposals are subject to these terms unless otherwise negotiated.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	f
55e314cd-b725-456d-8fbe-2c633b2eb9ba	Delivery Framework	Proposal Module	Our Delivery Framework follows Agile + Design Thinking. We begin with discovery, followed by rapid prototyping, iterative development, quality assurance, and client validation. Data engineering and system architecture underpin all delivery. Regulatory and compliance checks are embedded throughout.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	f
96998d89-4943-4e1a-8321-4285131a575e	Services Offering	Services	We offer application development, data engineering, AI/ML, automation of business processes, product strategy, regulatory reporting, and consulting. Our strength lies in integrating data, usability, and robust infrastructure to support scalable solutions.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	t
016af4f9-fd64-47ca-8686-007e1a4e003f	Case Study: Automation of Regulatory Reporting	Case Study	Client problem: manual regulatory reporting was error-prone and slow. Solution: Khonology automated data pipelines, implemented validation rules, and streamlined report generation. Result: reduced errors by XX%, decreased time from data submission to approval by YY%.	1	\N	2025-09-22 15:37:50.508315	2025-09-22 15:37:50.508315	t
1ec4e55c-4457-4595-9252-1eed325c60fc	Khonology Company Profile	company_profile	Khonology is a digital-services company founded in 2013, a B-BBEE Level 2 provider. Our vision is to ‘Digitise Africa’ by providing end-to-end digital solutions: application development, data engineering, AI, regulatory reporting, automation of workflows. We focus on transforming client experience through data-led insights and systemised delivery frameworks.	1	\N	2025-09-23 12:24:28.139979	2025-09-23 12:24:28.139987	f
bb439a2e-d292-4603-8103-946660f20758	Leadership Team Bio: Dapo Adeyemo (CEO)	bio	Dapo Adeyemo is Co-founder and CEO of Khonology. With a strong background in leadership and partnerships, he leads vision and strategic growth, overseeing client delivery and innovation.	1	\N	2025-09-23 12:24:28.225166	2025-09-23 12:24:28.225172	t
95d54d78-234e-4134-a284-53f7cf074060	Standard Khonology Terms & Conditions	terms	These terms outline Khonology’s standard conditions for digital services, covering scope, payment, confidentiality, IP, and liability. All proposals are subject to these terms unless otherwise negotiated.	1	\N	2025-09-23 12:24:28.25958	2025-09-23 12:24:28.259587	f
8fa3f00b-3ba4-4a81-b2fd-632a85809053	Delivery Framework	template	Our Delivery Framework blends Agile and Design Thinking: discovery → rapid prototyping → iterative development → QA → client validation. Data engineering and architecture underpin delivery; regulatory and compliance checks are embedded throughout.	1	\N	2025-09-23 12:24:28.29219	2025-09-23 12:24:28.292197	f
da76ef4a-2475-4ec4-aeda-b785e0cffa5d	Khonology Company Overview	Company Profile	# About Khonology\n\nKhonology is a leading technology consulting firm specializing in digital transformation, enterprise software development, and AI-powered solutions. Founded in 2015, we have successfully delivered over 500+ projects for clients across various industries including finance, healthcare, retail, and government sectors.\n\n## Our Mission\nTo empower organizations through innovative technology solutions that drive measurable business outcomes and sustainable growth.\n\n## Our Vision\nTo be the trusted technology partner for organizations seeking to transform their operations through cutting-edge digital solutions.\n\n## Core Values\n- **Excellence**: We deliver exceptional quality in every engagement\n- **Innovation**: We embrace emerging technologies and creative problem-solving\n- **Integrity**: We operate with transparency and ethical standards\n- **Collaboration**: We work as partners with our clients\n- **Impact**: We focus on delivering measurable business value	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
0f5856bf-d0fc-4e5d-9e20-a2898b637d12	Khonology Service Offerings	Company Profile	# Our Services\n\n## Digital Transformation Consulting\nWe help organizations navigate their digital transformation journey with strategic planning, technology roadmaps, and change management support.\n\n## Enterprise Software Development\nCustom software solutions built with modern architectures, scalable designs, and user-centric approaches.\n\n## AI & Machine Learning Solutions\nIntelligent automation, predictive analytics, natural language processing, and computer vision applications.\n\n## Cloud Migration & Optimization\nEnd-to-end cloud strategy, migration services, and ongoing optimization for AWS, Azure, and Google Cloud platforms.\n\n## Data Analytics & Business Intelligence\nTransform raw data into actionable insights with advanced analytics, visualization, and reporting solutions.\n\n## Cybersecurity Services\nComprehensive security assessments, implementation, and ongoing monitoring to protect your digital assets.	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
726bce3d-d9bb-43d1-b94c-32705fe10942	Leadership Team Bio: Africa Nkosi (Head of Sales & Marketing)	bio	Africa Nkosi co-founded Khonology. She leads Sales & Marketing, ensuring market-fit solutions and strong client relations across growth initiatives and go-to-market strategy. 	3	\N	2025-09-23 12:24:28.242589	2025-09-28 16:57:40.686484	t
fc8eef95-da98-4e41-85ad-7fcf17826582	Services Offering	services	We offer application development, data engineering, AI/ML, workflow automation, product strategy, regulatory reporting, and consulting—integrating data, UX, and robust infrastructure for scale.	3	\N	2025-09-23 12:24:28.308212	2025-09-28 16:57:50.442967	t
affa9f43-fc3a-499e-be5c-493fa71b85f8	Khonology Delivery Methodology	Methodology	# Khonology Delivery Approach\n\n## Agile-Hybrid Methodology\nWe employ a flexible Agile-Hybrid approach that combines the best practices of Agile, Scrum, and traditional project management methodologies.\n\n### Discovery Phase (2-4 weeks)\n- Stakeholder interviews and requirements gathering\n- Current state assessment and gap analysis\n- Solution architecture and technical design\n- Project planning and resource allocation\n\n### Design Phase (2-6 weeks)\n- User experience (UX) design and prototyping\n- Technical architecture finalization\n- Security and compliance review\n- Design approval and sign-off\n\n### Development Phase (8-16 weeks)\n- Iterative development in 2-week sprints\n- Continuous integration and automated testing\n- Regular demos and stakeholder feedback\n- Quality assurance and code reviews\n\n### Deployment Phase (1-2 weeks)\n- User acceptance testing (UAT)\n- Production deployment and cutover\n- Training and knowledge transfer\n- Go-live support\n\n### Support & Optimization (Ongoing)\n- Post-launch monitoring and support\n- Performance optimization\n- Feature enhancements\n- Continuous improvement	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
c03b584d-7dfe-41a6-8f34-f727df1e2e3c	Standard Terms and Conditions	Legal	# Terms and Conditions\n\n## 1. Engagement Terms\nThis Statement of Work (SOW) is governed by the Master Services Agreement (MSA) between Khonology and the Client. In the event of any conflict between this SOW and the MSA, the MSA shall prevail.\n\n## 2. Payment Terms\n- Invoices are issued according to the payment schedule outlined in the Investment section\n- Payment is due within 30 days of invoice date\n- Late payments may incur interest charges of 1.5% per month\n- All fees are in USD unless otherwise specified\n\n## 3. Intellectual Property\n- Client retains ownership of all pre-existing intellectual property\n- Khonology retains ownership of pre-existing frameworks and methodologies\n- Custom deliverables developed under this SOW become Client property upon final payment\n- Khonology may use project as case study with Client approval\n\n## 4. Confidentiality\nBoth parties agree to maintain confidentiality of proprietary information shared during the engagement and for 3 years following completion.\n\n## 5. Warranties\nKhonology warrants that services will be performed in a professional manner consistent with industry standards. Software deliverables include a 90-day warranty period for defects.\n\n## 6. Limitation of Liability\nKhonology's total liability shall not exceed the total fees paid under this SOW. Neither party shall be liable for indirect, incidental, or consequential damages.\n\n## 7. Change Management\nChanges to scope, timeline, or budget require written approval from both parties via formal change request process.\n\n## 8. Termination\nEither party may terminate with 30 days written notice. Client is responsible for payment of work completed through termination date.	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
1eeb217f-7cb8-4ad2-b800-31576de12d23	Standard Assumptions	Assumptions	# Project Assumptions\n\n## Client Responsibilities\n- Client will provide timely access to necessary systems, data, and documentation\n- Client will assign a dedicated project sponsor and key stakeholders\n- Client will provide feedback and approvals within agreed timeframes (typically 5 business days)\n- Client will ensure availability of subject matter experts for requirements gathering and testing\n\n## Technical Environment\n- Client will provide necessary development, testing, and production environments\n- Required third-party licenses and subscriptions will be procured by Client\n- Existing systems and APIs will be available and documented\n- Network connectivity and security access will be provided as needed\n\n## Project Governance\n- Weekly status meetings will be held with project stakeholders\n- A formal change request process will be followed for scope changes\n- Project decisions will be made within agreed escalation timeframes\n- Both parties will maintain open and transparent communication\n\n## Timeline Assumptions\n- Project timeline assumes no major scope changes or delays in Client approvals\n- Resource availability from both Khonology and Client as outlined in the SOW\n- No extended holiday periods or organizational changes affecting project continuity\n\n## Deliverables\n- All deliverables will be in English unless otherwise specified\n- Documentation will be provided in electronic format (PDF, Word, or web-based)\n- Source code will be delivered via Git repository\n- Training will be conducted remotely unless on-site is explicitly specified	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
e869873e-1fb9-45f7-8f8a-5aefdb82125f	Standard Risk Assessment	Risk Management	# Project Risks and Mitigation Strategies\n\n## Technical Risks\n\n### Integration Complexity (Medium Risk)\n**Risk**: Third-party system integrations may be more complex than anticipated\n**Mitigation**: Conduct thorough technical discovery, allocate buffer time for integration testing, maintain close communication with third-party vendors\n\n### Data Quality Issues (Medium Risk)\n**Risk**: Legacy data may require extensive cleansing and transformation\n**Mitigation**: Perform early data assessment, allocate time for data quality remediation, implement validation rules\n\n### Performance Requirements (Low Risk)\n**Risk**: Solution may not meet performance requirements under load\n**Mitigation**: Conduct performance testing early, implement scalable architecture, plan for optimization iterations\n\n## Resource Risks\n\n### Key Resource Availability (Medium Risk)\n**Risk**: Critical team members may become unavailable during project\n**Mitigation**: Cross-train team members, maintain documentation, have backup resources identified\n\n### Client SME Availability (High Risk)\n**Risk**: Client subject matter experts may not be available when needed\n**Mitigation**: Schedule SME time in advance, document requirements thoroughly, escalate availability issues early\n\n## Schedule Risks\n\n### Scope Creep (High Risk)\n**Risk**: Uncontrolled changes may impact timeline and budget\n**Mitigation**: Implement formal change control process, maintain clear scope documentation, regular scope reviews\n\n### Approval Delays (Medium Risk)\n**Risk**: Delayed approvals may impact project timeline\n**Mitigation**: Set clear approval timeframes, escalate delays promptly, maintain approval tracking log\n\n## Organizational Risks\n\n### Change Management (Medium Risk)\n**Risk**: User adoption may be lower than expected\n**Mitigation**: Involve users early in design, provide comprehensive training, implement phased rollout\n\n### Competing Priorities (Medium Risk)\n**Risk**: Other organizational initiatives may impact project focus\n**Mitigation**: Secure executive sponsorship, maintain regular stakeholder communication, demonstrate quick wins	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
eac13592-ce95-4d20-a518-22f6161f45c2	Cloud Architecture Best Practices	Technical	# Cloud Architecture Principles\n\n## Scalability\nDesign systems to scale horizontally and vertically based on demand. Utilize auto-scaling groups, load balancers, and distributed architectures.\n\n## Reliability\nImplement multi-region deployments, automated failover, and disaster recovery procedures. Target 99.9% uptime SLA.\n\n## Security\n- Implement defense-in-depth security strategy\n- Use encryption at rest and in transit\n- Apply principle of least privilege for access control\n- Regular security audits and penetration testing\n- Compliance with SOC 2, ISO 27001, and industry-specific regulations\n\n## Cost Optimization\n- Right-size resources based on actual usage\n- Implement auto-shutdown for non-production environments\n- Use reserved instances for predictable workloads\n- Regular cost reviews and optimization recommendations\n\n## Monitoring & Observability\n- Centralized logging and monitoring\n- Real-time alerting for critical issues\n- Performance metrics and dashboards\n- Distributed tracing for microservices	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
cd6824f6-434a-4abc-9072-62fc7154c5fb	AI/ML Implementation Framework	Technical	# AI/ML Solution Development\n\n## Discovery & Assessment\n- Identify business problems suitable for AI/ML solutions\n- Assess data availability and quality\n- Define success metrics and KPIs\n- Evaluate technical feasibility\n\n## Data Preparation\n- Data collection and aggregation\n- Data cleansing and normalization\n- Feature engineering\n- Train/test/validation split\n\n## Model Development\n- Algorithm selection and experimentation\n- Model training and hyperparameter tuning\n- Cross-validation and performance evaluation\n- Model interpretability and explainability\n\n## Deployment & Integration\n- Model containerization and deployment\n- API development for model serving\n- Integration with existing systems\n- A/B testing and gradual rollout\n\n## Monitoring & Maintenance\n- Model performance monitoring\n- Data drift detection\n- Retraining pipeline automation\n- Continuous improvement process	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
a4a23470-0ec5-420e-897f-4ba65647a409	Agile Sprint Structure	Methodology	# Two-Week Sprint Cycle\n\n## Sprint Planning (Day 1)\n- Review and prioritize backlog items\n- Define sprint goals and commitments\n- Break down user stories into tasks\n- Estimate effort and assign work\n\n## Daily Standups (15 minutes)\n- What did I complete yesterday?\n- What will I work on today?\n- Are there any blockers?\n\n## Development & Testing (Days 2-9)\n- Feature development\n- Unit and integration testing\n- Code reviews and pair programming\n- Continuous integration\n\n## Sprint Review/Demo (Day 10 - Morning)\n- Demonstrate completed features\n- Gather stakeholder feedback\n- Accept or reject user stories\n- Update product backlog\n\n## Sprint Retrospective (Day 10 - Afternoon)\n- What went well?\n- What could be improved?\n- Action items for next sprint\n- Team building and celebration	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
f5d88b33-4350-460f-bc46-9b783f12fde8	Executive Summary Template	Templates	# Executive Summary\n\n[Client Name] has engaged Khonology to [brief description of project objective]. This proposal outlines our approach to delivering [key outcomes] through [solution approach].\n\n## Business Challenge\n[Client Name] is currently facing [describe business challenge or opportunity]. This situation is impacting [business impact areas] and requires [type of solution needed].\n\n## Proposed Solution\nKhonology proposes to [high-level solution description]. Our approach leverages [key technologies/methodologies] to deliver [specific benefits].\n\n## Key Benefits\n- **[Benefit 1]**: [Description and quantified impact]\n- **[Benefit 2]**: [Description and quantified impact]\n- **[Benefit 3]**: [Description and quantified impact]\n\n## Investment & Timeline\nThe total investment for this engagement is **$[Amount]** with an estimated timeline of **[X] weeks/months**. The project will be delivered in [number] phases with key milestones at [milestone descriptions].\n\n## Why Khonology\nKhonology brings [X] years of experience in [relevant domain], having successfully delivered [number] similar projects. Our team combines deep technical expertise with industry knowledge to ensure successful outcomes.\n\n## Next Steps\nUpon approval, we can commence the engagement within [timeframe], with initial deliverables available by [date].	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
1ec37a46-19fd-4e2f-ae81-1e9782b0f5a8	Scope & Deliverables Template	Templates	# Scope & Deliverables\n\n## Project Scope\n\n### In Scope\nThe following activities and deliverables are included in this engagement:\n\n1. **[Deliverable Category 1]**\n   - [Specific deliverable 1.1]\n   - [Specific deliverable 1.2]\n   - [Specific deliverable 1.3]\n\n2. **[Deliverable Category 2]**\n   - [Specific deliverable 2.1]\n   - [Specific deliverable 2.2]\n   - [Specific deliverable 2.3]\n\n3. **[Deliverable Category 3]**\n   - [Specific deliverable 3.1]\n   - [Specific deliverable 3.2]\n   - [Specific deliverable 3.3]\n\n### Out of Scope\nThe following items are explicitly excluded from this engagement:\n- [Out of scope item 1]\n- [Out of scope item 2]\n- [Out of scope item 3]\n\n## Key Deliverables\n\n| Deliverable | Description | Format | Due Date |\n|------------|-------------|---------|----------|\n| [Deliverable 1] | [Description] | [Format] | [Date] |\n| [Deliverable 2] | [Description] | [Format] | [Date] |\n| [Deliverable 3] | [Description] | [Format] | [Date] |\n\n## Acceptance Criteria\nEach deliverable will be considered complete when:\n- All specified functionality is implemented and tested\n- Documentation is provided as outlined\n- Client acceptance testing is successfully completed\n- Any defects are resolved or documented for future phases	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
d4ab1e77-eb00-4034-b3db-486be78b54aa	Team Bios Template	Templates	# Project Team\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] brings extensive experience in [key expertise areas]. Notable projects include [brief project descriptions]. [He/She] holds [relevant certifications] and has deep expertise in [technologies/methodologies].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]\n\n---\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] specializes in [key expertise areas] with a proven track record of [achievements]. [He/She] has led [number] successful implementations and brings expertise in [specific skills].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]\n\n---\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] is an expert in [key expertise areas] with experience across [industries/domains]. [He/She] has successfully delivered [types of projects] and holds [certifications/degrees].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
3b3324fb-a3d0-45a3-a87f-59d2d921fe35	Investment & Payment Schedule Template	Templates	# Investment\n\n## Total Investment: $[Amount]\n\n### Cost Breakdown\n\n| Category | Description | Cost |\n|----------|-------------|------|\n| Professional Services | [X] hours @ $[rate]/hour | $[amount] |\n| Project Management | [X] hours @ $[rate]/hour | $[amount] |\n| Infrastructure Setup | One-time setup costs | $[amount] |\n| Third-Party Licenses | [Description] | $[amount] |\n| **Total** | | **$[amount]** |\n\n### Payment Schedule\n\n| Milestone | Deliverables | Amount | Due Date |\n|-----------|--------------|--------|----------|\n| Contract Signing | 30% deposit | $[amount] | Upon signing |\n| Phase 1 Completion | [Deliverables] | $[amount] | [Date] |\n| Phase 2 Completion | [Deliverables] | $[amount] | [Date] |\n| Final Delivery | All deliverables | $[amount] | [Date] |\n\n### Expenses\nTravel and other expenses will be billed at cost with prior approval. Estimated expenses: $[amount]\n\n### Payment Terms\n- Invoices are due within 30 days of receipt\n- Late payments subject to 1.5% monthly interest\n- All amounts in USD\n\n### Assumptions\nThis investment is based on the scope outlined in this proposal. Any changes to scope will be managed through our formal change request process and may impact the total investment.	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	t
5f03e8e1-9b9d-4e47-95f7-e69b17c0d5d4	Financial Services References	References	# Client References - Financial Services\n\n## Global Bank - Digital Banking Platform\n**Client**: Major international bank (Fortune 500)\n**Project**: Complete digital banking platform transformation\n**Duration**: 18 months\n**Team Size**: 25 consultants\n\n**Challenge**: Legacy banking systems unable to support modern digital banking requirements\n\n**Solution**: Developed cloud-native digital banking platform with mobile-first design, real-time transaction processing, and AI-powered fraud detection\n\n**Results**:\n- 300% increase in digital banking adoption\n- 45% reduction in operational costs\n- 99.99% system uptime achieved\n- $50M annual cost savings\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## Investment Firm - Data Analytics Platform\n**Client**: Leading investment management firm\n**Project**: Enterprise data analytics and reporting platform\n**Duration**: 12 months\n**Team Size**: 15 consultants\n\n**Challenge**: Disparate data sources preventing unified investment insights\n\n**Solution**: Implemented centralized data lake with advanced analytics, machine learning models for investment predictions, and executive dashboards\n\n**Results**:\n- 80% faster reporting cycles\n- 25% improvement in investment decision accuracy\n- $30M additional revenue from data-driven insights\n\n**Reference Contact**: [Available upon request]	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
c32d0ac5-8915-478c-8ce8-d58a8db14b03	Healthcare References	References	# Client References - Healthcare\n\n## Regional Hospital Network - EHR Integration\n**Client**: 15-hospital regional healthcare network\n**Project**: Electronic Health Record (EHR) system integration\n**Duration**: 24 months\n**Team Size**: 30 consultants\n\n**Challenge**: Fragmented patient records across multiple systems impacting care quality\n\n**Solution**: Integrated EHR systems across all facilities with unified patient portal, interoperability standards (FHIR), and clinical decision support\n\n**Results**:\n- 60% reduction in duplicate tests\n- 40% improvement in care coordination\n- 95% physician satisfaction rate\n- HIPAA and HITECH compliance achieved\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## Pharmaceutical Company - Clinical Trials Platform\n**Client**: Global pharmaceutical company\n**Project**: Clinical trials management platform\n**Duration**: 16 months\n**Team Size**: 20 consultants\n\n**Challenge**: Manual clinical trial processes causing delays and compliance risks\n\n**Solution**: Developed automated clinical trials platform with patient recruitment, data collection, regulatory reporting, and AI-powered adverse event detection\n\n**Results**:\n- 50% faster trial completion\n- 90% reduction in data entry errors\n- FDA 21 CFR Part 11 compliance\n- $40M cost savings in trial operations\n\n**Reference Contact**: [Available upon request]	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
7d23e13f-6835-4811-872c-69ac7904bab5	Retail & E-commerce References	References	# Client References - Retail & E-commerce\n\n## National Retailer - Omnichannel Platform\n**Client**: Top 10 US retailer\n**Project**: Omnichannel commerce platform\n**Duration**: 20 months\n**Team Size**: 35 consultants\n\n**Challenge**: Disconnected online and in-store experiences losing customers to competitors\n\n**Solution**: Built unified commerce platform with real-time inventory, buy-online-pickup-in-store (BOPIS), personalized recommendations, and mobile app\n\n**Results**:\n- 200% increase in online sales\n- 35% improvement in customer satisfaction\n- 50% reduction in inventory carrying costs\n- $100M additional annual revenue\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## E-commerce Startup - Scalable Platform\n**Client**: Fast-growing e-commerce startup\n**Project**: Scalable cloud infrastructure and platform\n**Duration**: 10 months\n**Team Size**: 12 consultants\n\n**Challenge**: Existing platform unable to handle rapid growth and traffic spikes\n\n**Solution**: Migrated to cloud-native architecture with auto-scaling, microservices, CDN, and DevOps automation\n\n**Results**:\n- 10x traffic capacity increase\n- 99.95% uptime during peak seasons\n- 70% reduction in infrastructure costs\n- Successful Black Friday with zero downtime\n\n**Reference Contact**: [Available upon request]	1	\N	2025-10-15 13:04:57.56458	2025-10-15 13:04:57.56458	f
\.


--
-- Data for Name: database_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.database_settings (id, backup_enabled, backup_frequency, retention_days, auto_cleanup, created_at, updated_at) FROM stdin;
1	t	daily	30	t	2025-10-08 23:30:44.680422	2025-10-08 23:30:44.680422
\.


--
-- Data for Name: document_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.document_comments (id, proposal_id, comment_text, created_by, created_at, section_index, highlighted_text, status, updated_at, resolved_by, resolved_at, parent_id, block_type, block_id, section_name) FROM stdin;
1	29	I saw the proposal I think  everything is fine, just check the prices	13	2025-10-27 13:30:04.626137	\N	\N	open	2025-10-27 13:30:04.626137	\N	\N	\N	\N	\N	\N
2	29	I'll change the prices	13	2025-10-27 13:34:27.341347	\N	\N	open	2025-10-27 13:34:27.341347	\N	\N	\N	\N	\N	\N
3	28	The proposal lack something, Please add the background and visuals	16	2025-10-27 13:57:03.738778	\N	\N	open	2025-10-27 13:57:03.738778	\N	\N	\N	\N	\N	\N
4	28	Can you please add budget on this proposal	22	2025-10-27 14:12:58.31974	\N	\N	open	2025-10-27 14:12:58.31974	\N	\N	\N	\N	\N	\N
5	28	Okay I already did add them, Thanks	16	2025-10-27 14:14:06.728558	\N	\N	open	2025-10-27 14:14:06.728558	\N	\N	\N	\N	\N	\N
6	28	I added the investment, Please re-check it	22	2025-10-27 14:46:10.545671	\N	\N	open	2025-10-27 14:46:10.545671	\N	\N	\N	\N	\N	\N
7	28	Will do so, thanks	16	2025-10-27 14:47:46.320728	\N	\N	open	2025-10-27 14:47:46.320728	\N	\N	\N	\N	\N	\N
8	31	Hey, please check the introduction and get back to me regarding it	22	2025-10-27 16:10:53.102888	\N	\N	open	2025-10-27 16:10:53.102888	\N	\N	\N	\N	\N	\N
9	31	Afternooon Zukhanye, will gladly do that	13	2025-10-27 16:11:54.466085	\N	\N	open	2025-10-27 16:11:54.466085	\N	\N	\N	\N	\N	\N
10	32	Please add budget pricing	22	2025-10-27 16:50:02.033045	\N	\N	open	2025-10-27 16:50:02.033045	\N	\N	\N	\N	\N	\N
11	32	Hey, its added	16	2025-10-27 16:51:12.34955	\N	\N	open	2025-10-27 16:51:12.34955	\N	\N	\N	\N	\N	\N
12	34	Good day, can you please fix the executive summary	22	2025-10-28 16:05:49.316899	\N	\N	open	2025-10-28 16:05:49.316899	\N	\N	\N	\N	\N	\N
13	34	Please re-check the execative summary	22	2025-10-28 18:20:51.929721	\N	\N	open	2025-10-28 18:20:51.929721	\N	\N	\N	\N	\N	\N
14	35	Hi, I need clarity with prices	13	2025-10-29 21:53:20.288943	\N	\N	open	2025-10-29 21:53:20.288943	\N	\N	\N	\N	\N	\N
21	41	Can you please help me edit the proposal	22	2025-11-07 14:03:01.775669	\N	\N	open	2025-11-07 14:03:01.775669	\N	\N	\N	\N	\N	\N
22	42	Please help me with the document	22	2025-11-07 14:15:10.374096	\N	\N	open	2025-11-07 14:15:10.374096	\N	\N	\N	\N	\N	\N
23	42	We still need to fix the url thats in the background	13	2025-11-07 14:15:55.930379	\N	\N	open	2025-11-07 14:15:55.930379	\N	\N	\N	\N	\N	\N
24	43	Please check the proposal if it fine	22	2025-11-07 15:09:54.625602	\N	\N	open	2025-11-07 15:09:54.625602	\N	\N	\N	\N	\N	\N
25	43	I see the proposal but what happening with the url	13	2025-11-07 15:11:17.086368	\N	\N	open	2025-11-07 15:11:17.086368	\N	\N	\N	\N	\N	\N
26	44	hey @Unathi please check the in app notification	22	2025-11-10 20:32:03.478359	\N	\N	open	2025-11-10 20:32:03.478359	\N	\N	\N	\N	\N	\N
27	44	@zukhanye@gmail.com Please check whats happening with the URL	16	2025-11-10 20:34:54.17326	\N	\N	open	2025-11-10 20:34:54.17326	\N	\N	\N	\N	\N	\N
28	44	@zukhanye@gmail.com Also remove the metadata	16	2025-11-10 20:55:02.710946	\N	\N	open	2025-11-10 20:55:02.710946	\N	\N	\N	\N	\N	\N
29	44	@zukhanye@gmail.com I forgot, I also added company profile	16	2025-11-10 21:09:51.616188	\N	\N	open	2025-11-10 21:09:51.616188	\N	\N	\N	\N	\N	\N
30	44	@zukhanye@gmail.com The tables are not included	16	2025-11-10 21:49:24.554295	\N	\N	open	2025-11-10 21:49:24.554295	\N	\N	\N	\N	\N	\N
31	44	@zukhanye@gmail.com Please check your messages	16	2025-11-10 22:10:21.277037	\N	\N	open	2025-11-10 22:10:21.277037	\N	\N	\N	\N	\N	\N
32	44	@zukhanye@gmail.com also add Hopeon the collaboration	16	2025-11-10 22:20:24.714106	\N	\N	open	2025-11-10 22:20:24.714106	\N	\N	\N	\N	\N	\N
33	44	@zukhanye@gmail.com its hope@gmail.com	16	2025-11-10 22:54:30.812635	\N	\N	open	2025-11-10 22:54:30.812635	\N	\N	\N	\N	\N	\N
34	44	@umsibanda.1994@gmail.com Please check the pricing and budgeting tables	16	2025-11-11 11:59:21.339699	\N	\N	open	2025-11-11 11:59:21.339699	\N	\N	\N	\N	\N	\N
35	44	@zukhanye@gmail.com thank you	16	2025-11-11 11:59:36.808814	\N	\N	open	2025-11-11 11:59:36.808814	\N	\N	\N	\N	\N	\N
36	44	@zukhanye@gmail.com check your messages please	16	2025-11-11 12:13:12.052466	\N	\N	open	2025-11-11 12:13:12.052466	\N	\N	\N	\N	\N	\N
37	44	@zukhanye@gmail.com check it out	16	2025-11-11 12:24:05.695005	\N	\N	open	2025-11-11 12:24:05.695005	\N	\N	\N	\N	\N	\N
38	44	@zukhanye@gmail.com Hi	16	2025-11-11 12:40:47.133668	\N	\N	open	2025-11-11 12:40:47.133668	\N	\N	\N	\N	\N	\N
39	44	@zukhanye@gmail.com eiy	16	2025-11-11 13:00:29.21659	\N	\N	open	2025-11-11 13:00:29.21659	\N	\N	\N	\N	\N	\N
40	44	@zukhanye@gmail.com its called smtp	16	2025-11-11 13:27:28.350545	\N	\N	open	2025-11-11 13:27:28.350545	\N	\N	\N	\N	\N	\N
41	44	@zukhanye@gmail.com yes	16	2025-11-11 13:38:19.483967	\N	\N	open	2025-11-11 13:38:19.483967	\N	\N	\N	\N	\N	\N
42	44	@zukhanye@gmail.com ???	16	2025-11-11 13:58:52.211683	\N	\N	open	2025-11-11 13:58:52.211683	\N	\N	\N	\N	\N	\N
43	47	@zukhanye@gmail.com Hi, how are you	13	2025-11-13 10:10:59.177103	\N	\N	open	2025-11-13 10:10:59.177103	\N	\N	\N	\N	\N	\N
44	47	@Unathi, Hiii	22	2025-11-13 10:11:57.532065	\N	\N	open	2025-11-13 10:11:57.532065	\N	\N	\N	\N	\N	\N
45	49	Hey @Unathi	15	2025-11-17 23:47:17.338651	\N	\N	open	2025-11-17 23:47:17.338651	\N	\N	\N	\N	\N	\N
46	48	Hi	16	2025-11-18 02:01:24.311476	\N	\N	open	2025-11-18 02:01:24.311476	\N	\N	\N	\N	\N	\N
47	63	✗ REJECTED\nReason: Nothing	13	2025-11-19 16:00:14.422386	\N	\N	resolved	2025-11-19 16:00:14.422386	\N	\N	\N	\N	\N	\N
48	67	Hey	15	2025-11-21 15:46:04.834386	\N	\N	open	2025-11-21 15:46:04.834386	\N	\N	\N	\N	\N	\N
50	67	...	15	2025-11-21 16:14:33.255531	\N	\N	resolved	2025-11-21 18:25:21.493684	15	2025-11-21 18:25:21.493684	\N	\N	\N	\N
51	67	Please help me solve this	15	2025-11-21 18:02:06.455093	\N	\N	resolved	2025-11-21 18:25:21.493684	15	2025-11-21 18:25:21.493684	50	\N	\N	\N
49	67	hello	15	2025-11-21 16:01:04.504712	\N	\N	resolved	2025-11-21 18:26:38.159602	15	2025-11-21 18:26:38.159602	\N	\N	\N	\N
52	67	Hi, I fixed the tables	15	2025-11-21 18:26:21.905504	\N	\N	resolved	2025-11-21 18:26:38.159602	15	2025-11-21 18:26:38.159602	49	\N	\N	\N
53	67	@Zukhanye, please check the proposal	13	2025-11-22 17:14:04.655042	\N	\N	open	2025-11-22 17:14:04.655042	\N	\N	\N	\N	\N	\N
54	67	Thank you, I will	15	2025-11-22 17:16:50.801018	\N	\N	open	2025-11-22 17:16:50.801018	\N	\N	53	\N	\N	\N
55	72	✗ REJECTED\nReason: I am not convinced	13	2025-11-26 16:01:32.571108	\N	\N	resolved	2025-11-26 16:01:32.571108	\N	\N	\N	\N	\N	\N
56	73	You outdid yourself	16	2025-11-26 16:55:04.666357	\N	\N	open	2025-11-26 16:55:04.666357	\N	\N	\N	\N	\N	\N
57	75	hi	15	2025-11-27 16:06:25.638839	\N	\N	open	2025-11-27 16:06:25.638839	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: email_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.email_settings (id, smtp_server, smtp_port, smtp_username, smtp_password, smtp_use_tls, from_email, from_name, created_at, updated_at) FROM stdin;
1	smtp.gmail.com	587			t		Proposal System	2025-10-08 23:30:44.680422	2025-10-08 23:30:44.680422
\.


--
-- Data for Name: email_verification_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.email_verification_events (id, invitation_id, email, event_type, event_detail, created_at) FROM stdin;
1	4	sheziluthando513@gmail.com	code_sent	Admin triggered email verification code send	2025-11-18 17:27:52.935955
\.


--
-- Data for Name: module_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.module_versions (id, module_id, version, snapshot, created_by, created_at, note) FROM stdin;
ae2e466a-c5b4-4c87-bd8e-47879d2e67c9	1ec4e55c-4457-4595-9252-1eed325c60fc	1	Khonology is a digital-services company founded in 2013, a B-BBEE Level 2 provider. Our vision is to ‘Digitise Africa’ by providing end-to-end digital solutions: application development, data engineering, AI, regulatory reporting, automation of workflows. We focus on transforming client experience through data-led insights and systemised delivery frameworks.	\N	2025-09-23 12:24:28.157546	Initial version
a3869c2b-e7b2-424f-93f2-c6b26edc2d23	bb439a2e-d292-4603-8103-946660f20758	1	Dapo Adeyemo is Co-founder and CEO of Khonology. With a strong background in leadership and partnerships, he leads vision and strategic growth, overseeing client delivery and innovation.	\N	2025-09-23 12:24:28.227504	Initial version
ac530c75-3727-4844-8364-cfb7480ecf7d	726bce3d-d9bb-43d1-b94c-32705fe10942	1	Africa Nkosi co-founded Khonology. She leads Sales & Marketing, ensuring market-fit solutions and strong client relations across growth initiatives and go-to-market strategy.	\N	2025-09-23 12:24:28.244604	Initial version
76f18130-1ec5-4af7-8377-22a3799147a7	95d54d78-234e-4134-a284-53f7cf074060	1	These terms outline Khonology’s standard conditions for digital services, covering scope, payment, confidentiality, IP, and liability. All proposals are subject to these terms unless otherwise negotiated.	\N	2025-09-23 12:24:28.261796	Initial version
25f9caf8-fd7a-4df9-8319-c96ef917ebda	8fa3f00b-3ba4-4a81-b2fd-632a85809053	1	Our Delivery Framework blends Agile and Design Thinking: discovery → rapid prototyping → iterative development → QA → client validation. Data engineering and architecture underpin delivery; regulatory and compliance checks are embedded throughout.	\N	2025-09-23 12:24:28.294231	Initial version
a8962774-98a6-403c-a823-2234386da6b7	fc8eef95-da98-4e41-85ad-7fcf17826582	1	We offer application development, data engineering, AI/ML, workflow automation, product strategy, regulatory reporting, and consulting—integrating data, UX, and robust infrastructure for scale.	\N	2025-09-23 12:24:28.310144	Initial version
324bfce2-63c2-4c5f-a362-608de13847e7	fc8eef95-da98-4e41-85ad-7fcf17826582	2	We offer application development, data engineering, AI/ML, workflow automation, product strategy, regulatory reporting, and consulting—integrating data, UX, and robust infrastructure for scale.	\N	2025-09-28 16:56:15.545141	Edited
47881293-d663-47f6-9bee-3b8f46830824	726bce3d-d9bb-43d1-b94c-32705fe10942	2	Africa Nkosi co-founded Khonology. She leads Sales & Marketing, ensuring market-fit solutions and strong client relations across growth initiatives and go-to-market strategy.	\N	2025-09-28 16:57:09.258023	Edited
0f6f88fe-12dd-4b5c-863e-0cccaf79f619	726bce3d-d9bb-43d1-b94c-32705fe10942	3	Africa Nkosi co-founded Khonology. She leads Sales & Marketing, ensuring market-fit solutions and strong client relations across growth initiatives and go-to-market strategy. Africa	\N	2025-09-28 16:57:40.686484	Edited
23bc76ab-2c8b-4333-a63d-6f2aacc3ef12	fc8eef95-da98-4e41-85ad-7fcf17826582	3	We offer application development, data engineering, AI/ML, workflow automation, product strategy, regulatory reporting, and consulting—integrating data, UX, and robust infrastructure for scale.www	\N	2025-09-28 16:57:50.442967	Edited
3a93b984-9a55-4b3c-8f7d-b8b3ca75d1f2	d4b78b2f-8cf3-4ab0-8bb5-3ca9355ee856	1	Khonology is a digital-services company founded in 2013, a B-BBEE Level 2 provider. Our vision is to Digitise Africa by providing end-to-end digital solutions: application development, data engineering, AI, regulatory reporting, and workflow automation. We focus on transforming client experience through data-led insights and systemised delivery frameworks.	\N	2025-10-15 13:04:57.56458	Initial version
e0b9f401-85d3-4042-9766-6bc4acf2e81f	4220821d-9e16-4c54-ac28-0786e732e9ae	1	Vision: Digitise Africa. We believe in unlocking value through digital transformation, enabling agility and insight in decision-making. Mission: deliver data-driven, scalable, and human-centred digital solutions.	\N	2025-10-15 13:04:57.56458	Initial version
e16f37dc-9344-4bfe-a78a-29b64f226c67	55ca7c6c-d796-4be6-bcd6-3e5aea2c7623	1	Dapo Adeyemo is Co-founder and CEO of Khonology. With a strong background in business leadership and technology strategy, he leads vision and strategic partnerships, overseeing client delivery and innovation.	\N	2025-10-15 13:04:57.56458	Initial version
10e6a9b0-1378-4ddf-873f-60a8aa3b48f2	0bdee407-2ef8-4853-a479-f469714f558b	1	Africa Nkosi co-founded Khonology and leads Sales & Marketing. Her expertise is in business growth, go-to-market strategies, and client relations, ensuring Khonologys solutions are market-fit.	\N	2025-10-15 13:04:57.56458	Initial version
7d98221d-ba76-4e44-a067-42211c34d098	df710a8c-fbff-4765-b348-d5daa044f8a1	1	These terms outline Khonologys standard conditions for digital services, covering scope, payment, confidentiality, and liability. All proposals are subject to these terms unless otherwise negotiated.	\N	2025-10-15 13:04:57.56458	Initial version
8e3c5ad3-2a89-4d82-a30e-6b8ff4f631f2	55e314cd-b725-456d-8fbe-2c633b2eb9ba	1	Our Delivery Framework follows Agile + Design Thinking. We begin with discovery, followed by rapid prototyping, iterative development, quality assurance, and client validation. Data engineering and system architecture underpin all delivery. Regulatory and compliance checks are embedded throughout.	\N	2025-10-15 13:04:57.56458	Initial version
65077a8e-6e9c-4cb7-bd6c-7bfdd86c9001	96998d89-4943-4e1a-8321-4285131a575e	1	We offer application development, data engineering, AI/ML, automation of business processes, product strategy, regulatory reporting, and consulting. Our strength lies in integrating data, usability, and robust infrastructure to support scalable solutions.	\N	2025-10-15 13:04:57.56458	Initial version
a2f5c8b0-66a6-435d-a68b-207b18c0d94c	016af4f9-fd64-47ca-8686-007e1a4e003f	1	Client problem: manual regulatory reporting was error-prone and slow. Solution: Khonology automated data pipelines, implemented validation rules, and streamlined report generation. Result: reduced errors by XX%, decreased time from data submission to approval by YY%.	\N	2025-10-15 13:04:57.56458	Initial version
1e582feb-0d77-4fa9-bdb9-8f254f446d7e	da76ef4a-2475-4ec4-aeda-b785e0cffa5d	1	# About Khonology\n\nKhonology is a leading technology consulting firm specializing in digital transformation, enterprise software development, and AI-powered solutions. Founded in 2015, we have successfully delivered over 500+ projects for clients across various industries including finance, healthcare, retail, and government sectors.\n\n## Our Mission\nTo empower organizations through innovative technology solutions that drive measurable business outcomes and sustainable growth.\n\n## Our Vision\nTo be the trusted technology partner for organizations seeking to transform their operations through cutting-edge digital solutions.\n\n## Core Values\n- **Excellence**: We deliver exceptional quality in every engagement\n- **Innovation**: We embrace emerging technologies and creative problem-solving\n- **Integrity**: We operate with transparency and ethical standards\n- **Collaboration**: We work as partners with our clients\n- **Impact**: We focus on delivering measurable business value	\N	2025-10-15 13:04:57.56458	Initial version
e3df41bd-ac87-4029-b9d2-028cdf8117ca	0f5856bf-d0fc-4e5d-9e20-a2898b637d12	1	# Our Services\n\n## Digital Transformation Consulting\nWe help organizations navigate their digital transformation journey with strategic planning, technology roadmaps, and change management support.\n\n## Enterprise Software Development\nCustom software solutions built with modern architectures, scalable designs, and user-centric approaches.\n\n## AI & Machine Learning Solutions\nIntelligent automation, predictive analytics, natural language processing, and computer vision applications.\n\n## Cloud Migration & Optimization\nEnd-to-end cloud strategy, migration services, and ongoing optimization for AWS, Azure, and Google Cloud platforms.\n\n## Data Analytics & Business Intelligence\nTransform raw data into actionable insights with advanced analytics, visualization, and reporting solutions.\n\n## Cybersecurity Services\nComprehensive security assessments, implementation, and ongoing monitoring to protect your digital assets.	\N	2025-10-15 13:04:57.56458	Initial version
eb57b96d-06b3-4056-8095-f32c99f0d06f	affa9f43-fc3a-499e-be5c-493fa71b85f8	1	# Khonology Delivery Approach\n\n## Agile-Hybrid Methodology\nWe employ a flexible Agile-Hybrid approach that combines the best practices of Agile, Scrum, and traditional project management methodologies.\n\n### Discovery Phase (2-4 weeks)\n- Stakeholder interviews and requirements gathering\n- Current state assessment and gap analysis\n- Solution architecture and technical design\n- Project planning and resource allocation\n\n### Design Phase (2-6 weeks)\n- User experience (UX) design and prototyping\n- Technical architecture finalization\n- Security and compliance review\n- Design approval and sign-off\n\n### Development Phase (8-16 weeks)\n- Iterative development in 2-week sprints\n- Continuous integration and automated testing\n- Regular demos and stakeholder feedback\n- Quality assurance and code reviews\n\n### Deployment Phase (1-2 weeks)\n- User acceptance testing (UAT)\n- Production deployment and cutover\n- Training and knowledge transfer\n- Go-live support\n\n### Support & Optimization (Ongoing)\n- Post-launch monitoring and support\n- Performance optimization\n- Feature enhancements\n- Continuous improvement	\N	2025-10-15 13:04:57.56458	Initial version
2a8918ca-6bb1-417a-a8e7-2f634db74ae2	c03b584d-7dfe-41a6-8f34-f727df1e2e3c	1	# Terms and Conditions\n\n## 1. Engagement Terms\nThis Statement of Work (SOW) is governed by the Master Services Agreement (MSA) between Khonology and the Client. In the event of any conflict between this SOW and the MSA, the MSA shall prevail.\n\n## 2. Payment Terms\n- Invoices are issued according to the payment schedule outlined in the Investment section\n- Payment is due within 30 days of invoice date\n- Late payments may incur interest charges of 1.5% per month\n- All fees are in USD unless otherwise specified\n\n## 3. Intellectual Property\n- Client retains ownership of all pre-existing intellectual property\n- Khonology retains ownership of pre-existing frameworks and methodologies\n- Custom deliverables developed under this SOW become Client property upon final payment\n- Khonology may use project as case study with Client approval\n\n## 4. Confidentiality\nBoth parties agree to maintain confidentiality of proprietary information shared during the engagement and for 3 years following completion.\n\n## 5. Warranties\nKhonology warrants that services will be performed in a professional manner consistent with industry standards. Software deliverables include a 90-day warranty period for defects.\n\n## 6. Limitation of Liability\nKhonology's total liability shall not exceed the total fees paid under this SOW. Neither party shall be liable for indirect, incidental, or consequential damages.\n\n## 7. Change Management\nChanges to scope, timeline, or budget require written approval from both parties via formal change request process.\n\n## 8. Termination\nEither party may terminate with 30 days written notice. Client is responsible for payment of work completed through termination date.	\N	2025-10-15 13:04:57.56458	Initial version
68ed7bf9-50f9-4d3a-bc3b-49ddadc12806	1eeb217f-7cb8-4ad2-b800-31576de12d23	1	# Project Assumptions\n\n## Client Responsibilities\n- Client will provide timely access to necessary systems, data, and documentation\n- Client will assign a dedicated project sponsor and key stakeholders\n- Client will provide feedback and approvals within agreed timeframes (typically 5 business days)\n- Client will ensure availability of subject matter experts for requirements gathering and testing\n\n## Technical Environment\n- Client will provide necessary development, testing, and production environments\n- Required third-party licenses and subscriptions will be procured by Client\n- Existing systems and APIs will be available and documented\n- Network connectivity and security access will be provided as needed\n\n## Project Governance\n- Weekly status meetings will be held with project stakeholders\n- A formal change request process will be followed for scope changes\n- Project decisions will be made within agreed escalation timeframes\n- Both parties will maintain open and transparent communication\n\n## Timeline Assumptions\n- Project timeline assumes no major scope changes or delays in Client approvals\n- Resource availability from both Khonology and Client as outlined in the SOW\n- No extended holiday periods or organizational changes affecting project continuity\n\n## Deliverables\n- All deliverables will be in English unless otherwise specified\n- Documentation will be provided in electronic format (PDF, Word, or web-based)\n- Source code will be delivered via Git repository\n- Training will be conducted remotely unless on-site is explicitly specified	\N	2025-10-15 13:04:57.56458	Initial version
a07baa61-e59d-49de-b853-480203e10a0e	e869873e-1fb9-45f7-8f8a-5aefdb82125f	1	# Project Risks and Mitigation Strategies\n\n## Technical Risks\n\n### Integration Complexity (Medium Risk)\n**Risk**: Third-party system integrations may be more complex than anticipated\n**Mitigation**: Conduct thorough technical discovery, allocate buffer time for integration testing, maintain close communication with third-party vendors\n\n### Data Quality Issues (Medium Risk)\n**Risk**: Legacy data may require extensive cleansing and transformation\n**Mitigation**: Perform early data assessment, allocate time for data quality remediation, implement validation rules\n\n### Performance Requirements (Low Risk)\n**Risk**: Solution may not meet performance requirements under load\n**Mitigation**: Conduct performance testing early, implement scalable architecture, plan for optimization iterations\n\n## Resource Risks\n\n### Key Resource Availability (Medium Risk)\n**Risk**: Critical team members may become unavailable during project\n**Mitigation**: Cross-train team members, maintain documentation, have backup resources identified\n\n### Client SME Availability (High Risk)\n**Risk**: Client subject matter experts may not be available when needed\n**Mitigation**: Schedule SME time in advance, document requirements thoroughly, escalate availability issues early\n\n## Schedule Risks\n\n### Scope Creep (High Risk)\n**Risk**: Uncontrolled changes may impact timeline and budget\n**Mitigation**: Implement formal change control process, maintain clear scope documentation, regular scope reviews\n\n### Approval Delays (Medium Risk)\n**Risk**: Delayed approvals may impact project timeline\n**Mitigation**: Set clear approval timeframes, escalate delays promptly, maintain approval tracking log\n\n## Organizational Risks\n\n### Change Management (Medium Risk)\n**Risk**: User adoption may be lower than expected\n**Mitigation**: Involve users early in design, provide comprehensive training, implement phased rollout\n\n### Competing Priorities (Medium Risk)\n**Risk**: Other organizational initiatives may impact project focus\n**Mitigation**: Secure executive sponsorship, maintain regular stakeholder communication, demonstrate quick wins	\N	2025-10-15 13:04:57.56458	Initial version
f174ff88-a698-493c-a295-961fb5f2fdc5	eac13592-ce95-4d20-a518-22f6161f45c2	1	# Cloud Architecture Principles\n\n## Scalability\nDesign systems to scale horizontally and vertically based on demand. Utilize auto-scaling groups, load balancers, and distributed architectures.\n\n## Reliability\nImplement multi-region deployments, automated failover, and disaster recovery procedures. Target 99.9% uptime SLA.\n\n## Security\n- Implement defense-in-depth security strategy\n- Use encryption at rest and in transit\n- Apply principle of least privilege for access control\n- Regular security audits and penetration testing\n- Compliance with SOC 2, ISO 27001, and industry-specific regulations\n\n## Cost Optimization\n- Right-size resources based on actual usage\n- Implement auto-shutdown for non-production environments\n- Use reserved instances for predictable workloads\n- Regular cost reviews and optimization recommendations\n\n## Monitoring & Observability\n- Centralized logging and monitoring\n- Real-time alerting for critical issues\n- Performance metrics and dashboards\n- Distributed tracing for microservices	\N	2025-10-15 13:04:57.56458	Initial version
3f222b52-0d72-4076-a454-9f9bea4899f8	cd6824f6-434a-4abc-9072-62fc7154c5fb	1	# AI/ML Solution Development\n\n## Discovery & Assessment\n- Identify business problems suitable for AI/ML solutions\n- Assess data availability and quality\n- Define success metrics and KPIs\n- Evaluate technical feasibility\n\n## Data Preparation\n- Data collection and aggregation\n- Data cleansing and normalization\n- Feature engineering\n- Train/test/validation split\n\n## Model Development\n- Algorithm selection and experimentation\n- Model training and hyperparameter tuning\n- Cross-validation and performance evaluation\n- Model interpretability and explainability\n\n## Deployment & Integration\n- Model containerization and deployment\n- API development for model serving\n- Integration with existing systems\n- A/B testing and gradual rollout\n\n## Monitoring & Maintenance\n- Model performance monitoring\n- Data drift detection\n- Retraining pipeline automation\n- Continuous improvement process	\N	2025-10-15 13:04:57.56458	Initial version
07f6204f-d9a8-4be5-8491-4ac9137d530c	a4a23470-0ec5-420e-897f-4ba65647a409	1	# Two-Week Sprint Cycle\n\n## Sprint Planning (Day 1)\n- Review and prioritize backlog items\n- Define sprint goals and commitments\n- Break down user stories into tasks\n- Estimate effort and assign work\n\n## Daily Standups (15 minutes)\n- What did I complete yesterday?\n- What will I work on today?\n- Are there any blockers?\n\n## Development & Testing (Days 2-9)\n- Feature development\n- Unit and integration testing\n- Code reviews and pair programming\n- Continuous integration\n\n## Sprint Review/Demo (Day 10 - Morning)\n- Demonstrate completed features\n- Gather stakeholder feedback\n- Accept or reject user stories\n- Update product backlog\n\n## Sprint Retrospective (Day 10 - Afternoon)\n- What went well?\n- What could be improved?\n- Action items for next sprint\n- Team building and celebration	\N	2025-10-15 13:04:57.56458	Initial version
ac58ebf0-4a78-4114-9840-3690aea5f153	f5d88b33-4350-460f-bc46-9b783f12fde8	1	# Executive Summary\n\n[Client Name] has engaged Khonology to [brief description of project objective]. This proposal outlines our approach to delivering [key outcomes] through [solution approach].\n\n## Business Challenge\n[Client Name] is currently facing [describe business challenge or opportunity]. This situation is impacting [business impact areas] and requires [type of solution needed].\n\n## Proposed Solution\nKhonology proposes to [high-level solution description]. Our approach leverages [key technologies/methodologies] to deliver [specific benefits].\n\n## Key Benefits\n- **[Benefit 1]**: [Description and quantified impact]\n- **[Benefit 2]**: [Description and quantified impact]\n- **[Benefit 3]**: [Description and quantified impact]\n\n## Investment & Timeline\nThe total investment for this engagement is **$[Amount]** with an estimated timeline of **[X] weeks/months**. The project will be delivered in [number] phases with key milestones at [milestone descriptions].\n\n## Why Khonology\nKhonology brings [X] years of experience in [relevant domain], having successfully delivered [number] similar projects. Our team combines deep technical expertise with industry knowledge to ensure successful outcomes.\n\n## Next Steps\nUpon approval, we can commence the engagement within [timeframe], with initial deliverables available by [date].	\N	2025-10-15 13:04:57.56458	Initial version
3a6694ce-1e01-4d48-a12a-fa9549a432e3	1ec37a46-19fd-4e2f-ae81-1e9782b0f5a8	1	# Scope & Deliverables\n\n## Project Scope\n\n### In Scope\nThe following activities and deliverables are included in this engagement:\n\n1. **[Deliverable Category 1]**\n   - [Specific deliverable 1.1]\n   - [Specific deliverable 1.2]\n   - [Specific deliverable 1.3]\n\n2. **[Deliverable Category 2]**\n   - [Specific deliverable 2.1]\n   - [Specific deliverable 2.2]\n   - [Specific deliverable 2.3]\n\n3. **[Deliverable Category 3]**\n   - [Specific deliverable 3.1]\n   - [Specific deliverable 3.2]\n   - [Specific deliverable 3.3]\n\n### Out of Scope\nThe following items are explicitly excluded from this engagement:\n- [Out of scope item 1]\n- [Out of scope item 2]\n- [Out of scope item 3]\n\n## Key Deliverables\n\n| Deliverable | Description | Format | Due Date |\n|------------|-------------|---------|----------|\n| [Deliverable 1] | [Description] | [Format] | [Date] |\n| [Deliverable 2] | [Description] | [Format] | [Date] |\n| [Deliverable 3] | [Description] | [Format] | [Date] |\n\n## Acceptance Criteria\nEach deliverable will be considered complete when:\n- All specified functionality is implemented and tested\n- Documentation is provided as outlined\n- Client acceptance testing is successfully completed\n- Any defects are resolved or documented for future phases	\N	2025-10-15 13:04:57.56458	Initial version
acab933c-96a0-4ae9-b77d-9f2efc2278ca	d4ab1e77-eb00-4034-b3db-486be78b54aa	1	# Project Team\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] brings extensive experience in [key expertise areas]. Notable projects include [brief project descriptions]. [He/She] holds [relevant certifications] and has deep expertise in [technologies/methodologies].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]\n\n---\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] specializes in [key expertise areas] with a proven track record of [achievements]. [He/She] has led [number] successful implementations and brings expertise in [specific skills].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]\n\n---\n\n## [Name] - [Role]\n**Experience**: [X] years in [domain/technology]\n\n[Name] is an expert in [key expertise areas] with experience across [industries/domains]. [He/She] has successfully delivered [types of projects] and holds [certifications/degrees].\n\n**Key Qualifications**:\n- [Qualification 1]\n- [Qualification 2]\n- [Qualification 3]	\N	2025-10-15 13:04:57.56458	Initial version
9eae1a94-bddd-45b5-91ae-cae33f4328de	3b3324fb-a3d0-45a3-a87f-59d2d921fe35	1	# Investment\n\n## Total Investment: $[Amount]\n\n### Cost Breakdown\n\n| Category | Description | Cost |\n|----------|-------------|------|\n| Professional Services | [X] hours @ $[rate]/hour | $[amount] |\n| Project Management | [X] hours @ $[rate]/hour | $[amount] |\n| Infrastructure Setup | One-time setup costs | $[amount] |\n| Third-Party Licenses | [Description] | $[amount] |\n| **Total** | | **$[amount]** |\n\n### Payment Schedule\n\n| Milestone | Deliverables | Amount | Due Date |\n|-----------|--------------|--------|----------|\n| Contract Signing | 30% deposit | $[amount] | Upon signing |\n| Phase 1 Completion | [Deliverables] | $[amount] | [Date] |\n| Phase 2 Completion | [Deliverables] | $[amount] | [Date] |\n| Final Delivery | All deliverables | $[amount] | [Date] |\n\n### Expenses\nTravel and other expenses will be billed at cost with prior approval. Estimated expenses: $[amount]\n\n### Payment Terms\n- Invoices are due within 30 days of receipt\n- Late payments subject to 1.5% monthly interest\n- All amounts in USD\n\n### Assumptions\nThis investment is based on the scope outlined in this proposal. Any changes to scope will be managed through our formal change request process and may impact the total investment.	\N	2025-10-15 13:04:57.56458	Initial version
c94d415b-9a3b-4eb1-ac81-85365f9c99c2	5f03e8e1-9b9d-4e47-95f7-e69b17c0d5d4	1	# Client References - Financial Services\n\n## Global Bank - Digital Banking Platform\n**Client**: Major international bank (Fortune 500)\n**Project**: Complete digital banking platform transformation\n**Duration**: 18 months\n**Team Size**: 25 consultants\n\n**Challenge**: Legacy banking systems unable to support modern digital banking requirements\n\n**Solution**: Developed cloud-native digital banking platform with mobile-first design, real-time transaction processing, and AI-powered fraud detection\n\n**Results**:\n- 300% increase in digital banking adoption\n- 45% reduction in operational costs\n- 99.99% system uptime achieved\n- $50M annual cost savings\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## Investment Firm - Data Analytics Platform\n**Client**: Leading investment management firm\n**Project**: Enterprise data analytics and reporting platform\n**Duration**: 12 months\n**Team Size**: 15 consultants\n\n**Challenge**: Disparate data sources preventing unified investment insights\n\n**Solution**: Implemented centralized data lake with advanced analytics, machine learning models for investment predictions, and executive dashboards\n\n**Results**:\n- 80% faster reporting cycles\n- 25% improvement in investment decision accuracy\n- $30M additional revenue from data-driven insights\n\n**Reference Contact**: [Available upon request]	\N	2025-10-15 13:04:57.56458	Initial version
60b73484-54dd-45f4-9008-db0d5e83c1c1	c32d0ac5-8915-478c-8ce8-d58a8db14b03	1	# Client References - Healthcare\n\n## Regional Hospital Network - EHR Integration\n**Client**: 15-hospital regional healthcare network\n**Project**: Electronic Health Record (EHR) system integration\n**Duration**: 24 months\n**Team Size**: 30 consultants\n\n**Challenge**: Fragmented patient records across multiple systems impacting care quality\n\n**Solution**: Integrated EHR systems across all facilities with unified patient portal, interoperability standards (FHIR), and clinical decision support\n\n**Results**:\n- 60% reduction in duplicate tests\n- 40% improvement in care coordination\n- 95% physician satisfaction rate\n- HIPAA and HITECH compliance achieved\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## Pharmaceutical Company - Clinical Trials Platform\n**Client**: Global pharmaceutical company\n**Project**: Clinical trials management platform\n**Duration**: 16 months\n**Team Size**: 20 consultants\n\n**Challenge**: Manual clinical trial processes causing delays and compliance risks\n\n**Solution**: Developed automated clinical trials platform with patient recruitment, data collection, regulatory reporting, and AI-powered adverse event detection\n\n**Results**:\n- 50% faster trial completion\n- 90% reduction in data entry errors\n- FDA 21 CFR Part 11 compliance\n- $40M cost savings in trial operations\n\n**Reference Contact**: [Available upon request]	\N	2025-10-15 13:04:57.56458	Initial version
39e05ee3-d3c8-4fce-9515-08f1b8ecb2c9	7d23e13f-6835-4811-872c-69ac7904bab5	1	# Client References - Retail & E-commerce\n\n## National Retailer - Omnichannel Platform\n**Client**: Top 10 US retailer\n**Project**: Omnichannel commerce platform\n**Duration**: 20 months\n**Team Size**: 35 consultants\n\n**Challenge**: Disconnected online and in-store experiences losing customers to competitors\n\n**Solution**: Built unified commerce platform with real-time inventory, buy-online-pickup-in-store (BOPIS), personalized recommendations, and mobile app\n\n**Results**:\n- 200% increase in online sales\n- 35% improvement in customer satisfaction\n- 50% reduction in inventory carrying costs\n- $100M additional annual revenue\n\n**Reference Contact**: [Available upon request]\n\n---\n\n## E-commerce Startup - Scalable Platform\n**Client**: Fast-growing e-commerce startup\n**Project**: Scalable cloud infrastructure and platform\n**Duration**: 10 months\n**Team Size**: 12 consultants\n\n**Challenge**: Existing platform unable to handle rapid growth and traffic spikes\n\n**Solution**: Migrated to cloud-native architecture with auto-scaling, microservices, CDN, and DevOps automation\n\n**Results**:\n- 10x traffic capacity increase\n- 99.95% uptime during peak seasons\n- 70% reduction in infrastructure costs\n- Successful Black Friday with zero downtime\n\n**Reference Contact**: [Available upon request]	\N	2025-10-15 13:04:57.56458	Initial version
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, title, message, type, resource_type, resource_id, created_at, read_at, is_read, action_url, metadata, proposal_id, notification_type) FROM stdin;
0af38bfb-e28c-4283-8101-c60b90830861	22	New Comment	Sipho Nkosi commented	comment_added	comment_added	\N	2025-11-11 13:38:19.821501+02	\N	f	\N	{"comment_id": 41, "section_index": null}	44	comment_added
9f617974-71ae-4e70-b52e-4a322961391c	22	You were mentioned	Sipho Nkosi mentioned you in a comment	mentioned	mentioned	\N	2025-11-11 13:38:23.762141+02	\N	f	\N	{"comment_id": 41, "mentioned_by": 16}	44	mentioned
03092f92-12a5-4c29-8a39-f705254dc8eb	22	New Comment	Sipho Nkosi commented	comment_added	comment_added	\N	2025-11-11 13:58:52.512595+02	\N	f	\N	{"comment_id": 42, "section_index": null}	44	comment_added
e72aaa3a-3318-44bd-8f3d-78d5fe74b016	22	You were mentioned	Sipho Nkosi mentioned you in a comment	mentioned	mentioned	\N	2025-11-11 13:58:57.138354+02	\N	f	\N	{"comment_id": 42, "mentioned_by": 16}	44	mentioned
0c4dd181-34e1-4588-9f0c-b7101fac6473	16	Proposal Approved	Zukhanye Baloyi approved the proposal 'Untitled Document' and sent it to the client.	proposal_approved	proposal_approved	\N	2025-11-11 16:35:16.608011+02	\N	f	\N	{"action": "approved", "status": "Sent to Client", "approver_id": 22, "proposal_id": 44, "proposal_title": "Untitled Document"}	44	proposal_approved
d0310c36-d769-4e2a-9175-5a0796ec4432	22	New Comment	Unathi Sibanda commented	comment_added	comment_added	47	2025-11-13 10:10:59.504044+02	\N	f	\N	{"comment_id": 43, "proposal_id": 47, "resource_id": 47, "section_index": null, "proposal_title": "Untitled Document"}	47	comment_added
fe5b7460-83ed-4708-8dbe-b122bd7c99f4	22	You were mentioned	Unathi Sibanda mentioned you in a comment	mentioned	mentioned	47	2025-11-13 10:11:03.070807+02	\N	f	\N	{"comment_id": 43, "mentioned_by": 13}	47	mentioned
377722f4-1207-4fd0-9014-fc66de9cda24	13	New Comment	Zukhanye Baloyi commented	comment_added	comment_added	47	2025-11-13 10:11:57.994154+02	\N	f	\N	{"comment_id": 44, "proposal_id": 47, "resource_id": 47, "section_index": null, "proposal_title": "Untitled Document"}	47	comment_added
1fabe2fc-b62e-4e26-9743-0967ec76bae2	13	Proposal Approved	Zukhanye Baloyi approved the proposal 'Untitled Document' and sent it to the client.	proposal_approved	proposal_approved	47	2025-11-13 10:17:37.925279+02	\N	f	\N	{"action": "approved", "status": "Sent to Client", "approver_id": 22, "proposal_id": 47, "resource_id": 47, "proposal_title": "Untitled Document"}	47	proposal_approved
\.


--
-- Data for Name: proposal_client_activity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_client_activity (id, proposal_id, client_id, event_type, metadata, created_at) FROM stdin;
1	65	\N	open	{}	2025-11-19 15:54:58.153435
2	65	\N	close	{}	2025-11-19 15:59:54.853044
3	63	\N	open	{}	2025-11-19 16:00:01.63975
4	63	\N	close	{}	2025-11-19 16:00:15.834448
5	65	\N	open	{}	2025-11-19 16:10:23.81733
6	65	\N	open	{}	2025-11-19 16:14:44.738697
7	65	\N	open	{}	2025-11-19 16:34:47.105106
8	66	\N	open	{}	2025-11-19 16:45:22.803839
9	66	\N	close	{}	2025-11-19 17:02:28.113811
10	68	\N	open	{}	2025-11-19 17:03:15.702198
11	68	\N	open	{}	2025-11-19 17:16:27.968618
12	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:16:31.831263
13	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:20:47.569863
14	68	\N	open	{}	2025-11-19 17:24:43.993047
15	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:24:47.303051
16	68	\N	open	{}	2025-11-19 17:30:18.403087
17	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:30:22.733967
18	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:31:25.844351
19	68	\N	open	{}	2025-11-19 17:37:02.033593
20	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:37:05.327071
21	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:37:35.994294
22	68	\N	close	{}	2025-11-19 17:38:19.011442
23	66	\N	open	{}	2025-11-19 17:38:21.349469
24	66	\N	close	{}	2025-11-19 17:38:29.733059
25	68	\N	open	{}	2025-11-19 17:38:32.44494
26	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:38:35.129113
27	68	\N	close	{}	2025-11-19 17:43:39.534011
28	68	\N	open	{}	2025-11-19 17:43:58.194396
29	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:44:00.835641
30	68	\N	open	{}	2025-11-19 17:52:29.593103
31	68	\N	sign	{"action": "signing_modal_opened"}	2025-11-19 17:52:31.732959
32	68	\N	open	{}	2025-11-19 18:03:33.120796
33	68	\N	open	{}	2025-11-19 18:09:23.802602
34	68	\N	close	{}	2025-11-19 18:10:16.526364
35	68	\N	open	{}	2025-11-19 18:10:51.686706
36	68	\N	open	{}	2025-11-19 18:15:46.292373
37	68	\N	open	{}	2025-11-19 18:22:46.935529
38	68	\N	open	{}	2025-11-25 12:11:24.636136
39	67	\N	open	{}	2025-11-25 12:14:49.354627
40	67	\N	close	{}	2025-11-25 13:04:18.853884
41	64	\N	open	{}	2025-11-25 13:04:23.866419
42	64	\N	close	{}	2025-11-25 13:04:28.466644
43	68	\N	open	{}	2025-11-25 13:04:30.880283
44	67	\N	open	{}	2025-11-25 13:13:56.862652
45	67	\N	close	{}	2025-11-25 13:14:09.398994
46	68	\N	open	{}	2025-11-25 13:14:11.863909
47	68	\N	open	{}	2025-11-25 13:14:48.156771
48	67	\N	open	{}	2025-11-25 13:50:22.314018
49	67	\N	close	{}	2025-11-25 13:50:26.585123
50	68	\N	open	{}	2025-11-25 13:50:29.22008
51	69	\N	open	{}	2025-11-26 10:01:41.075275
52	70	\N	open	{}	2025-11-26 10:15:52.188367
53	71	\N	open	{}	2025-11-26 10:36:29.15066
54	67	\N	open	{}	2025-11-26 12:57:52.801334
55	67	\N	close	{}	2025-11-26 12:57:58.368127
56	68	\N	open	{}	2025-11-26 12:58:02.22004
57	72	\N	open	{}	2025-11-26 16:01:13.527068
58	72	\N	close	{}	2025-11-26 16:01:34.343693
59	73	\N	open	{}	2025-11-26 16:56:14.827627
60	73	\N	open	{}	2025-11-26 17:12:26.739405
61	73	\N	open	{}	2025-11-26 17:12:56.799258
62	74	\N	open	{}	2025-11-26 17:28:36.231137
\.


--
-- Data for Name: proposal_client_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_client_session (id, proposal_id, client_id, session_start, session_end, total_seconds, created_at) FROM stdin;
1	65	\N	2025-11-19 15:54:57.992485	2025-11-19 15:59:55.1115	297	2025-11-19 15:54:57.992485
2	63	\N	2025-11-19 16:00:01.097396	2025-11-19 16:00:15.96442	14	2025-11-19 16:00:01.097396
3	65	\N	2025-11-19 16:10:23.277823	\N	\N	2025-11-19 16:10:23.277823
4	65	\N	2025-11-19 16:14:44.139515	\N	\N	2025-11-19 16:14:44.139515
5	65	\N	2025-11-19 16:34:46.795584	\N	\N	2025-11-19 16:34:46.795584
6	66	\N	2025-11-19 16:45:22.747225	2025-11-19 17:02:28.285239	1025	2025-11-19 16:45:22.747225
7	68	\N	2025-11-19 17:03:15.576557	\N	\N	2025-11-19 17:03:15.576557
8	68	\N	2025-11-19 17:16:27.656299	\N	\N	2025-11-19 17:16:27.656299
9	68	\N	2025-11-19 17:24:43.676846	\N	\N	2025-11-19 17:24:43.676846
10	68	\N	2025-11-19 17:30:18.090685	\N	\N	2025-11-19 17:30:18.090685
11	68	\N	2025-11-19 17:37:01.56551	2025-11-19 17:38:18.826887	77	2025-11-19 17:37:01.56551
12	66	\N	2025-11-19 17:38:21.031076	2025-11-19 17:38:29.641184	8	2025-11-19 17:38:21.031076
13	68	\N	2025-11-19 17:38:31.96741	2025-11-19 17:43:39.369723	307	2025-11-19 17:38:31.96741
14	68	\N	2025-11-19 17:43:58.381125	\N	\N	2025-11-19 17:43:58.381125
15	68	\N	2025-11-19 17:52:29.43035	\N	\N	2025-11-19 17:52:29.43035
16	68	\N	2025-11-19 18:03:32.811126	\N	\N	2025-11-19 18:03:32.811126
17	68	\N	2025-11-19 18:09:23.495441	2025-11-19 18:10:16.659049	53	2025-11-19 18:09:23.495441
18	68	\N	2025-11-19 18:10:51.497808	\N	\N	2025-11-19 18:10:51.497808
19	68	\N	2025-11-19 18:15:45.971303	\N	\N	2025-11-19 18:15:45.971303
20	68	\N	2025-11-19 18:22:46.622446	\N	\N	2025-11-19 18:22:46.622446
21	68	\N	2025-11-25 12:11:24.30839	\N	\N	2025-11-25 12:11:24.30839
22	67	\N	2025-11-25 12:14:49.047318	2025-11-25 13:04:19.124769	2970	2025-11-25 12:14:49.047318
23	64	\N	2025-11-25 13:04:23.405727	2025-11-25 13:04:28.361688	4	2025-11-25 13:04:23.405727
24	68	\N	2025-11-25 13:04:31.03626	\N	\N	2025-11-25 13:04:31.03626
25	67	\N	2025-11-25 13:13:56.694707	2025-11-25 13:14:09.277601	12	2025-11-25 13:13:56.694707
26	68	\N	2025-11-25 13:14:11.548475	\N	\N	2025-11-25 13:14:11.548475
27	68	\N	2025-11-25 13:14:47.703066	\N	\N	2025-11-25 13:14:47.703066
28	67	\N	2025-11-25 13:50:22.002709	2025-11-25 13:50:26.477337	4	2025-11-25 13:50:22.002709
29	68	\N	2025-11-25 13:50:28.746876	\N	\N	2025-11-25 13:50:28.746876
30	69	\N	2025-11-26 10:01:40.868938	\N	\N	2025-11-26 10:01:40.868938
31	70	\N	2025-11-26 10:15:52.040229	\N	\N	2025-11-26 10:15:52.040229
32	71	\N	2025-11-26 10:36:28.677773	\N	\N	2025-11-26 10:36:28.677773
33	67	\N	2025-11-26 12:57:52.649476	2025-11-26 12:57:58.239839	5	2025-11-26 12:57:52.649476
34	68	\N	2025-11-26 12:58:01.874881	\N	\N	2025-11-26 12:58:01.874881
35	72	\N	2025-11-26 16:01:13.378406	2025-11-26 16:01:34.595242	21	2025-11-26 16:01:13.378406
36	73	\N	2025-11-26 16:56:14.521562	\N	\N	2025-11-26 16:56:14.521562
37	73	\N	2025-11-26 17:12:27.056675	\N	\N	2025-11-26 17:12:27.056675
38	73	\N	2025-11-26 17:12:56.490041	\N	\N	2025-11-26 17:12:56.490041
39	74	\N	2025-11-26 17:28:35.646692	\N	\N	2025-11-26 17:28:35.646692
\.


--
-- Data for Name: proposal_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_feedback (id, proposal_id, client_id, feedback_text, rating, created_at) FROM stdin;
\.


--
-- Data for Name: proposal_signatures; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_signatures (id, proposal_id, envelope_id, signer_name, signer_email, signer_title, status, signing_url, sent_at, signed_at, declined_at, decline_reason, signed_document_url, created_by) FROM stdin;
1	35	ca48a921-a856-40f7-ab4b-2f2ed735021a	Unathi	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/32f74a6d-6012-4bf8-87f0-fc575f0b51b7?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCA4hYFHxfeSAgAgIIojEAX3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTAtMjlUMTk6MTY6NTIrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTAtMjlUMTk6MTE6NTMuMTM1NDI1NyswMDowMCIsIlJlc291cmNlSWQiOiJjYTQ4YTkyMS1hODU2LTQwZjctYWI0Yi0yZjJlZDczNTAyMWEiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJjYTQ4YTkyMS1hODU2LTQwZjctYWI0Yi0yZjJlZDczNTAyMWFcIixcIkFjdG9yVXNlcklkXCI6XCJhYjFkZGVkNC00ZjFkLTRlMzItODY4OC1jY2MzYWYyNjI2ZmJcIixcIlJlY2lwaWVudElkXCI6XCJlNTQ2OWFlOS0wYzM5LTQxMGYtOTk3NC0xZTAxYzE0NTVlMTJcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD05NmVlN2NjMy01YjhmLTQ3MTAtOThmMS00YTljNDcwNThkNTZcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEwLTI5VDE5OjExOjUyLjg2Mjc2MjlaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgBO2th8X3kg.gDp3TdOdscLUk9jrea2LDMgXBuUFvTOFGYHo6sJvmmuW3VPB8kWOgcZHwdYTHhQhpKhjKXFqw7oTCdgUjgvXkk6yHoge-h9zeqkR8ARvpHrfnai6bSpUEi3eCjcpI3a8FbPgkNo3rLAa6E8ZEacOB5laq_5KDz5TYDDtrjxsukP7lrtgujjuMSKg44zhB9cgQvQ2RMuzzy3hbXSFaB9himjDLLBWRIeeeo6LXyGXml2VVwZGsZICkEWQaUiqbSNTcm9DP_O6MVscmLWgHpWRb2o79sKr-f0wYIPXxGVnokakynAZRUN2byZ2cRbJsPRhNp_mwiTbSWU4__dWxQ_iXQ	2025-10-29 21:11:45.970395	\N	\N	\N	\N	22
2	35	87ed819e-39f5-4502-95d5-3eda19a3df6e	Unathi	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/97cce619-d867-4fc4-b826-3086b1820145?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAADI0aIRfeSAgAAKyeoUIX3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTAtMjlUMTk6MzE6NDgrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTAtMjlUMTk6MjY6NDguOTYwOTk4MyswMDowMCIsIlJlc291cmNlSWQiOiI4N2VkODE5ZS0zOWY1LTQ1MDItOTVkNS0zZWRhMTlhM2RmNmUiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI4N2VkODE5ZS0zOWY1LTQ1MDItOTVkNS0zZWRhMTlhM2RmNmVcIixcIkFjdG9yVXNlcklkXCI6XCJhYjFkZGVkNC00ZjFkLTRlMzItODY4OC1jY2MzYWYyNjI2ZmJcIixcIlJlY2lwaWVudElkXCI6XCI3ZDE5YTRkMS00YzBiLTQ2NTItODdlYi1iNGVmZjMyMTdmMjRcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD1jZTBiYmRiYi1hOWQzLTRhNTAtYmE2MC05YmNiYTc3OTJjYTdcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEwLTI5VDE5OjI2OjQ4LjgzNTQ3MTlaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgNPEzCEX3kg.DINilqEhYcRXeZd1KGkaRoEbhZWNe54HBWWc0G0BhtHVF9TIAZkd9sENoll9K9-h4uIF91RKwgHfU1IZpPyBZ3MbXcpoL78bVpK7KZGvuuJWYB2NQUEiq_OpiLePvw5T6u8jxafaQkW_CtEtTiVEp8fiHwV64iDe0HEj4Dat48WxJKYEtdACHqBgp74kYD1cwfaPBIXsN2HkUAPik0Lp72ID4-rAMzyfdmIPWiBnZGx59nHx7s3OO6c_ZV-tw-77cSeFPawdDZwzela7R0fC52njTBBCQhgpJr5GhBVuJ6B6rcj60afH1lR3U0-N-i3fS_uXzw7KdWOs-Mfcw9Zf1A	2025-10-29 21:26:42.127613	\N	\N	\N	\N	22
3	36	a1d598e4-a8ec-4eb1-af81-59266eae3a3d	unathiInc	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/bc5269fd-7537-4ae8-bae8-90cb41c53a2e?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAA7RRMcRjeSAgAAI0m05IY3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTAtMzFUMTE6Mzg6MjIrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTAtMzFUMTE6MzM6MjIuODM3OTAzNCswMDowMCIsIlJlc291cmNlSWQiOiJhMWQ1OThlNC1hOGVjLTRlYjEtYWY4MS01OTI2NmVhZTNhM2QiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJhMWQ1OThlNC1hOGVjLTRlYjEtYWY4MS01OTI2NmVhZTNhM2RcIixcIkFjdG9yVXNlcklkXCI6XCI4ZTMxMmI1Yy1iNWE5LTQxYTItYWFlNS01ODM1ZjFjMzEyZmRcIixcIlJlY2lwaWVudElkXCI6XCIzYThiNDBhMy0yYzlkLTRlNDktYmJjZS1lZmRjYTZlY2VkYjJcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD04NGU5MjA1Yi1kZDJiLTQ5NWMtYWI4Mi0yZmNhODgwODlhNmZcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEwLTMxVDExOjMzOjIyLjcyNTc1MDNaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgLRM_nEY3kg.HDbIqtCSE9Q3MU8LcXw6c_ZEP0ogUmvor0nPAVcYEf9pSXGQ_nmIwbUtxv0HiVVMQ5p2KBh-me2ER3Ly5fKaNSwAkY6CLTRsZ3sOj_XXSXtEW97F5j-Ykv8q6EDwXoJzaUir4GgK5scm4hhw5b6GTrIFgu2KjPKAVupp9J7Ai1KS2tvY7MS12aRCQWzzqu6iUWOh-tcNMWsVKRzdANcIcwVMf5DEgIZVxM5bQAb14j0P4WKTHnaAvG5o1GIQq1A9w_b6AfgD7cKq1NBVZMtXKD254q2R74qdZG5eWL1Upn2o0gARzTkFXOnvi1yspyzv2PWyYHsZx6LYemFR2RJAqQ	2025-10-31 13:33:14.367445	\N	\N	\N	\N	22
4	41	6285c57d-232c-4772-9dc6-a8775f10e61f	UnathiInc	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/5f74157d-2e3c-44ed-8db2-5f4c5a8b67f5?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCAr_ntvh_eSAgAgE8LdeAf3kgYAAEAAAAAAAAAIQDrAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMDlUMTg6NDE6NDMrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMDlUMTg6MzY6NDMuNzEyNTE3NyswMDowMCIsIlJlc291cmNlSWQiOiI2Mjg1YzU3ZC0yMzJjLTQ3NzItOWRjNi1hODc3NWYxMGU2MWYiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI2Mjg1YzU3ZC0yMzJjLTQ3NzItOWRjNi1hODc3NWYxMGU2MWZcIixcIkFjdG9yVXNlcklkXCI6XCI4ZTMxMmI1Yy1iNWE5LTQxYTItYWFlNS01ODM1ZjFjMzEyZmRcIixcIlJlY2lwaWVudElkXCI6XCI2N2UxNjkwNC1kYmNjLTQyNzUtYWY3Yi1jYTdiMzEzNDkwNzNcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD04MWQyZGZjOS0yM2NlLTRhYjctOGUyNi0xYWNlODA2Y2M1MTJcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTA5VDE4OjM2OjQzLjYzNjM4OFpcIn0iLCJUb2tlblR5cGUiOjEsIkF1ZGllbmNlIjoiMjVlMDkzOTgtMDM0NC00OTBjLThlNTMtM2FiMmNhNTYyN2JmIiwiUmVkaXJlY3RVcmkiOiJodHRwczovL2RlbW8uZG9jdXNpZ24ubmV0L1NpZ25pbmcvU3RhcnRJblNlc3Npb24uYXNweCIsIkhhc2hBbGdvcml0aG0iOjAsIkhhc2hSb3VuZHMiOjAsIlRva2VuU3RhdHVzIjowLCJJc1NpbmdsZVVzZSI6ZmFsc2V9PwAAdzGgvx_eSA.PyFFKIs6YpRxk7ZFDoMePoP6xBv_oM9pkM-0b3CZBdTnjW0Uie24G8JeoAA0drhV81luEcSvfjibRuP8QSNKehOsDpeL394CwODl4-gzDnB8R6imPKtoj_nD1YJODB97nw35ap481fJowBA2Lz97TaustCKbTRwX89SVKPa18Z83ruMz1hmwjdyU_jXhKx-tCIGLJi7M5Tz0F2jQ3f68Hhpcy6key1XEubv9wGvlpP45JE4iOzN06gdqu3spnKkh3aIrzHHihiPVQScf_y6l5GESzTdXtuz9fZtTC6mNqs45YIhE32BjaANBxlBUXXbTWNhy4a0b7QEm_vpWMwAXWQ	2025-11-09 20:36:43.824492	\N	\N	\N	\N	22
5	40	8c50f666-856a-49df-8ce6-8b05bf4c7d94	Standard Bank	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/4cc957f2-dba4-4cdd-8115-0c04f74c2677?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAA-zXpwB_eSAgAAJtHcOIf3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMDlUMTg6NTU6NTQrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMDlUMTg6NTA6NTQuOTU1MDEwNyswMDowMCIsIlJlc291cmNlSWQiOiI4YzUwZjY2Ni04NTZhLTQ5ZGYtOGNlNi04YjA1YmY0YzdkOTQiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI4YzUwZjY2Ni04NTZhLTQ5ZGYtOGNlNi04YjA1YmY0YzdkOTRcIixcIkFjdG9yVXNlcklkXCI6XCJkZDFjMmI0Ni1hN2ZiLTQzNWItOGI1Yy0wZWVlNjI0NWU0MTRcIixcIlJlY2lwaWVudElkXCI6XCJhYWNiOGVjNS0xOWM3LTQ2NDgtYjNmYi04MzJmYWYzMzRhMzdcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD01YTgyYTMzMS0yYTg0LTQ2ZWMtYTcxNS01NTZlNzA2Y2E0ZTlcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTA5VDE4OjUwOjU0Ljg3NTY4MDFaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgMJtm8Ef3kg.ZO2VYONRMfvIi_MSz8R3HFIUZbfwI034OS4YJGyhl7UcMRQmw7xO0ycGXoIW8Nidy84EwaNAc6nyUfpysFITMtbnxyjpnDOBf-CQTVrbfkaYbxaF4l_uNqW_jvfp6YrPXg-wnQtwlK0HMOyFDuipwwPTVTCz-nW1-z1UZRQnW39Y4rOgIU8PYxkFd1SHGn4akN7If-u9pqEtR8cW6pivjGrfzeULgttGQ1U2rYun63Mq6UO0KRukY7lzAonkESlIxXzvThywUyBe7W2GyBq0kHWbMUWR4hmiX-cllLYBZUpMITkYID5ORdxX0a76OoWEgQhbkA1aT8KEYhtjOEhl4Q	2025-11-09 20:50:55.083453	\N	\N	\N	\N	22
6	43	6cae8671-5c4b-4128-9082-0c37c7b8a134	Unathi	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/68c7e7bc-d669-49bd-b828-739054cabbea?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCA7ZR1wh_eSAgAgI2m_OMf3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMDlUMTk6MDY6NTkrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMDlUMTk6MDE6NTkuOTQ3NDE5NSswMDowMCIsIlJlc291cmNlSWQiOiI2Y2FlODY3MS01YzRiLTQxMjgtOTA4Mi0wYzM3YzdiOGExMzQiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI2Y2FlODY3MS01YzRiLTQxMjgtOTA4Mi0wYzM3YzdiOGExMzRcIixcIkFjdG9yVXNlcklkXCI6XCJhYjFkZGVkNC00ZjFkLTRlMzItODY4OC1jY2MzYWYyNjI2ZmJcIixcIlJlY2lwaWVudElkXCI6XCJiNzRiOTZlMi03OTJmLTQ1NjAtODFjMy1mMWIyMGU4YmM1NjRcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD02ZTU4MzkxMC0wMjU1LTRiMDUtYWVlZC0zN2JmNmE3Mjk0ZTBcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTA5VDE5OjAxOjU5Ljg2ODEzMTNaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AALXMJ8Mf3kg.bor9-oVcijBjt0vr_x6hmPyZTdlhNmyGmPPvNg6qISl4c1JxHClWPmCt9I4qqV6XxjvySzxWI6aIRrx_VQm-J9pO7n4pjJimysnU0SJBU8gKLW1tWGpNWEZ_EvtsqO3nXiBmP_3ii0MjecJ5MxGmz-YcxSKhEFXVe3M6zUlDsZJfcAk4PmU8v767iXANVDx0dTTMcMDIzdQjCjZn5yocZOyWuGRsE-LVoyx_IvrCfKgDoeWd_mAEX_TrxCikcw3cvcV9dMIEgyvTlWDgwfHZK-DWqKeHT5d1Gtz11QnYP0ZkRw-_uCDLbzgC2y3acU2PvvY54-kzM9ZpIZg4WBmNYg	2025-11-09 21:01:52.465552	\N	\N	\N	\N	22
7	45	101293c0-4693-4ffa-ae16-15de97e70fb0	ZukhanyeInc	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/675fba22-4333-4d04-818c-1032b1f67b98?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAAwDdDwx_eSAgAAGBJyuQf3kgYAAEAAAAAAAAAIQDrAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMDlUMTk6MTI6NDMrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMDlUMTk6MDc6NDQuMDE3MzIwNSswMDowMCIsIlJlc291cmNlSWQiOiIxMDEyOTNjMC00NjkzLTRmZmEtYWUxNi0xNWRlOTdlNzBmYjAiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCIxMDEyOTNjMC00NjkzLTRmZmEtYWUxNi0xNWRlOTdlNzBmYjBcIixcIkFjdG9yVXNlcklkXCI6XCJlNGRhMzFiYS1jMWU0LTRiN2UtOGE5Yi0wZmI5MjYzZTFkZTZcIixcIlJlY2lwaWVudElkXCI6XCJhNDk3ODRhZC1iYjNkLTQ4NTctODQwZS02OTZiMGFkYzBlYTZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD0zMGZlZGEzNS00NWQyLTQwZWItYjFjYi00MGRkZGZkMjkxMzRcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTA5VDE5OjA3OjQzLjg2OTMyNFpcIn0iLCJUb2tlblR5cGUiOjEsIkF1ZGllbmNlIjoiMjVlMDkzOTgtMDM0NC00OTBjLThlNTMtM2FiMmNhNTYyN2JmIiwiUmVkaXJlY3RVcmkiOiJodHRwczovL2RlbW8uZG9jdXNpZ24ubmV0L1NpZ25pbmcvU3RhcnRJblNlc3Npb24uYXNweCIsIkhhc2hBbGdvcml0aG0iOjAsIkhhc2hSb3VuZHMiOjAsIlRva2VuU3RhdHVzIjowLCJJc1NpbmdsZVVzZSI6ZmFsc2V9PwAA8db0wx_eSA.FrnvhhQ8X2gDMoNVsffhMAanaPXBRJWWdf2z_Pmet1lUgtO93IwxXC9VrpKzdoIG6CzMux3Rkjs8gE5oXs0tjauIgBdOWrEg_CDYTcthLLbUy_76wRKYIBXENoYnvOlghxBs3CyHZT5mro6xBtCC_KXlEob0ngNNWJG7Qdsra1KNTrV5Hc4aAhRW003TlOf7dD6dLar87AXLgYI7HDsgXcdGqcNn5QjcUiJDVx0NGJqJ8hm2a0IGEuzSQqSZByPt_USL5Z3UjyrCh0EY5o_TY57JfhK_TZkkAGGUiuq2Awn0DBIMQ7ZCzkKOyetayrfJXYxWTOlxwxg-O7DenOZPpQ	2025-11-09 21:07:44.15226	\N	\N	\N	\N	22
8	44	2f459375-6249-4032-9a8e-827ef284bd05	Braids	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/0f487991-3213-4b87-a723-4333c2780193?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAAeAePLyHeSAgAABgZFlEh3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMTFUMTQ6NDA6MjcrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMTFUMTQ6MzU6MjguMDMxMTgxOSswMDowMCIsIlJlc291cmNlSWQiOiIyZjQ1OTM3NS02MjQ5LTQwMzItOWE4ZS04MjdlZjI4NGJkMDUiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCIyZjQ1OTM3NS02MjQ5LTQwMzItOWE4ZS04MjdlZjI4NGJkMDVcIixcIkFjdG9yVXNlcklkXCI6XCJiM2RhZDY2Yy00MjBkLTRlY2QtOWM4YS02YTJkODBlNjAxYmFcIixcIlJlY2lwaWVudElkXCI6XCJmMGMyNDJjMC0zNDUyLTRhZTktOTA4OS1kMzA4Yjk2ZTczOGRcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD04YjFjZjczNy1kMmMzLTQ5NzItOWE5Ny0xZjBmNjFmY2E4NDVcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTExVDE0OjM1OjI3Ljg3Mjc2OTJaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AAKmmQDAh3kg.Sr6ylvAxYP7RssOE8rCivvf1dfUKVNG5ID4scpjrLgprdKVjMGQmiiuOe4PeoVfCEFczILQ-UXfM2kCjfKN1XuW1u8N9n6CNni-ZUjVvfjohYkdn9OAEPCuIMx3sHadF9RjBFZ0ZtsM_2GpjlClkdh6S2tjyGukQwz6nQmnxOH64IMSr3w8QVi9oxifoBa2FL8-jpVwMj6ALQNLoeccITfqz-aVwvMN-pg2XWcrlGF1CjzMXg8izozLJ5F5Hh_pxGiFLDmVsH1KGF54_BbJmhi7oG8IUmS1y2WrlSlGJdtaJ5g2ZtDRLVt2sXl_FshbKNQ7luF5GResMTXiJos_A8w	2025-11-11 16:35:28.251808	\N	\N	\N	\N	22
9	46	14a7ff48-3de1-4940-8e8d-da21e9bca35e	Unathi	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/e8b50414-596d-4991-b429-4994eafe6d6b?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAA8TCxKCLeSAgAAJFCOEoi3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMTJUMjA6MjM6NTArMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMTJUMjA6MTg6NTAuODc3NDA5NSswMDowMCIsIlJlc291cmNlSWQiOiIxNGE3ZmY0OC0zZGUxLTQ5NDAtOGU4ZC1kYTIxZTliY2EzNWUiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCIxNGE3ZmY0OC0zZGUxLTQ5NDAtOGU4ZC1kYTIxZTliY2EzNWVcIixcIkFjdG9yVXNlcklkXCI6XCJhYjFkZGVkNC00ZjFkLTRlMzItODY4OC1jY2MzYWYyNjI2ZmJcIixcIlJlY2lwaWVudElkXCI6XCI2NzBmZDcwMy0xNjVhLTRjOWEtODhiZC1iMTEzOTE3NzNiMTFcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD0yOTQyNDgyNy05YmNmLTRhNWUtYjcyNi1jOTMwZDQyMmIwNDBcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTEyVDIwOjE4OjUwLjc0MzQ3NDRaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgLhoYyki3kg.MeT8tommgff910OVtew7lQHM1kWjVmzLmRhMMXtiHND2KKoOC8o76-pwAL4oENSUs7rO9SzH7rqo8teBWSkXu1nYK9ERt5vaOyb-5aHs7Y-80C1uCD3DkbjvQ6ziMwDLoRT6dw4oEV1WHf1VgZ8qI6TKSSkJniwpc_M2wridcv5ZTUDlGpzbalCZwQSg9zVvjshBMkl25I8qnWAvtRrC6iPAvGxcy65_FzUp3ErwkOGzSCMoc7tcyyLSttQlWTMqJnNWPl7lsDdPFU6-tYFfzzCjYx2ZVPgu2LAdMBTEKptd8DBaMjiXnylKwwOqHXmyGwFpD0Kgj1c9I4WNSNGW-g	2025-11-12 22:18:51.01825	\N	\N	\N	\N	22
10	47	c344198c-ff34-8ce1-819a-8868d9b80dec	CCME	umsibanda.1994@gmail.com	\N	sent	https://demo.docusign.net/Signing/MTRedeem/v1/e6451a95-5084-4c08-aacc-31321eda3b12?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCAx9ggjSLeSAgAgGfqp64i3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMTNUMDg6MjI6NDcrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMTNUMDg6MTc6NDcuODY3NjM1MyswMDowMCIsIlJlc291cmNlSWQiOiJjMzQ0MTk4Yy1mZjM0LThjZTEtODE5YS04ODY4ZDliODBkZWMiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJjMzQ0MTk4Yy1mZjM0LThjZTEtODE5YS04ODY4ZDliODBkZWNcIixcIkFjdG9yVXNlcklkXCI6XCJiMTM2ZGNhNi00N2QzLTQyZTgtOGEzMi1iOWUxNTZkOGExNzdcIixcIlJlY2lwaWVudElkXCI6XCIyOWJhMWQ3OS0yNmM5LTgxNWItODE5NC05MWIyYmViNzBkN2NcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD1lYWM4MTllOC02Yzc3LTgzMzUtODE1Ni02MDk0ZmNiMTBkMzRcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTEzVDA4OjE3OjQ3LjczNDExNTdaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AAI8Q040i3kg.1JiBP4_KM6r7Ya_f_b6UPALbBxSonpej06OwtnvCbJ5pX_5s340xzj0Or0uxCcR4DSIilYSEoTRmRPUsuslTyhOk5zGSbQvLXTE-q3IJE7ehgFFPiHbnZY-HvJV-DymQbXpRdfBH3AcMurHiqhyUvjiDlCIqDCIUGhsXtu2NHUMnbFvus27vOLtsy2luRJdFbtA83Yho3zGMsdBQsd7USm_NrJ-iZRRsUhu_WR97y9xP52NzLMVKKGF9xv2cIVCCnnmPbVSVF7iGA47q9zZzGzcewHpPTQw2T-wpIDFc3lLyNkzMOUCKDJriqPI93v-nv3ZdSZWKvSFNcOysAeA-aw	2025-11-13 10:17:48.155194	\N	\N	\N	\N	22
11	68	064b1637-daff-86bb-80f1-a01b32bf13ac	Dhlamini Corp	sheziluthando513@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/958976ed-328f-49b4-89ad-1393698a88bd?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCA-VAEfSfeSAgAgJlii54n3kgYAAEAAAAAAAAAIQDsAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMTlUMTU6MTA6MDMrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMTlUMTU6MDU6MDMuNTMzMzgyNyswMDowMCIsIlJlc291cmNlSWQiOiIwNjRiMTYzNy1kYWZmLTg2YmItODBmMS1hMDFiMzJiZjEzYWMiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCIwNjRiMTYzNy1kYWZmLTg2YmItODBmMS1hMDFiMzJiZjEzYWNcIixcIkFjdG9yVXNlcklkXCI6XCI4ZmE2ZDQ4Mi0yODkzLTRhZTEtYmM2OC1mMDUyZGM5NzliMzhcIixcIlJlY2lwaWVudElkXCI6XCI2ODU5MTgwOS0xNzFiLTgxZWEtODA0MS1lMzFiN2RiOTEzMjFcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD0zYmQxMTRiZS1lMTJjLThkMDEtODA2ZS0wYWFhNmJiNzEzNzVcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTE5VDE1OjA1OjAzLjQzODM4MTJaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AAMGItn0n3kg.RuvnMQyohrognSUxrw_4V0gtBaWd2w6Ao_NKYRogU3MLkOeVcJ-1WW0KfjOi9lM1etbonLLDZY0hks9m4_CsykkqESLlD_cTslQjEnLGjkitz89scJVo964hTay_EImSYIwfwNcC2LSwixlNi-8y983SK1xGwrLHXlj5TDLh5Ka3YNHms82C9zPFxgZoC_OBw2b1uPaKGK-Lpwf5Nwh-P82c9c2ydgnXPbC_FOGWYZECvGs8pQJJKhiKyoVXVCuB7KvxyvuYvyOE-XyfimeGE0zGMS8j9L6uGPRx2iW-ocJwz97TIlhCk1pyy2fopYzcLEAZ5X732cDfRJbXmvlYEg	2025-11-19 17:04:55.858407	\N	\N	\N	\N	15
12	73	64d31762-afd9-8dc1-80b8-7ff5a6bf1aac	Sibanda.ICT	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/b41f4e2a-4def-4115-81ad-f8ba6ab91867?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAAsBFv_CzeSAgAAFAj9h0t3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMjZUMTU6MDQ6NDQrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMjZUMTQ6NTk6NDQuNDg3MzczNSswMDowMCIsIlJlc291cmNlSWQiOiI2NGQzMTc2Mi1hZmQ5LThkYzEtODBiOC03ZmY1YTZiZjFhYWMiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI2NGQzMTc2Mi1hZmQ5LThkYzEtODBiOC03ZmY1YTZiZjFhYWNcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD03MGUxMTdmNy05Mjg0LThlNWEtODBjNS05M2MxNDZiZDFhY2ZcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTI2VDE0OjU5OjQ0LjM1MzMyNDhaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgHdJIf0s3kg.g81k-Elom8SVgBsJDBjuK0ONQUAWkZXUotrEXQo9xT5ZvLnqdy2hvZ33Sbhf1XxC4863tvaL0Pk5kTwK46Or5auM9x5iqXjvKAriN_eaIG_0VUGj9FumyItVXjZumSrQAESrYdlqxjv_-gwD-g2QTynWQbVpg8dvY7cUZXruN2RvGd6rxiiPmzQGglFofXZbNL1ojHnnXKdYeyJHrMBVOaxJnW-kXpDX6YvwUhRpyRXrfnXnVht9EfpB-pUrvGeZmP99rHzmzG-MRXL-PDHicppnjW0MFl-69YWQRor_1TZi5dXB2Mb_D1rZ0sAn6W3dbRLQOa7oT_c8votxiHvEDw	2025-11-26 16:59:37.670781	\N	\N	\N	\N	15
13	74	e82b1d21-b33b-8057-8025-1ecc58b11b24	BrandBrands	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/1d47cf98-4b1d-49b2-862d-78d9a4cacdea?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCA6MxHuS3eSAgAgIjeztot3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTEtMjdUMTM6MzY6MzMrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTEtMjdUMTM6MzE6MzMuNzQzMjkyMSswMDowMCIsIlJlc291cmNlSWQiOiJlODJiMWQyMS1iMzNiLTgwNTctODAyNS0xZWNjNThiMTFiMjQiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJlODJiMWQyMS1iMzNiLTgwNTctODAyNS0xZWNjNThiMTFiMjRcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD01ZGYyMTZkOS0xZjgxLTg5ZDUtODA1Ni0yOTY2MGNiMTFiY2RcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTExLTI3VDEzOjMxOjMzLjY2Nzk3NDZaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AALAE-rkt3kg.E98alvVe-AkjgEwn75qt2Qfv0YNZsgwsQAWRHqgFalT4UnwLnZjDuGDxByF9PyHKnOvrNUTZJJf2Yg-lrCUDv8-dKdPGSA1GXyNk-PDD5_LRyzANIFo-8dpsjP0DZeNn6xI8gzABeHyriVF2pu0qaJRhKMAcHGif55yS-4jwoje5CjCrswenSY1-ONfSdcURyFZP_MeCP0u27EGPTAVupic9RVpSbSDwM8ZP0_37-KpKf5sxhQGR4F7igsS_kWGoXMhQnIDEN7KboDiklRmuZPJnanP9kCH4P_FCiQMo2JiXXWpxcdl3AsSYuyj-MLf7bckCD8yEEmHPEtCwL23y_g	2025-11-27 15:31:25.820602	\N	\N	\N	\N	15
14	76	b23b168c-1093-86d3-804b-38c1b2c9018f	UMS Inc	umsibanda.1994@gmail.com		sent	https://demo.docusign.net/Signing/MTRedeem/v1/dcfe53f9-ab29-448a-afcc-3a8603c5db2c?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCAe7xL1TDeSAgAgBvO0vYw3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTItMDFUMTI6MzQ6MzkrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTItMDFUMTI6Mjk6MzkuNDk2NzA1NyswMDowMCIsIlJlc291cmNlSWQiOiJiMjNiMTY4Yy0xMDkzLTg2ZDMtODA0Yi0zOGMxYjJjOTAxOGYiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJiMjNiMTY4Yy0xMDkzLTg2ZDMtODA0Yi0zOGMxYjJjOTAxOGZcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD0xNmY2MWEzNi0zY2ZlLTg5YmEtODBjOC1jZTNmNTBjODAxNzJcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEyLTAxVDEyOjI5OjM5LjM3NTU5NzVaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AAEP0_dUw3kg.mZEZnW413CeXUz3sHJGKClRcUz5kuH6L5xaGPYGiHFX6LuMkN51Nph0SBlRS_Gz_MI750EPTEJAE1SAZVKweiunNU-iV_CQa6SO2Jli27FlJmic6Qp5PVCrqy3bT4E4mhcPeZ-LSgQeLpHugSUwRBYOuFXFL3xDhBcnJzy-yDA70WSJBvQq96LBIg_Xu7spY_3U5ojtobOqW0drcuZguOyxZpVwclJnToGCgXo2haCF068neisLJ1JPxemgWvulhHDypRRjJTB8NDAWo5iFBk5dFjXrGQEKa7jvsyi-uwRGpBo98fFPTJn6lc35UFC4NT69wwKCN8TbdbYCV3Z2NuA	2025-12-01 14:29:39.961316	\N	\N	\N	\N	16
15	75	47ad17fd-4181-884f-8055-0ac57ec10350	Beauty FoodCourt	sibandanobunzima@gmail.com		signed	https://demo.docusign.net/Signing/MTRedeem/v1/df4a1495-5889-40f3-8419-0838160316ed?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCAv5P6bTLeSAgAgF-lgY8y3kgYAAEAAAAAAAAAIQCyAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTItMDNUMTM6MjA6MDYrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTItMDNUMTM6MTU6MDcuMDMwODgzNyswMDowMCIsIlJlc291cmNlSWQiOiI0N2FkMTdmZC00MTgxLTg4NGYtODA1NS0wYWM1N2VjMTAzNTAiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCI0N2FkMTdmZC00MTgxLTg4NGYtODA1NS0wYWM1N2VjMTAzNTBcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD03NjZhMWE1Ni05ZTIzLTgyNzYtODBjZi03MjhiYzNjYzAzY2ZcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEyLTAzVDEzOjE1OjA2LjkxMzYxN1pcIn0iLCJUb2tlblR5cGUiOjEsIkF1ZGllbmNlIjoiMjVlMDkzOTgtMDM0NC00OTBjLThlNTMtM2FiMmNhNTYyN2JmIiwiUmVkaXJlY3RVcmkiOiJodHRwczovL2RlbW8uZG9jdXNpZ24ubmV0L1NpZ25pbmcvU3RhcnRJblNlc3Npb24uYXNweCIsIkhhc2hBbGdvcml0aG0iOjAsIkhhc2hSb3VuZHMiOjAsIlRva2VuU3RhdHVzIjowLCJJc1NpbmdsZVVzZSI6ZmFsc2V9PwCA8DKsbjLeSA.JVT1Xpdsjdlf3k_8mMb6rBxJ4FVHeQNcb7-741TDalybpRWrnYI7poVHHpo9Afhq_ywix0Q7_RaCo0SiIuhUNVfcZFLrNToHWXT9gGEp21zhUMuRD2wb0hoG0mEgL9Cdquoby0bJYMmkiKVTBfpj1cdlj9S9BWIerWlCxf4OcbcadO6ZeipKJUGnWC6knycBejKdgVU9A2r05OMQMTqDITQy-8yiJ_pTq5HPMZgxMuKI7NdVKV1J4JiVSrvMsf5BiprlmoFOSMOZ0P1-Bu90Uz3vr7DuDJp7M2LygmBe-24EX-62HBSitO2t2q3B3YKQI0QlzvFh76Xi4LxIR_wIKQ	2025-12-03 15:15:07.225191	2025-12-03 15:27:30.820985	\N	\N	\N	16
17	78	f40b1847-2dab-8340-8051-9f9324c50338	Unathi ICT	umsibanda.1994@gmail.com		signed	https://demo.docusign.net/Signing/MTRedeem/v1/4f18ae13-2fa8-443a-af13-801f1c6f2599?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAAX8LPnzLeSAgAAP_TVsEy3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTItMDNUMTk6MTY6NTArMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTItMDNUMTk6MTE6NTAuNzkxNDQ2OCswMDowMCIsIlJlc291cmNlSWQiOiJmNDBiMTg0Ny0yZGFiLTgzNDAtODA1MS05ZjkzMjRjNTAzMzgiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJmNDBiMTg0Ny0yZGFiLTgzNDAtODA1MS05ZjkzMjRjNTAzMzhcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD1iNDliMWE3Ni04OThjLTg4NzAtODA4Zi1jNDIwMjNjODAzYjRcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEyLTAzVDE5OjExOjUwLjcxMzA5MDNaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgCb6gaAy3kg.vwzD6i4nZUh6Uf2BYd3oelgJFGQZnhesAhLG_sO_Ki43gvIY68FU9CamimPZ4vUimdApmJDUqTB9ZmfUDwV1IoyiIy3UzNpiNcis6qHUMumAeYxDaYC4avOMpPZJ97YU_eau5amexJRa-eYuxQgcUzR7KIU6x5pj3V19g-g9Yeueljr3mye1wvZA4viYwcvycenMdg9a-2rt4wGtkNM3X3cLXgfWmvL6Vp7JM0bOmDTOM7cLCKFCGuuhzLqNtPKTqCwX9f-3sovrB94wR7CL5MrWef0M4z7nLQLsGgUoVogQ9uI_PQavcTmuiF_vqYKDaB-UVKK6vrRtlixnsw_M_A	2025-12-03 21:11:50.944094	2025-12-03 21:13:30.456736	\N	\N	\N	16
16	77	dff41e77-8ede-80b2-813e-315127c603ad	Beauty ICT	sibandanobunzima@gmail.com		signed	https://demo.docusign.net/Signing/MTRedeem/v1/c7d18386-971e-47a7-9efd-6b5b0a51131e?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwAAFYPUlzLeSAgAALWUW7ky3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTItMDNUMTg6MTk6NDIrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTItMDNUMTg6MTQ6NDIuNDMzNzAwOCswMDowMCIsIlJlc291cmNlSWQiOiJkZmY0MWU3Ny04ZWRlLTgwYjItODEzZS0zMTUxMjdjNjAzYWQiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCJkZmY0MWU3Ny04ZWRlLTgwYjItODEzZS0zMTUxMjdjNjAzYWRcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD1mZGVkMTNkMS1mNjdlLTgxZWMtODE0ZS01NzVlOWZjZTAzY2ZcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEyLTAzVDE4OjE0OjQyLjMyMjk5NTRaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AgNy6hpgy3kg.n3QhcYYEFAaPD4sRZwcL7K7va1kpFWWG3GByooidOQVZKWNJrhl503NnY7vZalGUbksJLHoJowMIfhsyKJ7d7F7V1qKmr8TFvtVMlv2Zq5OI-3jLiA91RY9CL-tSPZYnoYw1-KpxTDMVQltkeujmqvmVkTmbO87ZO857OtW0ekjIy-5QJFmOwvyekXYXiczsLwpaNl0ORCF2sDbJykeV-dqSiXzbYxN2Rl6e_TtlARC4Xrgdbcl4BHv1bLCUVx3XTll9c4ak4BRPEcwv4x1GYH3lPErDBEl6ZhcwQ8glZLie7mJ824NSFLs7ZfI8tMGzUMlSyo7vWISOw8FdQBLOwg	2025-12-03 20:14:42.617806	2025-12-03 21:37:59.072756	\N	\N	\N	16
18	79	0b5f1865-49a8-85a5-8035-2561d6ce035c	Beauty ICtS	sibandanobunzima@gmail.com		signed	https://demo.docusign.net/Signing/MTRedeem/v1/1dfec4de-5871-4f90-a645-e758ef0f60f1?slt=eyJ0eXAiOiJNVCIsImFsZyI6IlJTMjU2Iiwia2lkIjoiNjgxODVmZjEtNGU1MS00Y2U5LWFmMWMtNjg5ODEyMjAzMzE3In0.AQYAAAABAAMABwCAhvLgBjPeSAgAgCYEaCgz3kgYAAEAAAAAAAAAIQCzAgAAeyJUb2tlbklkIjoiYzMyZjkwZDAtOGYyMy00MzZhLWFlNTctN2Q1MDgxZGRkZjAxIiwiRXhwaXJhdGlvbiI6IjIwMjUtMTItMDRUMDc6MzQ6MzcrMDA6MDAiLCJJc3N1ZWRBdCI6IjIwMjUtMTItMDRUMDc6Mjk6MzcuMzE3NTYxMSswMDowMCIsIlJlc291cmNlSWQiOiIwYjVmMTg2NS00OWE4LTg1YTUtODAzNS0yNTYxZDZjZTAzNWMiLCJSZXNvdXJjZXMiOiJ7XCJFbnZlbG9wZUlkXCI6XCIwYjVmMTg2NS00OWE4LTg1YTUtODAzNS0yNTYxZDZjZTAzNWNcIixcIkFjdG9yVXNlcklkXCI6XCIxYjk3MjU5My1hMGQwLTQwM2ItYWRiZS1kMTRjOWE3YmJkMmZcIixcIkZha2VRdWVyeVN0cmluZ1wiOlwidD1lNTU4MTU5MC0yNWY0LTgxNTMtODA3Yi0xMWFlYmJjNDAzOGVcIixcIkludGVncmF0b3JLZXlcIjpcImRiMDQ4M2Y1LThmNzAtNDVkOS1hOTQ5LWQzMDBjZGRkYzFjZFwiLFwiQ3JlYXRlZEF0XCI6XCIyMDI1LTEyLTA0VDA3OjI5OjM3LjE2ODYyNTJaXCJ9IiwiVG9rZW5UeXBlIjoxLCJBdWRpZW5jZSI6IjI1ZTA5Mzk4LTAzNDQtNDkwYy04ZTUzLTNhYjJjYTU2MjdiZiIsIlJlZGlyZWN0VXJpIjoiaHR0cHM6Ly9kZW1vLmRvY3VzaWduLm5ldC9TaWduaW5nL1N0YXJ0SW5TZXNzaW9uLmFzcHgiLCJIYXNoQWxnb3JpdGhtIjowLCJIYXNoUm91bmRzIjowLCJUb2tlblN0YXR1cyI6MCwiSXNTaW5nbGVVc2UiOmZhbHNlfT8AAE4qkwcz3kg.bUBZzZSXZpwpY8iONkOwuh2WjvzV5nHTJy6PuZuulpDEVuAn78kPkvxINySsTtMLM3-ANAUh327BZGSTwD21RA_Ki-1Q9eT13W6qWQUW2iJ5VY0BRvI5pVZNHqD-6VADq60nGnHpEn10F7VzNaRklH69IY6KKmnu0FB7X0gUIsPphOXWPz-PMWK7v30WNFyf_v0AzcE81S8-z3LsM6lq2h-o5g4Gi-hlHljeP_spyzJ3gEKUMMCL8kwIbMgKisleLm72OHBHbsxai0c2CjIl8hDMP9ddw-Emr74W22vgVqtc0_hmUn0vmwzNVHHBHC_GxycK1vRrwtawAaV1iwX2jw	2025-12-04 09:29:37.690715	2025-12-04 09:31:21.309409	\N	\N	\N	16
\.


--
-- Data for Name: proposal_system_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_system_feedback (id, email, message, created_at) FROM stdin;
\.


--
-- Data for Name: proposal_system_proposals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_system_proposals (id, title, client_name, dtype, status, sections, mandatory_sections, approval, readiness_score, readiness_issues, signed_at, signed_by, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: proposal_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_users (id, email, password_hash, first_name, last_name, company, role, is_active, email_verified, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: proposal_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposal_versions (id, proposal_id, version_number, content, created_by, created_at, change_description) FROM stdin;
1	29	1	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-23T11:47:30.422"}}	zukhanye@gmail.com	2025-10-23 11:47:30.737303	Auto-saved
2	29	2	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-23T11:47:39.535"}}	zukhanye@gmail.com	2025-10-23 11:47:39.849331	Auto-saved
3	29	3	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-10-23T11:47:48.715"}}	zukhanye@gmail.com	2025-10-23 11:47:49.033509	Auto-saved
4	29	4	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-23T11:53:45.255"}}	zukhanye@gmail.com	2025-10-23 11:53:45.574363	Auto-saved
5	29	5	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-10-23T11:53:50.346"}}	zukhanye@gmail.com	2025-10-23 11:53:50.924948	Auto-saved
6	29	6	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":7,"last_modified":"2025-10-23T11:53:57.624"}}	zukhanye@gmail.com	2025-10-23 11:53:57.93592	Auto-saved
7	29	7	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n| Column 1 | Column 2 | Column 3 |\\n|----------|----------|----------|\\n| Data 1   | Data 2   | Data 3   |"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":8,"last_modified":"2025-10-23T11:55:28.645"}}	zukhanye@gmail.com	2025-10-23 11:55:28.97051	Auto-saved
8	29	8	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":9,"last_modified":"2025-10-23T11:55:40.959"}}	zukhanye@gmail.com	2025-10-23 11:55:41.268372	Auto-saved
9	29	9	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":10,"last_modified":"2025-10-23T12:15:42.743"}}	zukhanye@gmail.com	2025-10-23 12:15:43.056794	Auto-saved
10	29	10	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-10-23T12:15:54.485"}}	zukhanye@gmail.com	2025-10-23 12:15:54.821714	Auto-saved
11	29	11	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":12,"last_modified":"2025-10-23T12:16:03.784"}}	zukhanye@gmail.com	2025-10-23 12:16:04.101206	Auto-saved
12	29	12	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n[Image placeholder - Image URL or file path]"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":13,"last_modified":"2025-10-23T13:29:14.860"}}	zukhanye@gmail.com	2025-10-23 13:29:15.184666	Auto-saved
13	29	13	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n[Image placeholder - Image URL or file path]\\n[Image: image_580.jpg]"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":14,"last_modified":"2025-10-23T13:29:37.823"}}	zukhanye@gmail.com	2025-10-23 13:29:38.14914	Auto-saved
14	29	14	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":15,"last_modified":"2025-10-23T13:29:52.710"}}	zukhanye@gmail.com	2025-10-23 13:29:53.026135	Auto-saved
15	29	15	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":16,"last_modified":"2025-10-23T13:30:09.163"}}	zukhanye@gmail.com	2025-10-23 13:30:09.476953	Auto-saved
16	29	16	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi\\n• Item 1\\n• Item 2\\n• Item 3"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":17,"last_modified":"2025-10-23T13:30:37.458"}}	zukhanye@gmail.com	2025-10-23 13:30:37.769348	Auto-saved
17	29	17	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi\\n• Item 1\\n• Item 2\\n• Item 3\\n1. Item 1\\n2. Item 2\\n3. Item 3"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":18,"last_modified":"2025-10-23T13:30:42.076"}}	zukhanye@gmail.com	2025-10-23 13:30:42.118299	Auto-saved
18	29	18	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi\\n• Item 1\\n• Item 2\\n• Item 3\\n1. Item 1\\n2. Item 2\\n3. Item 3"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":19,"last_modified":"2025-10-23T13:31:05.989"}}	zukhanye@gmail.com	2025-10-23 13:31:06.310135	Auto-saved
19	29	19	{"title":"ed Document","sections":[{"title":"Cover","content":"I want to create a proposal for my busi\\n• Item 1\\n• Item 2\\n• Item 3\\n1. Item 1\\n2. Item 2\\n3. Item 3"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":20,"last_modified":"2025-10-23T13:31:29.463"}}	zukhanye@gmail.com	2025-10-23 13:31:29.77564	Auto-saved
20	29	20	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":21,"last_modified":"2025-10-23T14:14:20.218"}}	zukhanye@gmail.com	2025-10-23 14:14:20.797663	Restored from version 1
21	29	21	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":22,"last_modified":"2025-10-23T14:14:23.651"}}	zukhanye@gmail.com	2025-10-23 14:14:23.781211	Auto-saved
22	29	22	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":23,"last_modified":"2025-10-23T14:19:48.164"}}	zukhanye@gmail.com	2025-10-23 14:19:48.48193	Auto-saved
23	29	23	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text"}],"metadata":{"currency":"Rand (ZAR)","version":24,"last_modified":"2025-10-23T14:54:45.993"}}	zukhanye@gmail.com	2025-10-23 14:54:46.574696	Restored from version 21
24	29	24	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]","backgroundColor":4294967295,"backgroundImageUrl":null},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":25,"last_modified":"2025-10-23T15:13:57.931"}}	zukhanye@gmail.com	2025-10-23 15:13:58.253689	Auto-saved
25	29	25	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":null},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":26,"last_modified":"2025-10-23T15:14:16.181"}}	zukhanye@gmail.com	2025-10-23 15:14:16.504549	Auto-saved
26	29	26	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":null},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":27,"last_modified":"2025-10-23T15:16:10.213"}}	zukhanye@gmail.com	2025-10-23 15:16:10.530185	Auto-saved
27	29	27	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":28,"last_modified":"2025-10-23T15:17:30.260"}}	zukhanye@gmail.com	2025-10-23 15:17:30.572426	Auto-saved
28	29	28	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":29,"last_modified":"2025-10-23T15:21:14.721"}}	zukhanye@gmail.com	2025-10-23 15:21:15.035612	Auto-saved
29	29	29	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\n[Link Text](https://example.com)","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":30,"last_modified":"2025-10-23T15:21:47.505"}}	zukhanye@gmail.com	2025-10-23 15:21:47.831416	Auto-saved
30	29	30	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":31,"last_modified":"2025-10-23T15:21:56.728"}}	zukhanye@gmail.com	2025-10-23 15:21:57.04614	Auto-saved
31	29	31	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\n\\nSignature (Manager Approval): __________________ Date: __________\\n","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":32,"last_modified":"2025-10-23T15:22:50.590"}}	zukhanye@gmail.com	2025-10-23 15:22:50.909104	Auto-saved
32	29	32	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\n","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":33,"last_modified":"2025-10-23T15:23:00.165"}}	zukhanye@gmail.com	2025-10-23 15:23:00.478012	Auto-saved
33	29	33	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg"},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null}],"metadata":{"currency":"Rand (ZAR)","version":34,"last_modified":"2025-10-23T15:25:48.860"}}	zukhanye@gmail.com	2025-10-23 15:25:49.174486	Auto-saved
34	29	34	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":35,"last_modified":"2025-10-23T15:31:42.367"}}	zukhanye@gmail.com	2025-10-23 15:31:42.681767	Auto-saved
35	29	35	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":36,"last_modified":"2025-10-23T15:36:14.281"}}	zukhanye@gmail.com	2025-10-23 15:36:14.606703	Auto-saved
36	29	36	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":37,"last_modified":"2025-10-23T15:36:20.096"}}	zukhanye@gmail.com	2025-10-23 15:36:20.423892	Auto-saved
37	29	37	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":38,"last_modified":"2025-10-23T15:36:56.173"}}	zukhanye@gmail.com	2025-10-23 15:36:56.486562	Auto-saved
38	29	38	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":39,"last_modified":"2025-10-23T15:37:03.230"}}	zukhanye@gmail.com	2025-10-23 15:37:03.564752	Auto-saved
39	29	39	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n[Image: https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]\\n[Image: http://res.cloudinary.com/dhy0jccgg/image/upload/v1761226607/g9bhgindr7r2j2mzhaju.png]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":true},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":40,"last_modified":"2025-10-23T15:44:31.616"}}	zukhanye@gmail.com	2025-10-23 15:44:31.943157	Auto-saved
40	29	40	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg","sectionType":"cover","isCoverPage":false},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":41,"last_modified":"2025-10-23T15:49:25.011"}}	zukhanye@gmail.com	2025-10-23 15:49:25.350829	Auto-saved
41	29	41	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg","sectionType":"cover","isCoverPage":false},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":42,"last_modified":"2025-10-23T15:49:34.010"}}	zukhanye@gmail.com	2025-10-23 15:49:34.326114	Auto-saved
42	29	42	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n1. Item 1\\n2. Item 2\\n3. Item 3","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg","sectionType":"cover","isCoverPage":false},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":43,"last_modified":"2025-10-23T15:55:55.462"}}	zukhanye@gmail.com	2025-10-23 15:55:55.788373	Auto-saved
43	29	43	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n1. Item 1\\n2. Item 2\\n3. Item 3\\n• Item 1\\n• Item 2\\n• Item 3","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg","sectionType":"cover","isCoverPage":false},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false}],"metadata":{"currency":"Rand (ZAR)","version":44,"last_modified":"2025-10-23T15:56:00.239"}}	zukhanye@gmail.com	2025-10-23 15:56:00.553123	Auto-saved
97	35	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Winky wink ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-29T18:47:55.860"}}	22	2025-10-29 18:47:56.179644	Auto-saved
44	29	44	{"title":"Untitled Document","sections":[{"title":"Cover","content":"\\nCreated by Unathi\\n1. Item 1\\n2. Item 2\\n3. Item 3\\n• Item 1\\n• Item 2\\n• Item 3","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":45,"last_modified":"2025-10-23T16:20:12.461"}}	zukhanye@gmail.com	2025-10-23 16:20:12.787591	Manual save
45	29	45	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":46,"last_modified":"2025-10-23T16:24:13.234"}}	zukhanye@gmail.com	2025-10-23 16:24:13.563489	Auto-saved
46	29	46	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":47,"last_modified":"2025-10-23T16:26:12.287"}}	zukhanye@gmail.com	2025-10-23 16:26:12.615591	Auto-saved
47	29	47	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[{"url":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png","width":300,"height":200,"x":31,"y":4}]}],"metadata":{"currency":"Rand (ZAR)","version":48,"last_modified":"2025-10-23T16:31:32.570"}}	zukhanye@gmail.com	2025-10-23 16:31:32.891751	Auto-saved
48	29	48	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":49,"last_modified":"2025-10-23T16:32:15.512"}}	zukhanye@gmail.com	2025-10-23 16:32:15.840126	Auto-saved
49	29	49	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":50,"last_modified":"2025-10-23T16:37:40.760"}}	zukhanye@gmail.com	2025-10-23 16:37:41.085755	Auto-saved
50	29	50	{"title":"Untitled Document","sections":[{"title":"Cover","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"cover","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":51,"last_modified":"2025-10-23T16:38:41.536"}}	zukhanye@gmail.com	2025-10-23 16:38:41.882503	Auto-saved
51	28	1	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-24T12:11:59.665"}}	zukhanye@gmail.com	2025-10-24 12:11:59.982767	Auto-saved
52	28	2	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-24T12:12:23.555"}}	zukhanye@gmail.com	2025-10-24 12:12:23.864189	Auto-saved
98	36	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dghjkloiuuttdchkml","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-30T12:09:17.451"}}	22	2025-10-30 12:09:17.772275	Auto-saved
53	28	3	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-10-24T12:12:43.166"}}	zukhanye@gmail.com	2025-10-24 12:12:43.476274	Auto-saved
54	28	4	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-24T12:13:33.644"}}	zukhanye@gmail.com	2025-10-24 12:13:33.960532	Auto-saved
55	28	5	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-10-24T12:13:37.920"}}	zukhanye@gmail.com	2025-10-24 12:13:38.227813	Auto-saved
56	28	6	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":7,"last_modified":"2025-10-24T12:13:59.162"}}	zukhanye@gmail.com	2025-10-24 12:13:59.473994	Auto-saved
57	28	7	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":8,"last_modified":"2025-10-24T12:51:42.321"}}	zukhanye@gmail.com	2025-10-24 12:51:42.657626	Auto-saved
58	28	8	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":9,"last_modified":"2025-10-24T13:05:54.447"}}	zukhanye@gmail.com	2025-10-24 13:05:54.759959	Auto-saved
59	28	9	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":10,"last_modified":"2025-10-24T13:06:16.726"}}	zukhanye@gmail.com	2025-10-24 13:06:17.056151	Auto-saved
60	28	10	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-10-24T13:07:34.654"}}	zukhanye@gmail.com	2025-10-24 13:07:34.969826	Auto-saved
61	29	51	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Stable business environment during implementation\\n• Available stakeholder participation\\n• Access to required systems and data\\n• Adequate infrastructure capacity\\n\\n2. Resource Availability:\\n• Timely decision-making from stakeholders\\n• Access to subject matter experts\\n• Availability of test environments\\n• Required third-party cooperation\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• System access and permissions\\n• Third-party system integrations\\n• Infrastructure readiness\\n• Data availability and quality\\n\\n2. Business Dependencies:\\n• Business process documentation\\n• User participation in testing\\n• Change management support\\n• Training participation","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":52,"last_modified":"2025-10-24T13:27:15.254"}}	zukhanye@gmail.com	2025-10-24 13:27:15.582036	Auto-saved
62	29	52	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Stable business environment during implementation\\n• Available stakeholder participation\\n• Access to required systems and data\\n• Adequate infrastructure capacity\\n\\n2. Resource Availability:\\n• Timely decision-making from stakeholders\\n• Access to subject matter experts\\n• Availability of test environments\\n• Required third-party cooperation\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• System access and permissions\\n• Third-party system integrations\\n• Infrastructure readiness\\n• Data availability and quality\\n\\n2. Business Dependencies:\\n• Business process documentation\\n• User participation in testing\\n• Change management support\\n• Training participation","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":53,"last_modified":"2025-10-24T13:27:47.513"}}	zukhanye@gmail.com	2025-10-24 13:27:47.843341	Auto-saved
63	29	53	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Stable business operations with minimal disruptions during implementation phase\\n• Committed stakeholder participation with 48-hour response times\\n• Secured access to all required systems and data sources\\n• Verified infrastructure capacity meeting project requirements\\n\\n2. Resource Availability:\\n• Stakeholder decisions within agreed SLA timeframes\\n• Dedicated subject matter experts with allocated project time\\n• Fully configured test environments with production-like data\\n• Confirmed third-party vendor support with documented agreements\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Provisioned system access with appropriate security clearances\\n• Validated third-party system integration capabilities\\n• Confirmed infrastructure readiness meeting performance requirements\\n• Verified data quality meeting minimum accuracy thresholds\\n\\n2. Business Dependencies:\\n• Current and approved business process documentation\\n• Committed user participation in all testing phases\\n• Established change management framework and resources\\n• Mandatory training completion by all end users\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":54,"last_modified":"2025-10-24T13:28:50.295"}}	zukhanye@gmail.com	2025-10-24 13:28:50.621923	Auto-saved
64	29	54	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Stable business operations with minimal disruptions during implementation phase\\n• Committed stakeholder participation with 48-hour response times\\n• Secured access to all required systems and data sources\\n• Verified infrastructure capacity meeting project requirements\\n\\n2. Resource Availability:\\n• Stakeholder decisions within agreed SLA timeframes\\n• Dedicated subject matter experts with allocated project time\\n• Fully configured test environments with production-like data\\n• Confirmed third-party vendor support with documented agreements\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Provisioned system access with appropriate security clearances\\n• Validated third-party system integration capabilities\\n• Confirmed infrastructure readiness meeting performance requirements\\n• Verified data quality meeting minimum accuracy thresholds\\n\\n2. Business Dependencies:\\n• Current and approved business process documentation\\n• Committed user participation in all testing phases\\n• Established change management framework and resources\\n• Mandatory training completion by all end users\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":55,"last_modified":"2025-10-24T13:29:08.232"}}	zukhanye@gmail.com	2025-10-24 13:29:08.556913	Auto-saved
65	29	55	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation\\n• Stakeholders will provide responses within 48 hours\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30%\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Backup SMEs identified for critical roles\\n• Escalation procedures documented for missed SLAs\\n• Alternative testing schedules prepared for resource conflicts","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":56,"last_modified":"2025-10-24T13:30:18.443"}}	zukhanye@gmail.com	2025-10-24 13:30:18.769384	Auto-saved
66	29	56	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation (as per Khonology's standard SLA)\\n• Stakeholders will provide responses within 2 business days (based on SAST timezone)\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30% to ensure optimal performance\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project (half of standard work week)\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time during South African business hours\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request (compliant with POPIA requirements)\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate with daily validation\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Primary and secondary backup SMEs identified for each critical role\\n• Documented escalation procedures for missed SLAs, including:\\n  - First-level response within 1 hour\\n  - Management escalation within 4 hours\\n  - Executive escalation within 8 hours\\n• Alternative testing schedules prepared for resource conflicts\\n• Emergency response team available during critical implementation phases\\n• Local disaster recovery procedures aligned with business continuity requirements","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":57,"last_modified":"2025-10-24T14:46:43.383"}}	zukhanye@gmail.com	2025-10-24 14:46:43.709142	Auto-saved
67	29	57	{"title":" Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation (as per Khonology's standard SLA)\\n• Stakeholders will provide responses within 2 business days (based on SAST timezone)\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30% to ensure optimal performance\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project (half of standard work week)\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time during South African business hours\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request (compliant with POPIA requirements)\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate with daily validation\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Primary and secondary backup SMEs identified for each critical role\\n• Documented escalation procedures for missed SLAs, including:\\n  - First-level response within 1 hour\\n  - Management escalation within 4 hours\\n  - Executive escalation within 8 hours\\n• Alternative testing schedules prepared for resource conflicts\\n• Emergency response team available during critical implementation phases\\n• Local disaster recovery procedures aligned with business continuity requirements","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":58,"last_modified":"2025-10-24T14:47:25.147"}}	zukhanye@gmail.com	2025-10-24 14:47:25.48371	Auto-saved
68	29	58	{"title":"Temp2","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation (as per Khonology's standard SLA)\\n• Stakeholders will provide responses within 2 business days (based on SAST timezone)\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30% to ensure optimal performance\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project (half of standard work week)\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time during South African business hours\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request (compliant with POPIA requirements)\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate with daily validation\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Primary and secondary backup SMEs identified for each critical role\\n• Documented escalation procedures for missed SLAs, including:\\n  - First-level response within 1 hour\\n  - Management escalation within 4 hours\\n  - Executive escalation within 8 hours\\n• Alternative testing schedules prepared for resource conflicts\\n• Emergency response team available during critical implementation phases\\n• Local disaster recovery procedures aligned with business continuity requirements","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":59,"last_modified":"2025-10-24T14:47:43.155"}}	zukhanye@gmail.com	2025-10-24 14:47:43.48568	Auto-saved
69	30	1	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n1. Client Environment\\n• Adequate infrastructure availability\\n• Access to necessary systems and data\\n• Stable network connectivity\\n\\n2. Project Support\\n• Timely decision-making from stakeholders\\n• Available subject matter experts\\n• Dedicated project team members\\n\\n3. Technical Requirements\\n• Compatible existing systems\\n• Required licenses and permissions\\n• Adequate testing environments\\n\\nDependencies:\\n• Client resource availability\\n• Third-party system integration\\n• Regulatory approvals\\n• Hardware/software procurement\\n• Stakeholder sign-offs","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"Total Project Investment: R2.5 million\\n\\nBreakdown:\\n1. Technology Implementation: R1,200,000\\n• Software development\\n• System integration\\n• Infrastructure setup\\n\\n2. Training & Development: R600,000\\n• Technical training\\n• Leadership development\\n• Change management\\n\\n3. Support & Maintenance: R400,000\\n• 12 months support\\n• System updates\\n• Performance optimization\\n\\n4. Project Management: R300,000\\n• Team coordination\\n• Documentation\\n• Quality assurance\\n\\nPayment Schedule:\\n• Initial payment: R500,000\\n• Monthly payments: R166,666 (12 months)\\n\\nAll prices are in South African Rand (ZAR) and exclude VAT.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a hybrid agile methodology that combines best practices from various frameworks:\\n\\n1. Project Initiation\\n• Stakeholder engagement\\n• Requirements gathering\\n• Project charter development\\n\\n2. Iterative Development\\n• Two-week sprint cycles\\n• Regular client feedback\\n• Continuous integration\\n\\n3. Quality Assurance\\n• Automated testing\\n• User acceptance testing\\n• Performance monitoring\\n\\n4. Implementation\\n• Phased rollout approach\\n• Risk-managed deployment\\n• User training and support\\n\\nOur methodology emphasizes:\\n• Regular communication\\n• Transparent progress tracking\\n• Flexible adaptation to changing needs\\n• Knowledge transfer throughout the project","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and professional development. This proposal outlines our comprehensive approach to delivering innovative solutions that drive business growth and operational excellence. With over a decade of experience serving major financial institutions and corporations across Africa, Khonology combines deep industry expertise with cutting-edge technology to create sustainable value for our clients. Our proposed engagement framework encompasses technology implementation, skills development, and organizational change management, with an estimated investment of R2.5 million over 12 months. This partnership will enable our clients to leverage emerging technologies, develop critical capabilities, and achieve their strategic objectives while maintaining competitive advantage in an increasingly digital marketplace. khokhvkkhhv","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Founded in 2013 and headquartered in Johannesburg, Khonology has established itself as a premier technology solutions partner for Africa's leading organizations. Our company's core focus areas include:\\n\\n• Financial Technology Solutions\\n• Digital Transformation\\n• Professional Development & Training\\n• Technology Consulting Services\\n• Change Management\\n\\nKhonology has successfully delivered over 200 projects across Southern Africa, working with major banks, insurance companies, and financial services providers. Our track record includes implementing core banking systems, developing custom fintech solutions, and training over 5,000 professionals in various technology disciplines. The company maintains strategic partnerships with global technology leaders and local institutions, ensuring access to world-class solutions and methodologies adapted for African markets.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive solution package comprising:\\n\\n1. Technology Implementation\\n• Custom software development and integration\\n• Cloud migration services\\n• Digital platform development\\n\\n2. Skills Enhancement Program\\n• Technical training modules\\n• Leadership development workshops\\n• Digital literacy courses\\n\\n3. Change Management Support\\n• Organizational readiness assessment\\n• Change impact analysis\\n• Stakeholder management\\n\\n4. Ongoing Support & Maintenance\\n• 24/7 technical support\\n• Regular system updates\\n• Performance monitoring\\n\\nOur solution is designed to be scalable, adaptable, and aligned with international best practices while considering local market conditions and requirements.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks\\n• Risk: System compatibility issues\\n• Mitigation: Comprehensive testing and POC phase\\n\\n2. Timeline Risks\\n• Risk: Project delays\\n• Mitigation: Buffer periods and resource optimization\\n\\n3. Resource Risks\\n• Risk: Key personnel availability\\n• Mitigation: Cross-training and backup resources\\n\\n4. Change Management Risks\\n• Risk: User resistance\\n• Mitigation: Early engagement and training programs\\n\\n5. Integration Risks\\n• Risk: Third-party system issues\\n• Mitigation: Detailed integration planning and testing","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"The project scope encompasses:\\n\\nPhase 1: Assessment & Planning\\n• Detailed requirements analysis\\n• Solution architecture design\\n• Project plan development\\n\\nPhase 2: Implementation\\n• Technology platform deployment\\n• Integration with existing systems\\n• User training and documentation\\n\\nPhase 3: Training & Development\\n• Technical skills training\\n• Leadership development programs\\n• Change management workshops\\n\\nPhase 4: Support & Optimization\\n• Post-implementation support\\n• Performance monitoring\\n• Continuous improvement initiatives\\n\\nKey Deliverables:\\n• Detailed project documentation\\n• Implemented technology solutions\\n• Training materials and certificates\\n• Support and maintenance documentation","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Our project team consists of highly qualified professionals:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience\\n• Technical Lead: 12+ years experience\\n• Change Management Lead: 10+ years experience\\n\\nTechnical Team:\\n• Senior Developers (4)\\n• System Architects (2)\\n• Integration Specialists (2)\\n• Quality Assurance Engineers (2)\\n\\nSupport Team:\\n• Training Specialists (2)\\n• Change Management Consultants (2)\\n• Technical Support Engineers (3)\\n\\nAll team members are certified in relevant technologies and methodologies, with extensive experience in similar projects across Africa.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Contract Duration\\n• Initial term: 12 months\\n• Option to extend based on mutual agreement\\n\\n2. Payment Terms\\n• Initial payment: Upon contract signing\\n• Monthly payments: End of each month\\n• 30-day payment terms\\n\\n3. Deliverables\\n• All deliverables subject to client approval\\n• Change requests handled through formal process\\n\\n4. Intellectual Property\\n• Client owns final deliverables\\n• Khonology retains methodology rights\\n\\n5. Confidentiality\\n• NDA covers all project information\\n• Data protection compliance\\n\\n6. Termination\\n• 60-day notice period\\n• Transition support included","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months:\\n\\nMonth 1-2: Project Initiation\\n• Project planning\\n• Requirements finalization\\n• Team mobilization\\n\\nMonth 3-6: Development & Implementation\\n• Solution development\\n• Integration testing\\n• Initial deployments\\n\\nMonth 7-9: Training & Change Management\\n• User training programs\\n• Change management activities\\n• Process optimization\\n\\nMonth 10-12: Optimization & Handover\\n• Performance tuning\\n• Documentation completion\\n• Support transition\\n\\nKey Milestones:\\n• Project kickoff: Month 1\\n• First deployment: Month 4\\n• Training completion: Month 8\\n• Project completion: Month 12","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our analysis and industry expertise, we understand that organizations in today's rapidly evolving digital landscape require:\\n\\n1. Digital Transformation Solutions\\n• Modernization of legacy systems\\n• Integration of emerging technologies\\n• Enhanced customer experience platforms\\n\\n2. Skills Development\\n• Technical training and certification\\n• Leadership development\\n• Digital literacy programs\\n\\n3. Change Management\\n• Organizational transformation support\\n• Process optimization\\n• Cultural change initiatives\\n\\n4. Technology Implementation\\n• Custom software development\\n• System integration\\n• Infrastructure modernization\\n\\nWe recognize the critical importance of delivering solutions that are not only technologically advanced but also culturally aligned and sustainable within the African context.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-24T14:59:59.279"}}	zukhanye@gmail.com	2025-10-24 14:59:59.616941	Auto-saved
70	29	59	{"title":"Temp2","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation (as per Khonology's standard SLA)\\n• Stakeholders will provide responses within 2 business days (based on SAST timezone)\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30% to ensure optimal performance\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project (half of standard work week)\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time during South African business hours\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request (compliant with POPIA requirements)\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate with daily validation\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Primary and secondary backup SMEs identified for each critical role\\n• Documented escalation procedures for missed SLAs, including:\\n  - First-level response within 1 hour\\n  - Management escalation within 4 hours\\n  - Executive escalation within 8 hours\\n• Alternative testing schedules prepared for resource conflicts\\n• Emergency response team available during critical implementation phases\\n• Local disaster recovery procedures aligned with business continuity requirements","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":60,"last_modified":"2025-10-27T12:04:28.131"}}	zukhanye@gmail.com	2025-10-27 12:04:28.471524	Auto-saved
71	28	11	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Hey","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":12,"last_modified":"2025-10-27T14:55:46.586"}}	zukhanye@gmail.com	2025-10-27 14:55:46.91236	Auto-saved
72	28	12	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Hey, how are you ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":13,"last_modified":"2025-10-27T14:55:56.453"}}	zukhanye@gmail.com	2025-10-27 14:55:56.769347	Auto-saved
73	28	13	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.\\n[Table]\\n[Column 1] | [Column 2] | [Column 3]\\n[Row 1] | [Data] | [Data]\\n[Row 2] | [Data] | [Data]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Hey, how are you ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":14,"last_modified":"2025-10-27T14:56:53.073"}}	zukhanye@gmail.com	2025-10-27 14:56:53.391049	Auto-saved
74	28	14	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.\\n[Table]\\n[Column 1] | [Column 2] | [Column 3]\\n[Row 1] | [Data] | [Data]\\n[Row 2] | [Data] | [Data]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Hey, how are you ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":15,"last_modified":"2025-10-27T14:57:06.549"}}	zukhanye@gmail.com	2025-10-27 14:57:06.866993	Auto-saved
75	31	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Introduction: The Khonology Approach\\n\\nIn today's rapidly evolving business landscape, organisations face unprecedented challenges in digital transformation, operational efficiency, and talent development. Khonology, as a proudly South African professional services firm, has established itself as a trusted partner in delivering innovative solutions that bridge the gap between technology and business outcomes.\\n\\nFounded on the principles of knowledge transfer and sustainable transformation, Khonology brings a unique perspective to professional services delivery. Our approach combines local market understanding with global best practices, ensuring solutions that are both world-class and contextually relevant to the South African business environment.\\n\\nWhat sets Khonology apart is our commitment to:\\n\\n• Knowledge-driven transformation: We believe in not just implementing solutions but embedding sustainable knowledge within our client organisations\\n• Local talent development: Our investment in South African talent ensures solutions that understand local nuances while meeting international standards\\n• Innovation with purpose: We leverage cutting-edge technologies and methodologies while maintaining focus on practical, value-driven outcomes\\n• Sustainable partnerships: We build lasting relationships that extend beyond project delivery to create long-term value\\n\\nOur track record of successful implementations across various sectors has demonstrated our ability to deliver tangible results while maintaining cost-effectiveness. With project values ranging from R500,000 to R50 million, we have consistently shown our capability to handle both focused interventions and large-scale transformations.\\n\\nThis proposal outlines how Khonology's ways of working can bring value to your organisation through our proven methodologies, experienced professionals, and commitment to excellence. We understand that each client's needs are unique, and our flexible approach ensures that solutions are tailored to your specific requirements while maintaining the rigour and quality that defines the Khonology brand.\\n\\nLet us demonstrate how our distinctive approach can help your organisation achieve its strategic objectives while building sustainable internal capabilities.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-27T15:52:58.396"}}	zukhanye@gmail.com	2025-10-27 15:52:58.714554	Auto-saved
76	32	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-27T16:47:31.143"}}	zukhanye@gmail.com	2025-10-27 16:47:31.466394	Auto-saved
77	32	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-27T16:47:46.702"}}	zukhanye@gmail.com	2025-10-27 16:47:47.023394	Auto-saved
78	32	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-10-27T16:47:56.986"}}	zukhanye@gmail.com	2025-10-27 16:47:57.29794	Auto-saved
79	32	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-27T16:48:27.596"}}	zukhanye@gmail.com	2025-10-27 16:48:27.91469	Auto-saved
80	31	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Introduction: The Khonology Approach\\n\\nIn today's rapidly evolving business landscape, organisations face unprecedented challenges in digital transformation, operational efficiency, and talent development. Khonology, as a proudly South African professional services firm, has established itself as a trusted partner in delivering innovative solutions that bridge the gap between technology and business outcomes.\\n\\nFounded on the principles of knowledge transfer and sustainable transformation, Khonology brings a unique perspective to professional services delivery. Our approach combines local market understanding with global best practices, ensuring solutions that are both world-class and contextually relevant to the South African business environment.\\n\\nWhat sets Khonology apart is our commitment to:\\n\\n• Knowledge-driven transformation: We believe in not just implementing solutions but embedding sustainable knowledge within our client organisations\\n• Local talent development: Our investment in South African talent ensures solutions that understand local nuances while meeting international standards\\n• Innovation with purpose: We leverage cutting-edge technologies and methodologies while maintaining focus on practical, value-driven outcomes\\n• Sustainable partnerships: We build lasting relationships that extend beyond project delivery to create long-term value\\n\\nOur track record of successful implementations across various sectors has demonstrated our ability to deliver tangible results while maintaining cost-effectiveness. With project values ranging from R500,000 to R50 million, we have consistently shown our capability to handle both focused interventions and large-scale transformations.\\n\\nThis proposal outlines how Khonology's ways of working can bring value to your organisation through our proven methodologies, experienced professionals, and commitment to excellence. We understand that each client's needs are unique, and our flexible approach ensures that solutions are tailored to your specific requirements while maintaining the rigour and quality that defines the Khonology brand.\\n\\nLet us demonstrate how our distinctive approach can help your organisation achieve its strategic objectives while building sustainable internal capabilities.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-27T17:07:01.851"}}	22	2025-10-27 17:07:02.173574	Auto-saved
81	32	5	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-10-27T17:22:49.844"}}	22	2025-10-27 17:22:50.160758	Auto-saved
82	32	6	{"title":"ed Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":7,"last_modified":"2025-10-27T17:22:57.185"}}	22	2025-10-27 17:22:57.512422	Auto-saved
83	32	7	{"title":"ed Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":8,"last_modified":"2025-10-27T17:23:03.718"}}	22	2025-10-27 17:23:04.043872	Auto-saved
84	32	8	{"title":"ed Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":9,"last_modified":"2025-10-27T17:23:12.058"}}	22	2025-10-27 17:23:12.379296	Auto-saved
85	32	9	{"title":"ed Document","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":10,"last_modified":"2025-10-27T17:41:58.009"}}	22	2025-10-27 17:41:58.331249	Auto-saved
86	32	10	{"title":"ocument","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-10-27T17:44:26.945"}}	22	2025-10-27 17:44:27.276075	Auto-saved
87	32	11	{"title":"ent","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":12,"last_modified":"2025-10-27T17:44:33.801"}}	22	2025-10-27 17:44:34.122801	Auto-saved
88	33	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to write a proposal about life","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-28T14:37:40.312"}}	22	2025-10-28 14:37:40.628523	Auto-saved
89	33	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to write a proposal about life ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-28T14:37:46.489"}}	22	2025-10-28 14:37:46.815826	Auto-saved
90	33	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to write a proposal about life ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-10-28T14:37:55.882"}}	22	2025-10-28 14:37:56.201194	Auto-saved
91	33	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to write a proposal about life, I dont know where to start","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-28T14:38:09.742"}}	22	2025-10-28 14:38:10.055	Auto-saved
92	34	1	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implementations and a commitment to transformation, Khonology offers a unique blend with ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-28T16:04:39.338"}}	22	2025-10-28 16:04:39.66796	Auto-saved
93	34	2	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implementations and a commitment to transformation, Khonology offers a unique blend with the proposal ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-28T16:04:49.667"}}	22	2025-10-28 16:04:49.986147	Auto-saved
94	34	3	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implemenotations and a commitment to transformation, Khonology offers a unique blend with the proposal ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-10-28T16:09:59.113"}}	22	2025-10-28 16:09:59.440943	Auto-saved
95	34	4	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implemenotations and a commitment to transformation, Khonology offers a unique blend with the proposal i want to know ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-28T18:19:11.091"}}	22	2025-10-28 18:19:11.422837	Auto-saved
96	34	5	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implemenotations and a commitment to transformation, Khonology offers a unique blend with the proposal ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-10-28T18:31:54.647"}}	\N	2025-10-28 18:31:55.001911	Restored from version 3
115	40	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"My OpenRouter key doesn't have credits\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-07T13:59:13.038"}}	22	2025-11-07 13:59:13.359649	Auto-saved
116	41	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to create a proposal","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-07T14:01:58.705"}}	22	2025-11-07 14:01:59.018921	Auto-saved
117	41	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to create a proposal","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"what is the version about","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-07T14:02:18.068"}}	22	2025-11-07 14:02:18.40103	Auto-saved
118	42	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"I want to","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-07T14:13:00.365"}}	22	2025-11-07 14:13:00.684305	Auto-saved
119	42	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"I want to","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"start a proposal","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-07T14:13:18.617"}}	22	2025-11-07 14:13:18.941011	Auto-saved
120	43	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-07T15:08:35.482"}}	22	2025-11-07 15:08:35.801811	Auto-saved
121	43	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dfvfbgnhnhn","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-07T15:08:42.309"}}	22	2025-11-07 15:08:42.64257	Auto-saved
122	40	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"My OpenRouter key doesn't have credits\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-09T20:50:03.217"}}	22	2025-11-09 20:50:03.540167	Auto-saved
123	45	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"creajs ckd dekmckdmsd cdsc","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-09T21:04:56.531"}}	22	2025-11-09 21:04:56.850297	Auto-saved
124	44	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"creajs ckd dekmckdmsd cdsc","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-10T11:40:22.510"}}	22	2025-11-10 11:40:22.83258	Auto-saved
125	46	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi hi hi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-12T22:17:36.256"}}	22	2025-11-12 22:17:36.580557	Auto-saved
126	46	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi hi hi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-12T22:17:47.965"}}	22	2025-11-12 22:17:48.534063	Auto-saved
127	47	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-13T10:08:34.125"}}	22	2025-11-13 10:08:34.442419	Auto-saved
128	48	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Hi my name is Unathi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-13T22:05:47.105"}}	15	2025-11-13 22:05:47.835101	Auto-saved
129	48	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Hi my name is Unathi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-13T22:06:14.861"}}	15	2025-11-13 22:06:15.585075	Auto-saved
130	49	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-14T15:40:44.763"}}	15	2025-11-14 15:40:45.243093	Auto-saved
131	49	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-14T18:04:51.147"}}	15	2025-11-14 18:04:51.65076	Auto-saved
132	49	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-17T22:54:03.544"}}	15	2025-11-17 22:54:04.062522	Auto-saved
133	62	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Cover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T14:11:17.072"}}	15	2025-11-19 14:11:17.816594	Auto-saved
134	62	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Cover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T14:11:35.947"}}	15	2025-11-19 14:11:36.109528	Auto-saved
135	62	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Cover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T14:11:40.564"}}	15	2025-11-19 14:11:41.063107	Manual save
136	62	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Cover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-11-19T14:14:56.480"}}	15	2025-11-19 14:14:57.134224	Manual save
137	63	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T14:33:52.046"}}	15	2025-11-19 14:33:52.745224	Auto-saved
138	63	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"executive summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T14:34:06.129"}}	15	2025-11-19 14:34:06.43139	Auto-saved
139	63	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"executive summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Risks","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T14:34:16.411"}}	15	2025-11-19 14:34:16.854227	Auto-saved
140	63	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"executive summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Risks","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-11-19T14:34:52.266"}}	15	2025-11-19 14:34:52.890629	Manual save
141	64	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T15:07:29.693"}}	15	2025-11-19 15:07:30.418627	Auto-saved
142	64	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T15:07:43.805"}}	15	2025-11-19 15:07:43.990892	Auto-saved
152	67	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["","","1","0.00","0.00"],["","","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"Pricing table","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-20T13:57:11.303"}}	15	2025-11-20 13:57:11.437494	Auto-saved
143	64	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T15:08:19.949"}}	15	2025-11-19 15:08:20.555256	Manual save
144	65	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T15:25:48.821"}}	15	2025-11-19 15:25:49.625496	Auto-saved
145	65	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T15:26:09.120"}}	15	2025-11-19 15:26:09.273337	Auto-saved
146	65	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T15:26:16.193"}}	15	2025-11-19 15:26:16.638504	Auto-saved
147	66	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T16:41:43.392"}}	15	2025-11-19 16:41:44.094937	Auto-saved
148	66	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T16:42:00.706"}}	15	2025-11-19 16:42:00.864252	Auto-saved
149	66	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T16:43:01.375"}}	15	2025-11-19 16:43:01.872149	Manual save
150	68	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T17:00:53.946"}}	15	2025-11-19 17:00:54.778032	Auto-saved
151	67	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["","","1","0.00","0.00"],["","","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-20T12:43:10.031"}}	15	2025-11-20 12:43:10.458622	Manual save
153	67	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"Pricing table","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-20T14:08:47.440"}}	15	2025-11-20 14:08:47.751082	Auto-saved
154	67	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"Pricing table","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-11-21T15:52:07.709"}}	15	2025-11-21 15:52:07.973416	Manual save
155	67	5	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-11-21T16:39:03.692"}}	15	2025-11-21 16:39:03.855028	Auto-saved
156	67	6	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n<!-- tags: [\\"template\\", \\"proposal\\", \\"risks\\", \\"mitigation\\", \\"module\\"] -->\\n<h1>Risks & Mitigation</h1>\\n<table style=\\"width: 100%; border-collapse: collapse; margin: 20px 0;\\">\\n    <thead>\\n        <tr style=\\"background: #f5f5f5;\\">\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Risk</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Impact</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Likelihood</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Mitigation</th>\\n        </tr>\\n    </thead>\\n    <tbody>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Limited stakeholder availability</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Align early calendars</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Data quality issues</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Early validation</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Changing scope</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Governance checkpoints</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Lack of documentation</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Early analysis and mapping</td>\\n        </tr>\\n    </tbody>\\n</table>","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":7,"last_modified":"2025-11-21T16:39:15.852"}}	15	2025-11-21 16:39:15.999802	Auto-saved
157	67	7	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n<!-- tags: [\\"template\\", \\"proposal\\", \\"risks\\", \\"mitigation\\", \\"module\\"] -->\\n<h1>Risks & Mitigation</h1>\\n<table style=\\"width: 100%; border-collapse: collapse; margin: 20px 0;\\">\\n    <thead>\\n        <tr style=\\"background: #f5f5f5;\\">\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Risk</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Impact</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Likelihood</th>\\n            <th style=\\"padding: 12px; text-align: left; border: 1px solid #ddd;\\">Mitigation</th>\\n        </tr>\\n    </thead>\\n    <tbody>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Limited stakeholder availability</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Align early calendars</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Data quality issues</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Early validation</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Changing scope</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Governance checkpoints</td>\\n        </tr>\\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Lack of documentation</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Medium</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Early analysis and mapping</td>\\n        </tr>\\n    </tbody>\\n</table>\\n\\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":8,"last_modified":"2025-11-21T17:07:27.582"}}	15	2025-11-21 17:07:27.742363	Auto-saved
158	67	8	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n        <tr>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Data quality issues</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">High</td>\\n            <td style=\\"padding: 12px; border: 1px solid #ddd;\\">Early validation</td>\\n        </tr>\\n     \\n</table>\\n\\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":9,"last_modified":"2025-11-21T17:08:06.294"}}	15	2025-11-21 17:08:06.451884	Auto-saved
159	67	9	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":10,"last_modified":"2025-11-21T17:08:13.841"}}	15	2025-11-21 17:08:13.99122	Auto-saved
160	67	10	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-11-21T17:08:37.668"}}	15	2025-11-21 17:08:38.113948	Auto-saved
161	67	11	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":12,"last_modified":"2025-11-21T17:08:53.103"}}	15	2025-11-21 17:08:53.549553	Auto-saved
162	67	12	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\nAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":13,"last_modified":"2025-11-21T17:08:57.788"}}	15	2025-11-21 17:08:58.23033	Auto-saved
163	67	13	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":14,"last_modified":"2025-11-21T17:09:14.538"}}	15	2025-11-21 17:09:14.709595	Auto-saved
173	67	23	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":24,"last_modified":"2025-11-24T11:45:01.232"}}	15	2025-11-24 11:45:01.404888	Manual save
164	67	14	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\nDocumentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":15,"last_modified":"2025-11-21T17:09:23.820"}}	15	2025-11-21 17:09:24.283879	Auto-saved
165	67	15	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\nDocumentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":16,"last_modified":"2025-11-21T17:09:30.964"}}	15	2025-11-21 17:09:31.418633	Auto-saved
166	67	16	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\nDocumentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":17,"last_modified":"2025-11-21T17:09:39.323"}}	15	2025-11-21 17:09:39.916349	Auto-saved
167	67	17	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15},{"type":"price","cells":[["Service Component","Quantity","Rate","Total",""],["Assessment & Discovery","2 Weeks","R {{Rate}}","R {{Total}}",""],["Build & Configuration","4 Weeks","R {{Rate}}","R {{Total}}",""],["UAT & Release","2 Weeks","R {{Rate}}","R {{Total}}",""],["Training & Handover","1 Week","R {{Rate}}","R {{Total}}",""]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":18,"last_modified":"2025-11-21T17:09:49.117"}}	15	2025-11-21 17:09:49.548791	Auto-saved
175	70	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-25T15:21:13.232"}}	15	2025-11-25 15:21:13.963197	Auto-saved
168	67	18	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15},{"type":"price","cells":[["Service Component","Quantity","Rate","Total",""],["Assessment & Discovery","2 Weeks","R {{Rate}}","R {{Total}}",""],["Build & Configuration","4 Weeks","R {{Rate}}","R {{Total}}",""],["UAT & Release","2 Weeks","R {{Rate}}","R {{Total}}",""],["Training & Handover","1 Week","R {{Rate}}","R {{Total}}",""]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":19,"last_modified":"2025-11-21T17:59:44.639"}}	15	2025-11-21 17:59:45.193303	Auto-saved
169	67	19	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15},{"type":"price","cells":[["Service Component","Quantity","Rate","Total",""],["Assessment & Discovery","2 Weeks","R {{Rate}}","R {{Total}}",""],["Build & Configuration","4 Weeks","R {{Rate}}","R {{Total}}",""],["UAT & Release","2 Weeks","R {{Rate}}","R {{Total}}",""],["Training & Handover","1 Week","R {{Rate}}","R {{Total}}",""]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":20,"last_modified":"2025-11-22T17:11:39.989"}}	15	2025-11-22 17:11:40.158871	Auto-saved
170	67	20	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15},{"type":"price","cells":[["Service Component","Quantity","Rate","Total",""],["Assessment & Discovery","2 Weeks","R {{Rate}}","R {{Total}}",""],["Build & Configuration","4 Weeks","R {{Rate}}","R {{Total}}",""],["UAT & Release","2 Weeks","R {{Rate}}","R {{Total}}",""],["Training & Handover","1 Week","R {{Rate}}","R {{Total}}",""]],"vatRate":0.15}]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":21,"last_modified":"2025-11-22T18:04:19.156"}}	15	2025-11-22 18:04:19.320605	Auto-saved
171	67	21	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"hi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":22,"last_modified":"2025-11-24T11:19:59.365"}}	15	2025-11-24 11:19:59.584508	Auto-saved
172	67	22	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":23,"last_modified":"2025-11-24T11:22:38.882"}}	15	2025-11-24 11:22:39.082233	Auto-saved
174	69	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-25T15:09:27.878"}}	15	2025-11-25 15:09:28.597641	Auto-saved
176	71	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"AI, or Artificial Intelligence, is the creation of computer systems that can perform tasks requiring human intelligence, such as learning, problem-solving, and reasoning. Gemini is a specific type of AI developed by Google, which is a large language model that is multimodal, meaning it can process and understand different types of information like text, images, audio, and video. \\nWhat is AI?\\nIt's a field of computer science: AI is a branch of computer science focused on building smart machines that can perform tasks typically done by humans.\\nIt learns from data: Instead of being programmed with a million rules for every situation, AI systems learn patterns from vast amounts of data to make predictions or decisions.\\nIt powers many everyday applications: You encounter AI every day in things like personalized recommendations on shopping sites, spam filters in your email, and navigation apps like Google Maps. \\nWhat is Gemini?\\nIt's a large language model: Gemini is a family of powerful, multimodal AI models from Google.\\nIt's multimodal: It can understand and combine different types of information, including text, code, audio, images, and video.\\nIt's a conversational AI: Gemini can be used as a chatbot to help you brainstorm, write, research, and more, by understanding natural language.\\nIt's being integrated into Google products: Gemini is the AI assistant in some Google Pixel phones and is also integrated into Google Workspace, where it can help with writing and summarizing documents in Docs or drafting emails in Gmail. ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T10:33:17.345"}}	15	2025-11-26 10:33:18.170239	Auto-saved
177	72	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T15:53:00.494"}}	15	2025-11-26 15:53:01.342512	Auto-saved
178	72	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi how are you","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-26T15:59:02.301"}}	15	2025-11-26 15:59:02.452396	Auto-saved
179	73	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"AI refers to artificial intelligence, a broad field of computer science focused on building machines capable of performing tasks that typically require human intelligence, such as understanding natural language, recognizing images, and making decisions. \\nAI on Google Search is powered by the Gemini family of models. \\nUnderstanding AI\\nArtificial Narrow Intelligence (ANI): This is the only form of AI that exists now. ANI systems are made to do one specific task very well, such as filtering emails, recognizing faces, or having a chatbot conversation.\\nHow it works: AI uses large amounts of data with advanced algorithms, like large language models (LLMs). This helps AI learn patterns, make predictions, and create content within set rules. AI does not have consciousness or self-awareness.\\nGenerative AI: This type of AI, which includes Gemini, can create new content like text, images, code, and video, based on what a user asks for. \\nWhat is Google Gemini? \\nGemini is the name for the large language models (LLMs) created by Google DeepMind. Key aspects of Gemini include: \\nMultimodality: Gemini can process and combine different types of information, including text, images, audio, video, and code.\\nAssistant: The Gemini app and web interface function as an AI assistant, helping with tasks like writing emails, brainstorming, summarizing information, and controlling smart home devices.\\nIntegration: The technology is used in several Google products, such as Google Search, Chrome, Gmail, Docs, and Android phones, to provide helpful features.\\nModels: Google offers different versions of the model, such as Gemini 2.5 Flash (for speed) and 3 Pro (for complex tasks and advanced reasoning). These are available on the Gemini website or through various subscription plans and developer APIs. \\nIn short, AI is the technology that simulates intelligent behavior, and Gemini is Google's specific implementation of that technology designed to be a helpful assistant. \\n\\n\\n\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T16:53:09.734"}}	15	2025-11-26 16:53:10.53542	Auto-saved
180	74	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dfghfdvencfekjfncewjnfefervrf","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T17:25:22.455"}}	15	2025-11-26 17:25:22.909522	Auto-saved
181	75	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T18:43:20.623"}}	15	2025-11-26 18:43:21.351319	Auto-saved
182	76	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"H","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T21:07:16.206"}}	15	2025-11-26 21:07:16.653461	Auto-saved
183	76	2	{"title":"","sections":[{"title":"Untitled Section","content":"H","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-26T21:12:45.889"}}	15	2025-11-26 21:12:46.048267	Auto-saved
184	76	3	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"H","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-26T21:12:57.078"}}	15	2025-11-26 21:12:57.377342	Auto-saved
185	76	4	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"H","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-11-26T21:13:01.304"}}	15	2025-11-26 21:13:01.790923	Auto-saved
186	75	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-27T16:04:06.851"}}	15	2025-11-27 16:04:07.033563	Auto-saved
187	76	5	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"H\\n[Table]\\n[Column 1] | [Column 2] | [Column 3]\\n[Row 1] | [Data] | [Data]\\n[Row 2] | [Data] | [Data]","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":6,"last_modified":"2025-11-27T16:42:51.420"}}	15	2025-11-27 16:42:51.602717	Auto-saved
188	76	6	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"H\\n[Table]\\n[Column 1] | [Column 2] | [Column 3]\\n[Row 1] | [Data] | [Data]\\n[Row 2] | [Data] | [Data]","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":7,"last_modified":"2025-11-27T16:42:59.592"}}	15	2025-11-27 16:42:59.77319	Auto-saved
189	76	7	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":8,"last_modified":"2025-11-27T16:43:07.720"}}	15	2025-11-27 16:43:07.890864	Auto-saved
190	76	8	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\nSignature (Manager Approval): __________________ Date: __________\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":9,"last_modified":"2025-11-27T17:47:14.955"}}	15	2025-11-27 17:47:15.144595	Auto-saved
191	76	9	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":10,"last_modified":"2025-11-27T17:47:43.760"}}	15	2025-11-27 17:47:43.92533	Auto-saved
192	76	10	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-11-27T17:54:37.557"}}	15	2025-11-27 17:54:37.817172	Auto-saved
193	76	11	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":12,"last_modified":"2025-11-27T17:55:17.186"}}	15	2025-11-27 17:55:17.33821	Auto-saved
194	76	12	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":13,"last_modified":"2025-11-27T17:55:21.970"}}	15	2025-11-27 17:55:22.164054	Auto-saved
195	76	13	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nProject Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":14,"last_modified":"2025-12-01T13:39:44.580"}}	15	2025-12-01 13:39:44.733147	Auto-saved
208	78	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nGo-Live & Support Khonology ensures a smooth production rollout supported by hypercare and operational enablement. Includes Release management Post-deployment support Knowledge transfer Operational handover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section (Copy)","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-12-03T21:10:18.355"}}	15	2025-12-03 21:10:18.858347	Auto-saved
196	76	14	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"\\n\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nProject Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":15,"last_modified":"2025-12-01T13:40:18.379"}}	15	2025-12-01 13:40:18.555249	Auto-saved
197	76	15	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"Project Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":16,"last_modified":"2025-12-01T13:40:38.447"}}	15	2025-12-01 13:40:38.892053	Auto-saved
198	76	16	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"Project Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":17,"last_modified":"2025-12-01T13:40:54.801"}}	15	2025-12-01 13:40:55.258389	Auto-saved
199	76	17	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"Project Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs. Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":18,"last_modified":"2025-12-01T13:41:06.358"}}	15	2025-12-01 13:41:06.827729	Auto-saved
209	79	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-12-04T09:27:11.610"}}	15	2025-12-04 09:27:12.421028	Auto-saved
200	76	18	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"Project Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs. Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":19,"last_modified":"2025-12-01T14:27:34.800"}}	15	2025-12-01 14:27:35.304126	Manual save
201	77	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-12-03T15:25:14.061"}}	15	2025-12-03 15:25:14.531328	Auto-saved
202	77	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-12-03T15:25:22.380"}}	15	2025-12-03 15:25:22.650087	Auto-saved
203	77	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Risk Assessment\\n\\nCritical Risks and Mitigation Strategies:\\n\\n1. Decision-Making Delays\\n• Risk: Extended approval cycles may impact project timelines\\n• Mitigation: Implement streamlined approval processes with 48-hour response targets\\n\\n2. Third-Party Dependencies\\n• Risk: Integration failures or vendor delays may create bottlenecks\\n• Mitigation: Establish vendor SLAs and maintain redundant supplier relationships\\n\\n3. Scope Management\\n• Risk: Unclear requirements may lead to costly rework\\n• Mitigation: Implement detailed scope documentation and weekly scope review sessions\\n\\n4. User Adoption\\n• Risk: Low user engagement may compromise ROI\\n• Mitigation: Develop comprehensive change management plan with regular training sessions","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-12-03T15:27:03.151"}}	15	2025-12-03 15:27:03.30631	Auto-saved
204	77	4	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Risk Assessment\\n\\nCritical Risks and Mitigation Strategies:\\n\\n1. Decision-Making Delays\\n• Risk: Extended approval cycles may impact project timelines\\n• Mitigation: Implement streamlined approval processes with 48-hour response targets\\n\\n2. Third-Party Dependencies\\n• Risk: Integration failures or vendor delays may create bottlenecks\\n• Mitigation: Establish vendor SLAs and maintain redundant supplier relationships\\n\\n3. Scope Management\\n• Risk: Unclear requirements may lead to costly rework\\n• Mitigation: Implement detailed scope documentation and weekly scope review sessions\\n\\n4. User Adoption\\n• Risk: Low user engagement may compromise ROI\\n• Mitigation: Develop comprehensive change management plan with regular training sessions","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-12-03T15:28:14.659"}}	15	2025-12-03 15:28:15.313413	Manual save
205	78	1	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-12-03T21:09:52.982"}}	15	2025-12-03 21:09:53.468142	Auto-saved
206	78	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section (Copy)","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-12-03T21:10:03.994"}}	15	2025-12-03 21:10:04.164139	Auto-saved
207	78	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section (Copy)","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-12-03T21:10:10.694"}}	15	2025-12-03 21:10:11.177083	Auto-saved
210	79	2	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nCommercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-12-04T09:27:16.806"}}	15	2025-12-04 09:27:16.96363	Auto-saved
211	79	3	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nCommercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-12-04T09:28:01.144"}}	15	2025-12-04 09:28:01.682293	Manual save
\.


--
-- Data for Name: proposals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proposals (id, user_id, title, content, status, client_name, client_email, budget, timeline_days, created_at, updated_at) FROM stdin;
62	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Cover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T14:14:56.108"}}	Sent to Client	RMB	umsibanda.1994@gmail.com	\N	\N	2025-11-19 14:11:16.715708	2025-11-19 14:16:22.50043
49	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-17T22:54:01.714"}}	Sent to Client	Standard Bank	umsibanda.1994@gmail.com	\N	\N	2025-11-14 15:40:44.674711	2025-11-19 14:22:18.401726
45	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"creajs ckd dekmckdmsd cdsc","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-09T21:05:25.993"}}	Sent to Client	ZukhanyeInc	umsibanda.1994@gmail.com	\N	\N	2025-11-09 21:04:55.981436	2025-11-09 21:07:37.075004
30	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n1. Client Environment\\n• Adequate infrastructure availability\\n• Access to necessary systems and data\\n• Stable network connectivity\\n\\n2. Project Support\\n• Timely decision-making from stakeholders\\n• Available subject matter experts\\n• Dedicated project team members\\n\\n3. Technical Requirements\\n• Compatible existing systems\\n• Required licenses and permissions\\n• Adequate testing environments\\n\\nDependencies:\\n• Client resource availability\\n• Third-party system integration\\n• Regulatory approvals\\n• Hardware/software procurement\\n• Stakeholder sign-offs","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"Total Project Investment: R2.5 million\\n\\nBreakdown:\\n1. Technology Implementation: R1,200,000\\n• Software development\\n• System integration\\n• Infrastructure setup\\n\\n2. Training & Development: R600,000\\n• Technical training\\n• Leadership development\\n• Change management\\n\\n3. Support & Maintenance: R400,000\\n• 12 months support\\n• System updates\\n• Performance optimization\\n\\n4. Project Management: R300,000\\n• Team coordination\\n• Documentation\\n• Quality assurance\\n\\nPayment Schedule:\\n• Initial payment: R500,000\\n• Monthly payments: R166,666 (12 months)\\n\\nAll prices are in South African Rand (ZAR) and exclude VAT.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a hybrid agile methodology that combines best practices from various frameworks:\\n\\n1. Project Initiation\\n• Stakeholder engagement\\n• Requirements gathering\\n• Project charter development\\n\\n2. Iterative Development\\n• Two-week sprint cycles\\n• Regular client feedback\\n• Continuous integration\\n\\n3. Quality Assurance\\n• Automated testing\\n• User acceptance testing\\n• Performance monitoring\\n\\n4. Implementation\\n• Phased rollout approach\\n• Risk-managed deployment\\n• User training and support\\n\\nOur methodology emphasizes:\\n• Regular communication\\n• Transparent progress tracking\\n• Flexible adaptation to changing needs\\n• Knowledge transfer throughout the project","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and professional development. This proposal outlines our comprehensive approach to delivering innovative solutions that drive business growth and operational excellence. With over a decade of experience serving major financial institutions and corporations across Africa, Khonology combines deep industry expertise with cutting-edge technology to create sustainable value for our clients. Our proposed engagement framework encompasses technology implementation, skills development, and organizational change management, with an estimated investment of R2.5 million over 12 months. This partnership will enable our clients to leverage emerging technologies, develop critical capabilities, and achieve their strategic objectives while maintaining competitive advantage in an increasingly digital marketplace. khokhvkkhhv","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Founded in 2013 and headquartered in Johannesburg, Khonology has established itself as a premier technology solutions partner for Africa's leading organizations. Our company's core focus areas include:\\n\\n• Financial Technology Solutions\\n• Digital Transformation\\n• Professional Development & Training\\n• Technology Consulting Services\\n• Change Management\\n\\nKhonology has successfully delivered over 200 projects across Southern Africa, working with major banks, insurance companies, and financial services providers. Our track record includes implementing core banking systems, developing custom fintech solutions, and training over 5,000 professionals in various technology disciplines. The company maintains strategic partnerships with global technology leaders and local institutions, ensuring access to world-class solutions and methodologies adapted for African markets.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive solution package comprising:\\n\\n1. Technology Implementation\\n• Custom software development and integration\\n• Cloud migration services\\n• Digital platform development\\n\\n2. Skills Enhancement Program\\n• Technical training modules\\n• Leadership development workshops\\n• Digital literacy courses\\n\\n3. Change Management Support\\n• Organizational readiness assessment\\n• Change impact analysis\\n• Stakeholder management\\n\\n4. Ongoing Support & Maintenance\\n• 24/7 technical support\\n• Regular system updates\\n• Performance monitoring\\n\\nOur solution is designed to be scalable, adaptable, and aligned with international best practices while considering local market conditions and requirements.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks\\n• Risk: System compatibility issues\\n• Mitigation: Comprehensive testing and POC phase\\n\\n2. Timeline Risks\\n• Risk: Project delays\\n• Mitigation: Buffer periods and resource optimization\\n\\n3. Resource Risks\\n• Risk: Key personnel availability\\n• Mitigation: Cross-training and backup resources\\n\\n4. Change Management Risks\\n• Risk: User resistance\\n• Mitigation: Early engagement and training programs\\n\\n5. Integration Risks\\n• Risk: Third-party system issues\\n• Mitigation: Detailed integration planning and testing","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"The project scope encompasses:\\n\\nPhase 1: Assessment & Planning\\n• Detailed requirements analysis\\n• Solution architecture design\\n• Project plan development\\n\\nPhase 2: Implementation\\n• Technology platform deployment\\n• Integration with existing systems\\n• User training and documentation\\n\\nPhase 3: Training & Development\\n• Technical skills training\\n• Leadership development programs\\n• Change management workshops\\n\\nPhase 4: Support & Optimization\\n• Post-implementation support\\n• Performance monitoring\\n• Continuous improvement initiatives\\n\\nKey Deliverables:\\n• Detailed project documentation\\n• Implemented technology solutions\\n• Training materials and certificates\\n• Support and maintenance documentation","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Our project team consists of highly qualified professionals:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience\\n• Technical Lead: 12+ years experience\\n• Change Management Lead: 10+ years experience\\n\\nTechnical Team:\\n• Senior Developers (4)\\n• System Architects (2)\\n• Integration Specialists (2)\\n• Quality Assurance Engineers (2)\\n\\nSupport Team:\\n• Training Specialists (2)\\n• Change Management Consultants (2)\\n• Technical Support Engineers (3)\\n\\nAll team members are certified in relevant technologies and methodologies, with extensive experience in similar projects across Africa.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Contract Duration\\n• Initial term: 12 months\\n• Option to extend based on mutual agreement\\n\\n2. Payment Terms\\n• Initial payment: Upon contract signing\\n• Monthly payments: End of each month\\n• 30-day payment terms\\n\\n3. Deliverables\\n• All deliverables subject to client approval\\n• Change requests handled through formal process\\n\\n4. Intellectual Property\\n• Client owns final deliverables\\n• Khonology retains methodology rights\\n\\n5. Confidentiality\\n• NDA covers all project information\\n• Data protection compliance\\n\\n6. Termination\\n• 60-day notice period\\n• Transition support included","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months:\\n\\nMonth 1-2: Project Initiation\\n• Project planning\\n• Requirements finalization\\n• Team mobilization\\n\\nMonth 3-6: Development & Implementation\\n• Solution development\\n• Integration testing\\n• Initial deployments\\n\\nMonth 7-9: Training & Change Management\\n• User training programs\\n• Change management activities\\n• Process optimization\\n\\nMonth 10-12: Optimization & Handover\\n• Performance tuning\\n• Documentation completion\\n• Support transition\\n\\nKey Milestones:\\n• Project kickoff: Month 1\\n• First deployment: Month 4\\n• Training completion: Month 8\\n• Project completion: Month 12","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our analysis and industry expertise, we understand that organizations in today's rapidly evolving digital landscape require:\\n\\n1. Digital Transformation Solutions\\n• Modernization of legacy systems\\n• Integration of emerging technologies\\n• Enhanced customer experience platforms\\n\\n2. Skills Development\\n• Technical training and certification\\n• Leadership development\\n• Digital literacy programs\\n\\n3. Change Management\\n• Organizational transformation support\\n• Process optimization\\n• Cultural change initiatives\\n\\n4. Technology Implementation\\n• Custom software development\\n• System integration\\n• Infrastructure modernization\\n\\nWe recognize the critical importance of delivering solutions that are not only technologically advanced but also culturally aligned and sustainable within the African context.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-27T18:49:12.459"}}	Sent to Client	Apple Inc	sheziluthando513@gmail.com	\N	\N	2025-10-24 14:59:59.220827	2025-10-27 22:09:51.927182
63	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"executive summary","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Risks","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T14:34:51.903"}}	Client Declined	RMBS	umsibanda.1994@gmail.com	\N	\N	2025-11-19 14:33:51.820821	2025-11-19 16:00:14.422386
29	zukhanye@gmail.com	Temp2	{"title":"Temp2","sections":[{"title":"Assumptions & Dependencies","content":"Key Assumptions:\\n\\n1. Project Environment:\\n• Business operations will maintain 99.9% uptime during implementation (as per Khonology's standard SLA)\\n• Stakeholders will provide responses within 2 business days (based on SAST timezone)\\n• IT team will provide system access within 24 hours of request\\n• Infrastructure capacity exceeds projected peak loads by 30% to ensure optimal performance\\n\\n2. Resource Availability:\\n• Stakeholders will make decisions within 3 business days\\n• Subject matter experts will dedicate 20 hours per week to the project (half of standard work week)\\n• Test environments will mirror production with 95% data accuracy\\n• Third-party vendors will provide support per signed SLAs with 4-hour response time during South African business hours\\n\\nDependencies:\\n\\n1. Technical Dependencies:\\n• Security team will grant system access within 5 business days of request (compliant with POPIA requirements)\\n• Third-party systems will maintain 99.5% integration uptime\\n• Infrastructure will support peak loads of 10,000 concurrent users\\n• Data quality will maintain 98% accuracy rate with daily validation\\n\\n2. Business Dependencies:\\n• Business analysts will provide updated process documentation by project kickoff\\n• 90% of users will participate in each testing phase\\n• Change management team will execute communication plan within 24 hours of major milestones\\n• All users will complete required training two weeks before go-live\\n\\nContingency Plans:\\n• Primary and secondary backup SMEs identified for each critical role\\n• Documented escalation procedures for missed SLAs, including:\\n  - First-level response within 1 hour\\n  - Management escalation within 4 hours\\n  - Executive escalation within 8 hours\\n• Alternative testing schedules prepared for resource conflicts\\n• Emergency response team available during critical implementation phases\\n• Local disaster recovery procedures aligned with business continuity requirements","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Budget & Pricing","content":"The total investment for this digital transformation initiative is structured as follows:\\n\\n1. Professional Services: $800,000\\n• Project Management: $150,000\\n• Technical Implementation: $400,000\\n• Change Management: $150,000\\n• Training & Documentation: $100,000\\n\\n2. Technology Costs: $300,000\\n• Software Licenses: $150,000\\n• Infrastructure Setup: $100,000\\n• Security Implementation: $50,000\\n\\n3. Contingency: $100,000\\n\\nTotal Project Investment: $1,200,000\\n\\nPayment Schedule:\\n• 30% upon project initiation\\n• 40% spread across implementation milestones\\n• 30% upon project completion\\n\\nAll prices are exclusive of applicable taxes and travel expenses.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Delivery Approach & Methodology","content":"Khonology employs a proven agile delivery methodology that ensures consistent quality and timely delivery:\\n\\n1. Discovery Phase:\\n• Requirements gathering and analysis\\n• Stakeholder interviews\\n• Current state assessment\\n• Solution design workshops\\n\\n2. Design Phase:\\n• Architecture design\\n• Process mapping\\n• Solution blueprinting\\n• Prototype development\\n\\n3. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous testing and validation\\n• Change management activities\\n\\n4. Deployment Phase:\\n• User acceptance testing\\n• Training and knowledge transfer\\n• Go-live support\\n• Performance monitoring\\n\\nOur methodology incorporates best practices from PMBOK, Agile, and ITIL frameworks, ensuring robust project governance and quality delivery.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"Khonology, a leading digital transformation consultancy, presents this comprehensive proposal outlining our innovative approach to delivering technology-driven solutions. With over a decade of experience in the industry, we specialize in bridging the gap between business objectives and technological implementation. This proposal details our methodology, expertise, and commitment to delivering exceptional value to our clients.\\n\\nOur proven track record includes successful partnerships with Fortune 500 companies, financial institutions, and emerging enterprises across multiple sectors. We propose a strategic framework that combines our proprietary methodologies, industry best practices, and cutting-edge technologies to drive sustainable digital transformation. Our solution encompasses comprehensive change management, technology implementation, and continuous improvement processes.\\n\\nThe proposed engagement will be delivered by our team of certified professionals, leveraging our global delivery network and local expertise. We estimate a project timeline of 12 months with a total investment of $1.2M, providing an expected ROI of 300% within the first 24 months of implementation. Our commitment to excellence, coupled with our innovative approach and deep industry knowledge, positions us as the ideal partner for your digital transformation journey.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Introduction & Background","content":"Khonology was founded in 2010 with a vision to revolutionize how businesses approach digital transformation. Our journey began with a focus on financial services technology consulting, and we have since expanded our expertise across multiple industries and technological domains. Today, we stand as a trusted partner to over 200 clients globally, with offices in 15 countries and a team of more than 1,000 professionals.\\n\\nOur core philosophy centers on the belief that successful digital transformation requires a holistic approach that combines technical excellence with deep business understanding. We have developed proprietary methodologies and frameworks that enable organizations to navigate complex digital transformations while minimizing risks and maximizing value.\\n\\nKhonology's track record includes:\\n• Successfully completing over 500 major digital transformation projects\\n• Maintaining a 95% client retention rate\\n• Achieving numerous industry certifications and partnerships\\n• Developing innovative solutions that have become industry standards\\n\\nOur understanding of current market dynamics, emerging technologies, and business challenges positions us uniquely to deliver solutions that drive sustainable competitive advantage for our clients.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Proposed Solution","content":"Khonology proposes a comprehensive digital transformation solution that addresses all identified requirements through a multi-layered approach:\\n\\n1. Digital Foundation Layer:\\n• Cloud infrastructure implementation using AWS/Azure\\n• Microservices architecture for improved scalability\\n• API-first design approach for system integration\\n\\n2. Process Automation Layer:\\n• RPA implementation for routine tasks\\n• AI/ML solutions for intelligent automation\\n• Workflow optimization and standardization\\n\\n3. Data Analytics Layer:\\n• Real-time analytics dashboard\\n• Predictive modeling capabilities\\n• Data governance framework\\n\\n4. User Experience Layer:\\n• Intuitive interface design\\n• Mobile-first approach\\n• Personalized user journeys\\n\\nOur solution incorporates industry best practices and leverages cutting-edge technologies while ensuring seamless integration with existing systems. The modular design allows for phased implementation and future scalability.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Risks & Mitigation","content":"Identified Risks and Mitigation Strategies:\\n\\n1. Technical Risks:\\n• Legacy System Integration\\n  - Mitigation: Detailed assessment and backup plans\\n  - Contingency testing and rollback procedures\\n\\n2. Operational Risks:\\n• Business Disruption\\n  - Mitigation: Phased implementation approach\\n  - Comprehensive testing before deployment\\n\\n3. Resource Risks:\\n• Skill Availability\\n  - Mitigation: Cross-training team members\\n  - Maintaining backup resource pool\\n\\n4. Change Management Risks:\\n• User Adoption\\n  - Mitigation: Early stakeholder engagement\\n  - Comprehensive training program\\n\\nRisk monitoring and management will be ongoing throughout the project lifecycle, with regular risk assessment reviews and updates to mitigation strategies.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Scope & Deliverables","content":"Project Scope:\\n\\n1. Technology Implementation:\\n• System architecture design and implementation\\n• Integration with existing systems\\n• Security and compliance framework\\n• Testing and quality assurance\\n\\n2. Process Transformation:\\n• Business process reengineering\\n• Workflow automation\\n• Performance monitoring systems\\n\\n3. Change Management:\\n• Training materials and programs\\n• User adoption strategy\\n• Support documentation\\n\\nKey Deliverables:\\n\\n1. Technical Deliverables:\\n• Detailed system architecture\\n• Implemented software solutions\\n• Integration documentation\\n• Security protocols\\n\\n2. Business Deliverables:\\n• Process maps and workflows\\n• Performance dashboards\\n• ROI analysis reports\\n\\n3. Documentation:\\n• User manuals\\n• Training materials\\n• Support documentation\\n• Maintenance guides","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Team & Expertise","content":"Khonology will deploy a highly skilled team with extensive experience in digital transformation:\\n\\nLeadership Team:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Architect: Certified in cloud platforms and enterprise architecture\\n• Business Analyst Lead: Expert in process optimization and requirements analysis\\n\\nDelivery Team:\\n• 4 Senior Developers (Full-stack)\\n• 2 UX/UI Specialists\\n• 2 Data Engineers\\n• 2 Quality Assurance Engineers\\n• 1 Security Specialist\\n\\nSupport Team:\\n• Change Management Specialist\\n• Training Coordinator\\n• Documentation Specialist\\n\\nAll team members are certified in relevant technologies and methodologies, including:\\n• Cloud platforms (AWS/Azure)\\n• Agile methodologies\\n• Security frameworks\\n• Industry-specific certifications","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Terms & Conditions","content":"1. Service Level Agreement:\\n• Response time commitments\\n• Issue resolution timeframes\\n• Performance metrics\\n• Support availability\\n\\n2. Intellectual Property:\\n• All custom development ownership transfers to client\\n• Pre-existing IP remains with respective owners\\n• License terms for third-party software\\n\\n3. Confidentiality:\\n• Non-disclosure agreements\\n• Data protection measures\\n• Information security protocols\\n\\n4. Contract Terms:\\n• 12-month initial contract period\\n• 90-day notice for termination\\n• Change request procedures\\n• Dispute resolution process\\n\\n5. Warranty:\\n• 90-day warranty period post-implementation\\n• Bug fixes and critical updates\\n• Support terms and conditions\\n\\nDetailed terms and conditions will be provided in the final contract document.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Timeline & Milestones","content":"The project will be executed over 12 months, with the following key milestones:\\n\\nPhase 1: Discovery & Planning (Months 1-2)\\n• Project kickoff\\n• Requirements finalization\\n• Solution design approval\\n• Project plan baseline\\n\\nPhase 2: Design & Development (Months 3-6)\\n• Architecture implementation\\n• Core system development\\n• Integration development\\n• Initial testing\\n\\nPhase 3: Implementation & Testing (Months 7-9)\\n• System integration\\n• User acceptance testing\\n• Training program execution\\n• Performance optimization\\n\\nPhase 4: Deployment & Stabilization (Months 10-12)\\n• Production deployment\\n• Go-live support\\n• Performance monitoring\\n• Project closure\\n\\nEach milestone includes specific deliverables and success criteria that will be tracked and reported regularly.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Understanding of Requirements","content":"Based on our extensive analysis and discussions, we have identified the following key requirements for this digital transformation initiative:\\n\\n1. Business Process Optimization:\\n• Streamline existing workflows and eliminate redundancies\\n• Implement automated solutions for routine tasks\\n• Establish clear performance metrics and monitoring systems\\n\\n2. Technology Infrastructure:\\n• Modernize legacy systems while ensuring business continuity\\n• Implement cloud-based solutions for improved scalability\\n• Enhance security protocols and compliance measures\\n\\n3. Change Management:\\n• Develop comprehensive training programs\\n• Establish clear communication channels\\n• Create support systems for user adoption\\n\\n4. Data Management:\\n• Implement robust data governance frameworks\\n• Enhance data analytics capabilities\\n• Ensure compliance with regulatory requirements\\n\\nOur understanding encompasses both immediate operational needs and long-term strategic objectives, ensuring that our proposed solution addresses current challenges while building foundations for future growth.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":60,"last_modified":"2025-10-27T22:22:07.114"}}	Sent to Client	Hackathon	sheziluthando513@gmail.com	\N	\N	2025-10-23 02:24:14.481723	2025-10-27 22:23:23.479493
28	zukhanye@gmail.com	Template	{"title":"Template","sections":[{"title":"Cover","content":"I want to create a proposal for my business to be as successful as i am i cannot streched the level of success that i want\\n\\nExecutive Summary\\n\\nIn today's competitive retail landscape, delivering exceptional customer experiences while maintaining operational efficiency is paramount to success. We understand your organization's need for a modern, integrated Customer Relationship Management (CRM) solution that can transform your customer interactions and drive sustainable growth.\\n\\nKhonology is pleased to present this comprehensive proposal for implementing a state-of-the-art CRM system tailored to your retail operations. Our solution addresses your key challenges and objectives:\\n\\n• Fragmented customer data across multiple systems\\n• Limited visibility into customer buying patterns and preferences\\n• Inefficient sales and marketing processes\\n• Need for improved customer service capabilities\\n• Lack of actionable insights for decision-making\\n\\nOur proposed solution leverages industry-leading CRM technology combined with Khonology's proven implementation methodology to deliver:\\n\\n• A unified 360-degree view of customer interactions and transactions\\n• Automated sales and marketing workflows\\n• Advanced analytics and reporting capabilities\\n• Seamless integration with existing retail systems\\n• Mobile access for staff and field teams\\n\\nDrawing on our extensive experience in retail technology implementations, we will execute this project in three phases over 16 weeks, ensuring minimal disruption to your operations. Our approach includes comprehensive staff training and change management support to drive rapid adoption and maximize return on investment.\\n\\nKey benefits you can expect:\\n• 25-30% increase in sales team productivity\\n• Improved customer satisfaction and retention rates\\n• Enhanced marketing campaign effectiveness\\n• Real-time access to customer insights\\n• Reduced operational costs through process automation\\n\\nWith Khonology as your implementation partner, you gain access to our retail industry expertise, technical excellence, and unwavering commitment to your success. Our team of certified professionals will work closely with your stakeholders to ensure the solution meets your current needs while providing scalability for future growth.\\n\\nWe look forward to partnering with you on this transformative initiative and helping your organization achieve its customer experience and business objectives.\\n\\nProject Risks and Mitigation Strategies\\n\\nAt Khonology, we believe in transparent communication regarding potential risks and maintaining robust mitigation strategies to ensure project success. Based on our extensive experience in professional services, we have identified the following key risks and corresponding mitigation approaches:\\n\\nResource-Related Risks\\n• Skill availability: Critical resources may become unavailable due to illness or departure\\n- Mitigation: We maintain deep bench strength and cross-train team members to ensure knowledge redundancy\\n- Implementation of comprehensive knowledge management and documentation practices\\n- Established partnerships with trusted contractors for surge capacity\\n\\nTechnical Risks\\n• Integration complexity: Systems may present unexpected integration challenges\\n- Mitigation: Early technical assessment and proof-of-concept testing\\n- Leveraging our extensive experience with similar implementations\\n- Maintaining close relationships with technology vendors for support\\n\\nTimeline Risks\\n• Scope changes: Project scope may evolve, impacting delivery schedules\\n- Mitigation: Robust change management process\\n- Regular stakeholder alignment sessions\\n- Buffer time built into project planning\\n\\nOperational Risks\\n• Business process disruption: Implementation may impact daily operations\\n- Mitigation: Carefully planned deployment windows\\n- Comprehensive testing prior to implementation\\n- Detailed rollback procedures if needed\\n\\nData Security Risks\\n• Information security: Protection of sensitive client data\\n- Mitigation: Adherence to industry security standards and best practices\\n- Regular security audits and updates\\n- Encrypted data transmission and storage\\n\\nOur risk management approach includes:\\n1. Weekly risk assessment reviews\\n2. Proactive identification of emerging risks\\n3. Regular stakeholder communication about risk status\\n4. Documented escalation procedures\\n5. Continuous monitoring and adjustment of mitigation strategies\\n\\nThrough this comprehensive risk management framework, Khonology maintains a proactive stance in identifying, assessing, and mitigating potential challenges before they impact project delivery or client operations. Our track record demonstrates the effectiveness of these strategies in ensuring successful project outcomes.\\n[Table]\\n[Column 1] | [Column 2] | [Column 3]\\n[Row 1] | [Data] | [Data]\\n[Row 2] | [Data] | [Data]","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Investment","content":"The proposal should be on par with tables for prices and text","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Hey, how are you ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":15,"last_modified":"2025-10-27T23:04:49.992"}}	Sent to Client	UnathiTech	sheziluthando513@gmail.com	\N	\N	2025-10-23 02:23:00.65182	2025-10-27 23:06:18.3899
46	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi hi hi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-12T22:18:05.281"}}	Sent to Client	Unathi	umsibanda.1994@gmail.com	\N	\N	2025-11-12 22:17:36.162342	2025-11-12 22:18:37.396974
68	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-19T17:01:29.646"}}	Sent to Client	Dhlamini Corp	sheziluthando513@gmail.com	\N	\N	2025-11-19 17:00:53.370828	2025-11-19 17:02:17.205563
27	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Cover","content":"I want to create a proposal for my business","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":1,"last_modified":"2025-10-28T14:11:58.875"}}	Sent to Client	UnathiInc	umsibanda.1994@gmail.com	\N	\N	2025-10-23 02:22:20.988241	2025-10-28 14:12:42.196349
74	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dfghfdvencfekjfncewjnfefervrf","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T17:25:44.424"}}	Sent for Signature	BrandBrands	umsibanda.1994@gmail.com	\N	\N	2025-11-26 17:25:21.036018	2025-11-27 15:31:34.220005
43	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dfvfbgnhnhn","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-07T15:12:02.678"}}	Sent to Client	Unathi	learner.hackathon@gmail.com	\N	\N	2025-11-07 15:08:35.319489	2025-11-07 15:14:18.907061
41	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to create a proposal","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"what is the version about","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-09T20:36:14.952"}}	Sent to Client	UnathiInc	umsibanda.1994@gmail.com	\N	\N	2025-11-07 14:01:58.528787	2025-11-09 20:36:37.37001
47	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes yes","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-13T10:15:20.098"}}	Sent to Client	CCME	umsibanda.1994@gmail.com	\N	\N	2025-11-13 10:08:34.033215	2025-11-13 10:17:37.638181
48	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Hi my name is Unathi","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-18T01:03:25.448"}}	Sent to Client	Absa	umsibanda.1994@gmail.com	\N	\N	2025-11-13 22:05:47.012269	2025-11-19 12:39:06.98772
31	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Introduction: The Khonology Approach\\n\\nIn today's rapidly evolving business landscape, organisations face unprecedented challenges in digital transformation, operational efficiency, and talent development. Khonology, as a proudly South African professional services firm, has established itself as a trusted partner in delivering innovative solutions that bridge the gap between technology and business outcomes.\\n\\nFounded on the principles of knowledge transfer and sustainable transformation, Khonology brings a unique perspective to professional services delivery. Our approach combines local market understanding with global best practices, ensuring solutions that are both world-class and contextually relevant to the South African business environment.\\n\\nWhat sets Khonology apart is our commitment to:\\n\\n• Knowledge-driven transformation: We believe in not just implementing solutions but embedding sustainable knowledge within our client organisations\\n• Local talent development: Our investment in South African talent ensures solutions that understand local nuances while meeting international standards\\n• Innovation with purpose: We leverage cutting-edge technologies and methodologies while maintaining focus on practical, value-driven outcomes\\n• Sustainable partnerships: We build lasting relationships that extend beyond project delivery to create long-term value\\n\\nOur track record of successful implementations across various sectors has demonstrated our ability to deliver tangible results while maintaining cost-effectiveness. With project values ranging from R500,000 to R50 million, we have consistently shown our capability to handle both focused interventions and large-scale transformations.\\n\\nThis proposal outlines how Khonology's ways of working can bring value to your organisation through our proven methodologies, experienced professionals, and commitment to excellence. We understand that each client's needs are unique, and our flexible approach ensures that solutions are tailored to your specific requirements while maintaining the rigour and quality that defines the Khonology brand.\\n\\nLet us demonstrate how our distinctive approach can help your organisation achieve its strategic objectives while building sustainable internal capabilities.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-10-27T18:06:00.235"}}	Sent to Client	HackTech	sheziluthando513@gmail.com	\N	\N	2025-10-27 15:52:58.32546	2025-10-27 22:19:44.934215
32	zukhanye@gmail.com	ent	{"title":"ent","sections":[{"title":"Untitled Section","content":"hey i am proposal one, i want to add proposal 2","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nKhonology is pleased to present this proposal outlining our comprehensive professional services offering. As a leading South African technology consulting firm, we bring extensive experience in digital transformation, business process optimization, and technology implementation to help organizations achieve their strategic objectives.\\n\\nWith over a decade of experience serving clients across multiple sectors including financial services, telecommunications, and retail, Khonology has established itself as a trusted partner in delivering innovative solutions that drive measurable business value. Our team of highly skilled consultants combines deep technical expertise with practical business acumen to ensure successful project outcomes.\\n\\nKey highlights of our value proposition include:\\n\\n• Local expertise with global standards: Our South African-based team understands the unique challenges and opportunities in the local market while maintaining international best practices\\n• Proven methodology: Our proprietary delivery framework ensures consistent, high-quality results across all engagements\\n• Cost-effective solutions: We offer competitive rates starting from R1,500 per hour, with flexible engagement models to suit various budget requirements\\n• Strong track record: Over 95% client satisfaction rate across more than 200 successful projects completed\\n\\nOur comprehensive service offering includes:\\n\\n• Digital transformation strategy and implementation\\n• Business process reengineering\\n• Technology advisory services\\n• Custom software development\\n• Change management and training\\n• Ongoing support and maintenance\\n\\nWe understand that each client's needs are unique, and we tailor our approach accordingly. Our proposed solution will be specifically designed to address your requirements while ensuring optimal return on investment. With our strong local presence and commitment to skills development in South Africa, we are well-positioned to be your long-term strategic partner.\\n\\nKhonology is committed to delivering exceptional value through innovative solutions that drive sustainable business growth. We look forward to the opportunity to collaborate with you on this important initiative.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":11,"last_modified":"2025-10-27T17:44:33.420"}}	Sent to Client	Acme Trading	umsibanda.1994@gmail.com	\N	\N	2025-10-27 16:47:31.091059	2025-10-27 22:28:39.714993
36	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"dghjkloiuuttdchkml","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-30T12:09:38.875"}}	Sent to Client	unathiInc	umsibanda.1994@gmail.com	\N	\N	2025-10-30 12:09:16.344558	2025-10-30 12:10:46.080044
33	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"i want to write a proposal about life, I dont know where to start","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-28T14:38:31.402"}}	Sent to Client	unathi	umsibanda.1994@gmail.com	\N	\N	2025-10-28 14:37:40.124084	2025-10-28 14:39:07.919892
34	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Content","content":" of technical expertise, industry knowledge, and social impact through our graduate development programs. Our solutions are designed to deliver measurable business value while contributing to the growth of South Africa's digital economy. The total investment required for this engagement is R2.5 million, with an expected ROI of 250% over three years. This proposal demonstrates our capability to execute complex technology projects while maintaining our commitment to skills development and transformation in the South African context.\\",\\n\\n  \\"Introduction & Background\\": \\"Established in 2013, Khonology has emerged as a transformative force in South Africa's technology landscape. Our company was founded on the principle that technology advancement must go hand-in-hand with skills development and economic transformation. We specialize in providing innovative solutions to the financial services sector while simultaneously addressing the critical skills shortage in the industry. Over the past decade, Khonology has successfully implemented over 200 projects for major financial institutions, trained more than 500 graduates, and contributed significantly to the transformation of South Africa's financial technology sector. Our unique approach combines technical excellence with a strong focus on developing local talent, particularly from previously disadvantaged communities. We have established partnerships with leading technology providers, financial institutions, and educational organizations to create a sustainable ecosystem for technology innovation and skills development in South Africa.\\",\\n\\n  \\"Understanding of Requirements\\": \\"Based on our extensive analysis and industry expertise, we recognize the critical challenges facing South African organizations in the digital age. These include:\\n\\n• Need for robust digital transformation strategies\\n• Integration of legacy systems with modern technology platforms\\n• Shortage of skilled technology professionals\\n• Regulatory compliance requirements\\n• Cybersecurity threats and data protection\\n• Cost optimization and operational efficiency\\n\\nOur understanding encompasses both the technical and human capital aspects of these challenges. We acknowledge the importance of delivering solutions that are not only technologically advanced but also sustainable within the South African context. This includes considerations for:\\n\\n• Local regulatory requirements and compliance frameworks\\n• Skills transfer and capacity building\\n• Cultural sensitivity and transformation goals\\n• Cost-effective implementation strategies\\n• Long-term sustainability and maintenance\\n\\nOur approach is designed to address these requirements comprehensively while ensuring alignment with broader organizational objectives and transformation goals.\\",\\n\\n  \\"Proposed Solution\\": \\"Khonology proposes a multi-faceted solution that combines cutting-edge technology implementation with comprehensive skills development programs. Our solution architecture consists of:\\n\\n1. Technology Implementation:\\n• Custom-developed digital platforms\\n• System integration services\\n• Cloud migration and optimization\\n• Cybersecurity enhancement\\n• Data analytics and business intelligence\\n\\n2. Skills Development Program:\\n• Graduate recruitment and training\\n• Technical skills development\\n• Soft skills and leadership development\\n• Mentorship programs\\n• Industry placement\\n\\n3. Transformation Initiative:\\n• Employment equity advancement\\n• Enterprise development support\\n• Supplier diversity program\\n• Community engagement\\n\\nThe solution is designed to be modular and scalable, allowing for phased implementation while maintaining focus on immediate priorities. Our approach ensures technology advancement while building sustainable internal capabilities.\\",\\n\\n  \\"Scope & Deliverables\\": \\"The project scope encompasses the following key deliverables:\\n\\nTechnology Deliverables:\\n• Digital platform implementation and integration\\n• System architecture design and documentation\\n• Security framework implementation\\n• Data migration and validation\\n• User acceptance testing and deployment\\n• Performance optimization and monitoring\\n\\nSkills Development Deliverables:\\n• Training curriculum development\\n• Graduate recruitment and selection\\n• Technical training modules\\n• Practical work experience programs\\n• Assessment and certification\\n• Placement support services\\n\\nTransformation Deliverables:\\n• Employment equity planning and implementation\\n• Skills transfer documentation\\n• Mentorship program structure\\n• Progress monitoring and reporting\\n• Impact assessment and evaluation\\n\\nEach deliverable includes detailed documentation, training materials, and support procedures to ensure sustainable implementation and knowledge transfer.\\",\\n\\n  \\"Delivery Approach & Methodology\\": \\"Khonology employs a hybrid delivery methodology that combines agile principles with traditional project management approaches, tailored to the South African context. Our methodology consists of:\\n\\n1. Project Initiation Phase:\\n• Stakeholder engagement and requirements validation\\n• Project charter development\\n• Resource allocation and team formation\\n• Risk assessment and mitigation planning\\n\\n2. Implementation Phase:\\n• Iterative development cycles\\n• Regular stakeholder reviews\\n• Continuous integration and testing\\n• Progress monitoring and reporting\\n\\n3. Skills Transfer Phase:\\n• Knowledge transfer sessions\\n• Mentorship program implementation\\n• Documentation and training\\n• Capability assessment\\n\\n4. Quality Assurance:\\n• Regular quality reviews\\n• Performance benchmarking\\n• Compliance verification\\n• Security audits\\n\\nOur approach emphasizes collaboration, transparency, and continuous improvement throughout the project lifecycle.\\",\\n\\n  \\"Timeline & Milestones\\": \\"The project will be executed over a 12-month period with the following key milestones:\\n\\nMonth 1-2:\\n• Project initiation and planning\\n• Requirements finalization\\n• Team mobilization\\n• Infrastructure setup\\n\\nMonth 3-4:\\n• Platform development initiation\\n• Graduate recruitment\\n• Training program launch\\n• First sprint completion\\n\\nMonth 5-8:\\n• Core system implementation\\n• Integration development\\n• Training delivery\\n• Progress assessments\\n\\nMonth 9-10:\\n• User acceptance testing\\n• System optimization\\n• Final deployment preparation\\n• Documentation completion\\n\\nMonth 11-12:\\n• Go-live implementation\\n• Post-implementation support\\n• Final assessments\\n• Project closure and handover\\",\\n\\n  \\"Team & Expertise\\": \\"Khonology will deploy a highly skilled team of professionals with extensive experience in technology implementation and skills development:\\n\\nProject Leadership:\\n• Project Director: 15+ years experience in digital transformation\\n• Technical Lead: 12+ years in system integration\\n• Training Manager: 10+ years in skills development\\n\\nTechnical Team:\\n• Senior Developers (4): Average 8 years experience\\n• Integration Specialists (2): 7+ years experience\\n• Security Expert: 10+ years experience\\n• Database Administrator: 8+ years experience\\n\\nTraining Team:\\n• Technical Trainers (3): Average 6 years experience\\n• Soft Skills Facilitators (2): 8+ years experience\\n• Mentorship Coordinators (2): 5+ years experience\\n\\nSupport Team:\\n• Project Coordinators (2)\\n• Quality Assurance Specialists (2)\\n• Documentation Specialists (1)\\",\\n\\n  \\"Budget & Pricing\\": \\"The total investment for this comprehensive solution is structured as follows:\\n\\nTechnology Implementation: R1,500,000\\n• Platform development: R600,000\\n• System integration: R400,000\\n• Security implementation: R300,000\\n• Infrastructure setup: R200,000\\n\\nSkills Development Program: R750,000\\n• Training curriculum development: R150,000\\n• Program delivery: R400,000\\n• Materials and resources: R100,000\\n• Assessment and certification: R100,000\\n\\nProject Management: R250,000\\n• Project coordination: R150,000\\n• Quality assurance: R50,000\\n• Documentation: R50,000\\n\\nTotal Project Investment: R2,500,000\\n\\nPayment Schedule:\\n• Initial payment (30%): R750,000\\n• Milestone payments (50%): R1,250,000\\n• Final payment (20%): R500,000\\",\\n\\n  \\"Assumptions & Dependencies\\": \\"This proposal is based on the following key assumptions and dependencies:\\n\\nKey Assumptions:\\n• Client will provide necessary access to systems and data\\n• Stakeholder availability for key decisions and reviews\\n• Stable technical environment during implementation\\n• Availability of suitable graduate candidates\\n• Commitment to transformation objectives\\n\\nDependencies:\\n• Timely provision of required infrastructure\\n• Access to subject matter experts\\n• Regulatory approval where required\\n• Stakeholder buy-in and support\\n• Resource availability as per schedule\\n\\nExternal Factors:\\n• Regulatory environment stability\\n• Market conditions\\n• Technology platform availability\\n• Skills market dynamics\\n\\nThe success of the project relies on these assumptions being met and dependencies being managed effectively.\\",\\n\\n  \\"Risks & Mitigation\\": \\"We have identified the following key risks and corresponding mitigation strategies:\\n\\nTechnical Risks:\\n• System compatibility issues\\n- Mitigation: Comprehensive assessment and testing\\n• Data security concerns\\n- Mitigation: Implementation of robust security frameworks\\n• Integration challenges\\n- Mitigation: Detailed integration planning and testing\\n\\nOperational Risks:\\n• Resource availability\\n- Mitigation: Backup resource pool and cross-training\\n• Timeline delays\\n- Mitigation: Buffer periods in project schedule\\n• Quality issues\\n- Mitigation: Regular quality reviews and checkpoints\\n\\nBusiness Risks:\\n• Budget overruns\\n- Mitigation: Detailed cost tracking and control measures\\n• Scope creep\\n- Mitigation: Strict change management procedures\\n• Stakeholder resistance\\n- Mitigation: Comprehensive change management program\\",\\n\\n  \\"Terms & Conditions\\": \\"This proposal is subject to the following terms and conditions:\\n\\nValidity:\\n• This proposal is valid for 60 days from submission\\n• Prices quoted are in South African Rand (ZAR)\\n• Terms are subject to final contract negotiation\\n\\nPayment Terms:\\n• 30% advance payment upon contract signing\\n• 50% based on achieved milestones\\n• 20% upon project completion\\n• Payment terms: 30 days from invoice\\n\\nIntellectual Property:\\n• All developed IP remains property of client\\n• Khonology retains rights to methodologies and tools\\n• Confidentiality agreements to be signed by all parties\\n\\nService Level Agreements:\\n• Response times for support queries\\n• System availability guarantees\\n• Performance metrics and standards\\n• Regular service review meetings\\n\\nThe final agreement will be subject to legal review and mutual acceptance of terms.\\"\\n}","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Executive Summary","content":"{\\n  \\"Executive Summary\\": \\"Khonology is a leading South African technology consulting and solutions provider specializing in digital transformation, financial technology, and skills development. This proposal outlines our comprehensive approach to delivering innovative technology solutions while addressing the critical skills gap in South Africa's financial services sector. With a proven track record of successful implemenotations and a commitment to transformation, Khonology offers a unique blend with the proposal i want to know ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-10-28T18:21:32.467"}}	Sent to Client	HackStart	hackathon.learner@gmail.com	\N	\N	2025-10-28 16:04:39.261247	2025-10-28 18:23:07.222987
35	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Winky wink ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-10-29T18:48:21.844"}}	Sent to Client	Unathi	umsibanda.1994@gmail.com	\N	\N	2025-10-29 18:47:55.696368	2025-10-29 18:50:06.907951
42	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"I want to","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"start a proposal","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-07T14:16:48.151"}}	Sent to Client	Unathi	learner.hackathon@gmail.com	\N	\N	2025-11-07 14:13:00.21885	2025-11-07 14:20:57.217556
40	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":"https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg","sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"My OpenRouter key doesn't have credits\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-09T20:50:29.835"}}	Sent to Client	Standard Bank	umsibanda.1994@gmail.com	\N	\N	2025-11-07 13:59:12.77302	2025-11-09 20:50:49.079358
44	zukhanye@gmail.com	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"creajs ckd dekmckdmsd cdsc","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-11T16:27:02.087"}}	Sent to Client	Braids	umsibanda.1994@gmail.com	\N	\N	2025-11-09 21:04:55.880636	2025-11-11 16:35:16.346711
66	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T16:43:01.018"}}	Sent to Client	SheziICT	sheziluthando513@gmail.com	\N	\N	2025-11-19 16:41:43.179348	2025-11-19 16:44:31.916796
64	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-19T15:08:19.610"}}	Sent to Client	Absa	sheziluthando513@gmail.com	\N	\N	2025-11-19 15:07:29.364071	2025-11-19 15:10:24.419371
65	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]},{"title":"Untitled Section","content":"Executive Summary\\n\\nOverview: Provide a high-level overview of the project, including its purpose and key goals.\\nObjectives: Clearly outline the main objectives of the project and what it aims to achieve.\\nImportance: Explain why this project is important to the organization or stakeholders involved.\\n\\nProject Overview\\nDescription:\\nBriefly describe the project.\\nOutline the objectives and goals.\\n\\nScope of Work\\nIncluded Tasks:\\nTask 1: [Description]\\nTask 2: [Description]\\nTask 3: [Description]\\n\\nExclusions:\\nOutline what is not included in the project scope.\\n\\nDeliverables\\n\\nDeliverable 1: [Description, due date]\\nDeliverable 2: [Description, due date]\\nDeliverable 3: [Description, due date]\\n\\nTimeline\\n\\n          \\n            \\n              PhaseStart DateEnd DateMilestones\\n              Phase 1[Date][Date][Milestone]Phase 2[Date][Date][Milestone]\\n            \\n          \\n        Roles and Responsibilities\\n\\n          \\n            \\n              RoleNameResponsibilities\\n              Project Manager[Name][Responsibilities]Team Member 1[Name][Responsibilities]Team Member 2[Name][Responsibilities]\\n            \\n          \\n        Budget\\n\\nTotal Cost: $[Amount]\\nCost Breakdown:\\nItem 1: $[Amount]\\nItem 2: $[Amount]\\n\\n\\n\\nRisks\\n\\nRisk 1: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 2: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\n\\nRisk 3: [Description of the risk]\\nImpact: [High/Medium/Low]\\nMitigation Strategy: [How to minimize or manage this risk]\\n\\n\\n\\nAcceptance Criteria\\n\\nDefine the criteria for project acceptance.\\nOutline how deliverables will be evaluated.\\n\\nChange Management\\n\\nDescribe the process for handling changes in scope, budget, or timeline.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-11-19T15:26:39.588"}}	Sent to Client	RMBS	umsibanda.1994@gmail.com	\N	\N	2025-11-19 15:25:48.493562	2025-11-19 15:28:12.331182
69	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["","","1","0.00","0.00"],["","","1","0.00","0.00"]],"vatRate":0.15}]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T09:59:39.843"}}	Sent to Client	BrandonInc	sheziluthando513@gmail.com	\N	\N	2025-11-25 15:09:27.610331	2025-11-26 10:00:27.434627
70	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"text","cells":[["Header 1","Header 2","Header 3"],["Row 1 Col 1","Row 1 Col 2","Row 1 Col 3"],["Row 2 Col 1","Row 2 Col 2","Row 2 Col 3"]],"vatRate":0.15},{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["","","1","0.00","0.00"],["","","1","0.00","0.00"]],"vatRate":0.15}]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T10:13:56.852"}}	Sent to Client	Brandon ICT	umsibanda.1994@gmail.com	\N	\N	2025-11-25 15:21:13.028048	2025-11-26 10:15:00.237362
79	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nCommercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-12-04T09:28:00.820"}}	Signed	Beauty ICtS	sibandanobunzima@gmail.com	\N	\N	2025-12-04 09:27:11.098699	2025-12-04 09:31:21.309409
67	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"yes yes\\n\\n\\n       \\n\\nGovernance Model Governance Structure Engagement Lead Product Owner (Client) Delivery Team QA & Compliance Group Tools Jira Teams/Email Automated reporting dashboard Cadence Daily standups Weekly status updates Monthly executive review\\n\\n\\n\\nScope of Work Khonology proposes the following Scope of Work: 1. Discovery & Assessment Requirements gathering Stakeholder workshops Current-state assessment 2. Solution Design Technical architecture Workflow design Data models and integration approach 3. Build & Configuration Product configuration UI/UX setup Data pipeline setup Reporting components 4. Implementation & Testing UAT support QA testing Release preparation 5. Training & Knowledge Transfer System training\\n\\n\\n\\n\\nPricing Table  Total Estimated Cost: R {{Total}} Final costs will be confirmed after detailed scoping.Documentation handoverAppendix – Company Profile About Khonology Khonology is a South African-based digital consulting and technology delivery company specialising in: Enterprise automation Digital transformation ESG reporting Data engineering & cloud Business analysis and enterprise delivery We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[{"type":"price","cells":[["Item","Description","Quantity","Unit Price","Total"],["321","ddsrd","1","0.00","0.00"],["","dvffds","1","0.00","0.00"]],"vatRate":0.15}]},{"title":"Untitled Section","content":"\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":24,"last_modified":"2025-11-25T12:12:39.192"}}	Sent to Client	SibandaICT	sheziluthando513@gmail.com	\N	\N	2025-11-19 17:00:53.012238	2025-11-25 12:13:51.026212
77	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Risk Assessment\\n\\nCritical Risks and Mitigation Strategies:\\n\\n1. Decision-Making Delays\\n• Risk: Extended approval cycles may impact project timelines\\n• Mitigation: Implement streamlined approval processes with 48-hour response targets\\n\\n2. Third-Party Dependencies\\n• Risk: Integration failures or vendor delays may create bottlenecks\\n• Mitigation: Establish vendor SLAs and maintain redundant supplier relationships\\n\\n3. Scope Management\\n• Risk: Unclear requirements may lead to costly rework\\n• Mitigation: Implement detailed scope documentation and weekly scope review sessions\\n\\n4. User Adoption\\n• Risk: Low user engagement may compromise ROI\\n• Mitigation: Develop comprehensive change management plan with regular training sessions","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":4,"last_modified":"2025-12-03T15:28:14.388"}}	Signed	Beauty ICT	sibandanobunzima@gmail.com	\N	\N	2025-12-03 15:25:13.150736	2025-12-03 21:37:59.072756
72	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"hi how are you","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-11-26T15:59:28.637"}}	Client Declined	UnathiLink	umsibanda.1994@gmail.com	\N	\N	2025-11-26 15:52:59.732798	2025-11-26 16:01:32.571108
71	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"AI, or Artificial Intelligence, is the creation of computer systems that can perform tasks requiring human intelligence, such as learning, problem-solving, and reasoning. Gemini is a specific type of AI developed by Google, which is a large language model that is multimodal, meaning it can process and understand different types of information like text, images, audio, and video. \\nWhat is AI?\\nIt's a field of computer science: AI is a branch of computer science focused on building smart machines that can perform tasks typically done by humans.\\nIt learns from data: Instead of being programmed with a million rules for every situation, AI systems learn patterns from vast amounts of data to make predictions or decisions.\\nIt powers many everyday applications: You encounter AI every day in things like personalized recommendations on shopping sites, spam filters in your email, and navigation apps like Google Maps. \\nWhat is Gemini?\\nIt's a large language model: Gemini is a family of powerful, multimodal AI models from Google.\\nIt's multimodal: It can understand and combine different types of information, including text, code, audio, images, and video.\\nIt's a conversational AI: Gemini can be used as a chatbot to help you brainstorm, write, research, and more, by understanding natural language.\\nIt's being integrated into Google products: Gemini is the AI assistant in some Google Pixel phones and is also integrated into Google Workspace, where it can help with writing and summarizing documents in Docs or drafting emails in Gmail. ","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T10:34:05.965"}}	Sent to Client	ITWeb	sheziluthando513@gmail.com	\N	\N	2025-11-26 10:33:16.823109	2025-11-26 10:35:13.293071
73	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"AI refers to artificial intelligence, a broad field of computer science focused on building machines capable of performing tasks that typically require human intelligence, such as understanding natural language, recognizing images, and making decisions. \\nAI on Google Search is powered by the Gemini family of models. \\nUnderstanding AI\\nArtificial Narrow Intelligence (ANI): This is the only form of AI that exists now. ANI systems are made to do one specific task very well, such as filtering emails, recognizing faces, or having a chatbot conversation.\\nHow it works: AI uses large amounts of data with advanced algorithms, like large language models (LLMs). This helps AI learn patterns, make predictions, and create content within set rules. AI does not have consciousness or self-awareness.\\nGenerative AI: This type of AI, which includes Gemini, can create new content like text, images, code, and video, based on what a user asks for. \\nWhat is Google Gemini? \\nGemini is the name for the large language models (LLMs) created by Google DeepMind. Key aspects of Gemini include: \\nMultimodality: Gemini can process and combine different types of information, including text, images, audio, video, and code.\\nAssistant: The Gemini app and web interface function as an AI assistant, helping with tasks like writing emails, brainstorming, summarizing information, and controlling smart home devices.\\nIntegration: The technology is used in several Google products, such as Google Search, Chrome, Gmail, Docs, and Android phones, to provide helpful features.\\nModels: Google offers different versions of the model, such as Gemini 2.5 Flash (for speed) and 3 Pro (for complex tasks and advanced reasoning). These are available on the Gemini website or through various subscription plans and developer APIs. \\nIn short, AI is the technology that simulates intelligent behavior, and Gemini is Google's specific implementation of that technology designed to be a helpful assistant. \\n\\n\\n\\n","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":2,"last_modified":"2025-11-26T16:53:40.599"}}	Sent for Signature	Sibanda.ICT	umsibanda.1994@gmail.com	\N	\N	2025-11-26 16:53:09.171141	2025-11-26 16:59:44.810436
76	nkosinathikhono	Breeed	{"title":"Breeed","sections":[{"title":"Untitled Section","content":"Project Assumptions\\n\\nThe successful delivery of this project is based on the following key assumptions:\\n\\n• Client stakeholders and resources will be available as per agreed project schedules\\n• Project milestone completion is contingent upon receiving timely client feedback and approvals\\n• Management of external vendor relationships and deliverables remains the client's responsibility\\n• Any changes to the agreed scope may impact project timelines and commercial estimates\\n• Standard business hours (8:00-17:00 SAST) will be observed for project activities\\n• Project communications will be conducted through approved channels\\n• Client will provide necessary access to systems and documentation within agreed timeframes\\n\\nNote: These assumptions form the basis of our project planning and pricing structure. Any deviations may require reassessment of timelines and costs. Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"Commercial Terms Rates exclude VAT unless otherwise stated. Travel is charged at cost if required. Invoices are payable within 30 days. Changes to scope may result in revised costing.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":18,"last_modified":"2025-12-01T14:27:34.547"}}	Sent for Signature	UMS Inc	umsibanda.1994@gmail.com	\N	\N	2025-11-26 21:07:15.669463	2025-12-01 14:29:39.961316
75	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":3,"last_modified":"2025-12-03T11:52:21.073"}}	Signed	Beauty FoodCourt	sibandanobunzima@gmail.com	\N	\N	2025-11-26 18:43:19.087737	2025-12-03 15:27:30.820985
78	nkosinathikhono	Untitled Document	{"title":"Untitled Document","sections":[{"title":"Untitled Section","content":"Project Risks Delays in decision-making may impact timelines. Third-party dependency failures can cause bottlenecks. Scope ambiguity increases rework risk. Insufficient user adoption may affect long-term value.\\n\\nProject Assumptions Client resources will be available as needed. All milestones are dependent on timely client feedback. Dependencies on external vendors are managed by the client. Scope changes may impact timelines and commercial estimates.\\n\\nGo-Live & Support Khonology ensures a smooth production rollout supported by hypercare and operational enablement. Includes Release management Post-deployment support Knowledge transfer Operational handover","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]},{"title":"Untitled Section (Copy)","content":"","backgroundColor":4294967295,"backgroundImageUrl":null,"sectionType":"content","isCoverPage":false,"inlineImages":[],"tables":[]}],"metadata":{"currency":"Rand (ZAR)","version":5,"last_modified":"2025-12-03T21:10:56.360"}}	Signed	Unathi ICT	umsibanda.1994@gmail.com	\N	\N	2025-12-03 21:09:52.189296	2025-12-03 21:13:30.456736
\.


--
-- Data for Name: section_locks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.section_locks (id, proposal_id, section_id, locked_by, locked_at, expires_at) FROM stdin;
\.


--
-- Data for Name: settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.settings (id, key, value, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sows (id, user_id, title, content, status, client_name, client_email, project_scope, deliverables, timeline, budget, payment_terms, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: suggested_changes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suggested_changes (id, proposal_id, section_id, suggested_by, suggestion_text, original_text, status, created_at, resolved_at, resolved_by, resolution_action) FROM stdin;
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_settings (id, company_name, company_email, company_phone, company_address, company_website, default_proposal_template, auto_save_interval, email_notifications, approval_workflow, signature_required, pdf_watermark, client_portal_enabled, created_at, updated_at) FROM stdin;
1	Your Company	contact@yourcompany.com	\N	\N	\N	proposal_standard	30	t	sequential	t	f	t	2025-10-08 23:30:44.680422	2025-10-08 23:30:44.680422
\.


--
-- Data for Name: team_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team_members (id, team_id, user_id, role, joined_at) FROM stdin;
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teams (id, name, description, created_by, created_at, updated_at, settings, is_active) FROM stdin;
\.


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates (id, key, dtype, name, sections, created_at, updated_at) FROM stdin;
1	proposal_standard	Proposal	Standard Proposal	{"Executive Summary","Scope & Deliverables","Delivery Approach",Assumptions,Risks,References,"Team Bios"}	2025-09-22 12:40:48.855406	2025-09-22 12:40:48.855406
2	sow_standard	SOW	Standard SOW	{"Scope & Deliverables","Acceptance Criteria","Timeline & Milestones",Assumptions,Risks,"Team Bios",Terms}	2025-09-22 12:40:48.855406	2025-09-22 12:40:48.855406
3	rfi_standard	RFI	Standard RFI	{"Company Profile",Questions,References}	2025-09-22 12:40:48.855406	2025-09-22 12:40:48.855406
\.


--
-- Data for Name: user_email_verification_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_email_verification_tokens (id, user_id, token, email, expires_at, used_at, created_at) FROM stdin;
1	65	4IaswmM0eYeuBjjzoy3_f-esH_D0qaCfr7D3bFh1FDE	hackathon.learner@gmail.com	2025-11-14 17:54:27.223868	2025-11-13 17:56:48.727093	2025-11-13 17:54:27.362422
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_preferences (user_id, theme, language, timezone, dashboard_layout, notifications_enabled, email_digest, auto_logout, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, email, password_hash, full_name, role, department, is_active, created_at, updated_at, is_email_verified) FROM stdin;
16	sheziluthando513	sheziluthando513@gmail.com	pbkdf2:sha256:600000$LSLxqt7FMwmDRCla$7cadc40bc6ce295bcaf35daa39c962a8f694fb98bc4f1c03c6948d328c480b70	Sipho Nkosi	admin	\N	t	2025-10-22 12:58:15.314616	2025-10-22 12:58:15.314616	t
22	zukhanye@gmail.com	zukhanye@gmail.com	pbkdf2:sha256:600000$NiiGIBjjGCSvvwt1$9ec5a160ec1facfe6501c906743842bbb1944ac619e04398a2221f142d6e862a	Zukhanye Baloyi	admin	\N	t	2025-10-22 23:55:49.171262	2025-10-22 23:55:49.171262	t
65	hackathon.learner@gmail.com	hackathon.learner@gmail.com	pbkdf2:sha256:600000$bO006Npyt6Rh6mEK$8d89b0a25c3cdfb03436428c01d3f850237bbc78588d07bf86409896b7abedf1	Luthando Hackathon	manager	\N	t	2025-11-13 17:54:27.207123	2025-11-13 17:56:48.727093	t
15	nkosinathikhono	nkosinathikhono@gmail.com	pbkdf2:sha256:600000$TfsK7MwPCGWPyMlP$4802eb5797eb58afc9e3286dd06fec55901e92af443cf39c3995dee81aa4f7aa	Nkosinathi Khono	manager	\N	t	2025-10-22 12:03:32.58696	2025-10-22 12:03:32.58696	t
17	tester	tester@gmail.com	pbkdf2:sha256:600000$hUVMuVxvjhFWcwXy$0a1dc4906dba21ff5dbeba796f9593323d84c08d098e6064bc863b18526b6aaf	Test Tester	manager	\N	t	2025-10-22 13:08:32.542971	2025-10-22 13:08:32.542971	t
18	nathi.msuthwana	nathi.msuthwana@gmail.com	pbkdf2:sha256:600000$GgIkCWTPmrkCQpW2$9d4789f186be11670a1c49e46fd637f39caafcc946bb554debfa7f185af5b386	Nathi Msuthwana	manager	\N	t	2025-10-22 13:14:12.964635	2025-10-22 13:14:12.964635	t
19	unathi.msuthwana@gmail.com	unathi.msuthwana@gmail.com	pbkdf2:sha256:600000$VLXpG5JJCNfR6Dsx$dc33891cf5ee4c0750f963a84ae7cf035fd5ceec7b7562b6273e3b62e96d758b	Unathi Msuthwana	manager	\N	t	2025-10-22 13:24:31.566754	2025-10-22 13:24:31.566754	t
21	tester.19@gmail.com	tester.19@gmail.com	pbkdf2:sha256:600000$V22ESXqLLgsHuTA0$1950c5f40c0e1c8fa6e41f753fdb40657ab11ae23162285b41a227a48e717f73	Tester Test	manager	\N	t	2025-10-22 14:14:12.523936	2025-10-22 14:14:12.523936	t
13	umsibanda.1994	umsibanda.1994@gmail.com	pbkdf2:sha256:600000$hfSqxUujqpMyKWPP$8d73547ad18dd81327f01c3e6fafe1c3ff686db29fbbabb8e45f1148ec274788	Unathi Sibanda	manager	\N	t	2025-10-22 11:53:40.28413	2025-10-22 11:53:40.28413	t
\.


--
-- Data for Name: verification_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_tokens (id, user_id, token, expires_at, created_at) FROM stdin;
\.


--
-- Data for Name: verify_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verify_tokens (id, email, token, created_at, expires_at) FROM stdin;
1	umsibanda.1994@gmail.com	FXfSuAEb4mcHLGoUECxSInviK0DYiQsaOy81oc947ss	2025-10-22 10:00:15.739988	2025-10-23 10:00:15.737949
\.


--
-- Data for Name: workspace_documents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.workspace_documents (id, workspace_id, document_id, document_type, added_by, added_at) FROM stdin;
\.


--
-- Data for Name: workspace_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.workspace_members (id, workspace_id, user_id, permission, joined_at) FROM stdin;
\.


--
-- Data for Name: workspaces; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.workspaces (id, name, description, team_id, created_by, created_at, updated_at, settings, is_active) FROM stdin;
\.


--
-- Name: activity_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.activity_log_id_seq', 44, true);


--
-- Name: approvals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.approvals_id_seq', 1, false);


--
-- Name: client_dashboard_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.client_dashboard_tokens_id_seq', 1, false);


--
-- Name: client_notes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.client_notes_id_seq', 1, false);


--
-- Name: client_onboarding_invitations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.client_onboarding_invitations_id_seq', 4, true);


--
-- Name: client_proposals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.client_proposals_id_seq', 1, false);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_id_seq', 4, true);


--
-- Name: collaboration_invitations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.collaboration_invitations_id_seq', 80, true);


--
-- Name: collaborators_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.collaborators_id_seq', 5, true);


--
-- Name: comment_mentions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.comment_mentions_id_seq', 17, true);


--
-- Name: content_blocks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.content_blocks_id_seq', 45, true);


--
-- Name: content_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.content_id_seq', 167, true);


--
-- Name: content_library_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.content_library_id_seq', 1, false);


--
-- Name: document_comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.document_comments_id_seq', 57, true);


--
-- Name: email_verification_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.email_verification_events_id_seq', 1, true);


--
-- Name: proposal_client_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposal_client_activity_id_seq', 62, true);


--
-- Name: proposal_client_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposal_client_session_id_seq', 39, true);


--
-- Name: proposal_feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposal_feedback_id_seq', 1, false);


--
-- Name: proposal_signatures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposal_signatures_id_seq', 18, true);


--
-- Name: proposal_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposal_versions_id_seq', 211, true);


--
-- Name: proposals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proposals_id_seq', 79, true);


--
-- Name: section_locks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.section_locks_id_seq', 1, false);


--
-- Name: settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.settings_id_seq', 1, false);


--
-- Name: sows_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sows_id_seq', 1, false);


--
-- Name: suggested_changes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.suggested_changes_id_seq', 1, false);


--
-- Name: templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_id_seq', 3, true);


--
-- Name: user_email_verification_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_email_verification_tokens_id_seq', 1, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 68, true);


--
-- Name: verification_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verification_tokens_id_seq', 1, false);


--
-- Name: verify_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.verify_tokens_id_seq', 1, true);


--
-- Name: activity_log activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);


--
-- Name: ai_settings ai_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_settings
    ADD CONSTRAINT ai_settings_pkey PRIMARY KEY (id);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: client_dashboard_tokens client_dashboard_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_dashboard_tokens
    ADD CONSTRAINT client_dashboard_tokens_pkey PRIMARY KEY (id);


--
-- Name: client_dashboard_tokens client_dashboard_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_dashboard_tokens
    ADD CONSTRAINT client_dashboard_tokens_token_key UNIQUE (token);


--
-- Name: client_notes client_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_notes
    ADD CONSTRAINT client_notes_pkey PRIMARY KEY (id);


--
-- Name: client_onboarding_invitations client_onboarding_invitations_access_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_onboarding_invitations
    ADD CONSTRAINT client_onboarding_invitations_access_token_key UNIQUE (access_token);


--
-- Name: client_onboarding_invitations client_onboarding_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_onboarding_invitations
    ADD CONSTRAINT client_onboarding_invitations_pkey PRIMARY KEY (id);


--
-- Name: client_proposals client_proposals_client_id_proposal_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals
    ADD CONSTRAINT client_proposals_client_id_proposal_id_key UNIQUE (client_id, proposal_id);


--
-- Name: client_proposals client_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals
    ADD CONSTRAINT client_proposals_pkey PRIMARY KEY (id);


--
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: clients clients_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_token_key UNIQUE (token);


--
-- Name: collaboration_invitations collaboration_invitations_access_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaboration_invitations
    ADD CONSTRAINT collaboration_invitations_access_token_key UNIQUE (access_token);


--
-- Name: collaboration_invitations collaboration_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaboration_invitations
    ADD CONSTRAINT collaboration_invitations_pkey PRIMARY KEY (id);


--
-- Name: collaborators collaborators_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_pkey PRIMARY KEY (id);


--
-- Name: collaborators collaborators_proposal_id_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_proposal_id_email_key UNIQUE (proposal_id, email);


--
-- Name: comment_mentions comment_mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comment_mentions
    ADD CONSTRAINT comment_mentions_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: content_blocks content_blocks_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_blocks
    ADD CONSTRAINT content_blocks_key_key UNIQUE (key);


--
-- Name: content_blocks content_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_blocks
    ADD CONSTRAINT content_blocks_pkey PRIMARY KEY (id);


--
-- Name: content content_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content
    ADD CONSTRAINT content_key_key UNIQUE (key);


--
-- Name: content_library content_library_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_library
    ADD CONSTRAINT content_library_pkey PRIMARY KEY (id);


--
-- Name: content_modules content_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_modules
    ADD CONSTRAINT content_modules_pkey PRIMARY KEY (id);


--
-- Name: content content_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content
    ADD CONSTRAINT content_pkey PRIMARY KEY (id);


--
-- Name: database_settings database_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.database_settings
    ADD CONSTRAINT database_settings_pkey PRIMARY KEY (id);


--
-- Name: document_comments document_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments
    ADD CONSTRAINT document_comments_pkey PRIMARY KEY (id);


--
-- Name: email_settings email_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_settings
    ADD CONSTRAINT email_settings_pkey PRIMARY KEY (id);


--
-- Name: email_verification_events email_verification_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_verification_events
    ADD CONSTRAINT email_verification_events_pkey PRIMARY KEY (id);


--
-- Name: module_versions module_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.module_versions
    ADD CONSTRAINT module_versions_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: proposal_client_activity proposal_client_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_activity
    ADD CONSTRAINT proposal_client_activity_pkey PRIMARY KEY (id);


--
-- Name: proposal_client_session proposal_client_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_session
    ADD CONSTRAINT proposal_client_session_pkey PRIMARY KEY (id);


--
-- Name: proposal_feedback proposal_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_feedback
    ADD CONSTRAINT proposal_feedback_pkey PRIMARY KEY (id);


--
-- Name: proposal_signatures proposal_signatures_envelope_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_signatures
    ADD CONSTRAINT proposal_signatures_envelope_id_key UNIQUE (envelope_id);


--
-- Name: proposal_signatures proposal_signatures_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_signatures
    ADD CONSTRAINT proposal_signatures_pkey PRIMARY KEY (id);


--
-- Name: proposal_system_feedback proposal_system_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_system_feedback
    ADD CONSTRAINT proposal_system_feedback_pkey PRIMARY KEY (id);


--
-- Name: proposal_system_proposals proposal_system_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_system_proposals
    ADD CONSTRAINT proposal_system_proposals_pkey PRIMARY KEY (id);


--
-- Name: proposal_users proposal_users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_users
    ADD CONSTRAINT proposal_users_email_key UNIQUE (email);


--
-- Name: proposal_users proposal_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_users
    ADD CONSTRAINT proposal_users_pkey PRIMARY KEY (id);


--
-- Name: proposal_versions proposal_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_versions
    ADD CONSTRAINT proposal_versions_pkey PRIMARY KEY (id);


--
-- Name: proposals proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_pkey PRIMARY KEY (id);


--
-- Name: section_locks section_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.section_locks
    ADD CONSTRAINT section_locks_pkey PRIMARY KEY (id);


--
-- Name: section_locks section_locks_proposal_id_section_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.section_locks
    ADD CONSTRAINT section_locks_proposal_id_section_id_key UNIQUE (proposal_id, section_id);


--
-- Name: settings settings_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_key_key UNIQUE (key);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: sows sows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sows
    ADD CONSTRAINT sows_pkey PRIMARY KEY (id);


--
-- Name: suggested_changes suggested_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_changes
    ADD CONSTRAINT suggested_changes_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_team_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_user_id_key UNIQUE (team_id, user_id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: templates templates_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_key_key UNIQUE (key);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: user_email_verification_tokens user_email_verification_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_email_verification_tokens
    ADD CONSTRAINT user_email_verification_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_email_verification_tokens user_email_verification_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_email_verification_tokens
    ADD CONSTRAINT user_email_verification_tokens_token_key UNIQUE (token);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: verification_tokens verification_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verification_tokens_pkey PRIMARY KEY (id);


--
-- Name: verification_tokens verification_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_tokens
    ADD CONSTRAINT verification_tokens_token_key UNIQUE (token);


--
-- Name: verify_tokens verify_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verify_tokens
    ADD CONSTRAINT verify_tokens_pkey PRIMARY KEY (id);


--
-- Name: verify_tokens verify_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verify_tokens
    ADD CONSTRAINT verify_tokens_token_key UNIQUE (token);


--
-- Name: workspace_documents workspace_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspace_documents
    ADD CONSTRAINT workspace_documents_pkey PRIMARY KEY (id);


--
-- Name: workspace_members workspace_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspace_members
    ADD CONSTRAINT workspace_members_pkey PRIMARY KEY (id);


--
-- Name: workspace_members workspace_members_workspace_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspace_members
    ADD CONSTRAINT workspace_members_workspace_id_user_id_key UNIQUE (workspace_id, user_id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: idx_activity_client_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_activity_client_id ON public.proposal_client_activity USING btree (client_id);


--
-- Name: idx_activity_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_activity_created_at ON public.proposal_client_activity USING btree (created_at);


--
-- Name: idx_activity_event_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_activity_event_type ON public.proposal_client_activity USING btree (event_type);


--
-- Name: idx_activity_log_proposal; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_activity_log_proposal ON public.activity_log USING btree (proposal_id, created_at DESC);


--
-- Name: idx_activity_proposal_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_activity_proposal_id ON public.proposal_client_activity USING btree (proposal_id);


--
-- Name: idx_approvals_proposal_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_approvals_proposal_id ON public.approvals USING btree (proposal_id);


--
-- Name: idx_approvals_sow_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_approvals_sow_id ON public.approvals USING btree (sow_id);


--
-- Name: idx_comment_mentions_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comment_mentions_user ON public.comment_mentions USING btree (mentioned_user_id, is_read, created_at DESC);


--
-- Name: idx_comments_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_author ON public.comments USING btree (author_id);


--
-- Name: idx_comments_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_created_at ON public.comments USING btree (created_at);


--
-- Name: idx_comments_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_parent ON public.comments USING btree (parent_id);


--
-- Name: idx_comments_resource; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_comments_resource ON public.comments USING btree (resource_type, resource_id);


--
-- Name: idx_content_library_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_content_library_user_id ON public.content_library USING btree (user_id);


--
-- Name: idx_content_modules_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_content_modules_category ON public.content_modules USING btree (category);


--
-- Name: idx_content_modules_title; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_content_modules_title ON public.content_modules USING btree (title);


--
-- Name: idx_document_comments_block; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_comments_block ON public.document_comments USING btree (proposal_id, block_type, block_id) WHERE (block_id IS NOT NULL);


--
-- Name: idx_document_comments_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_comments_parent ON public.document_comments USING btree (parent_id) WHERE (parent_id IS NOT NULL);


--
-- Name: idx_document_comments_proposal; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_comments_proposal ON public.document_comments USING btree (proposal_id);


--
-- Name: idx_document_comments_section; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_comments_section ON public.document_comments USING btree (proposal_id, section_index) WHERE (section_index IS NOT NULL);


--
-- Name: idx_document_comments_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_document_comments_status ON public.document_comments USING btree (status) WHERE ((status)::text = 'open'::text);


--
-- Name: idx_module_versions_module_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_module_versions_module_id ON public.module_versions USING btree (module_id);


--
-- Name: idx_notifications_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at);


--
-- Name: idx_notifications_is_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_is_read ON public.notifications USING btree (is_read);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id, is_read, created_at DESC);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: idx_proposal_signatures; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_signatures ON public.proposal_signatures USING btree (proposal_id, status, sent_at DESC);


--
-- Name: idx_proposal_system_proposals_client; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_system_proposals_client ON public.proposal_system_proposals USING btree (client_name);


--
-- Name: idx_proposal_system_proposals_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_system_proposals_created_at ON public.proposal_system_proposals USING btree (created_at DESC);


--
-- Name: idx_proposal_system_proposals_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_system_proposals_created_by ON public.proposal_system_proposals USING btree (created_by);


--
-- Name: idx_proposal_system_proposals_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_system_proposals_status ON public.proposal_system_proposals USING btree (status);


--
-- Name: idx_proposal_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_users_email ON public.proposal_users USING btree (email);


--
-- Name: idx_proposal_users_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposal_users_role ON public.proposal_users USING btree (role);


--
-- Name: idx_proposals_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposals_status ON public.proposals USING btree (status);


--
-- Name: idx_proposals_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_proposals_user_id ON public.proposals USING btree (user_id);


--
-- Name: idx_session_client_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session_client_id ON public.proposal_client_session USING btree (client_id);


--
-- Name: idx_session_proposal_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session_proposal_id ON public.proposal_client_session USING btree (proposal_id);


--
-- Name: idx_session_start; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session_start ON public.proposal_client_session USING btree (session_start);


--
-- Name: idx_sows_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sows_status ON public.sows USING btree (status);


--
-- Name: idx_sows_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sows_user_id ON public.sows USING btree (user_id);


--
-- Name: idx_team_members_team_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_team_members_team_id ON public.team_members USING btree (team_id);


--
-- Name: idx_team_members_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_team_members_user_id ON public.team_members USING btree (user_id);


--
-- Name: idx_teams_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teams_created_by ON public.teams USING btree (created_by);


--
-- Name: idx_teams_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teams_is_active ON public.teams USING btree (is_active);


--
-- Name: idx_templates_dtype; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_templates_dtype ON public.templates USING btree (dtype);


--
-- Name: idx_templates_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_templates_name ON public.templates USING btree (name);


--
-- Name: idx_verification_tokens_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_verification_tokens_token ON public.verification_tokens USING btree (token);


--
-- Name: idx_verification_tokens_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_verification_tokens_user_id ON public.verification_tokens USING btree (user_id);


--
-- Name: idx_workspace_documents_workspace_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_workspace_documents_workspace_id ON public.workspace_documents USING btree (workspace_id);


--
-- Name: idx_workspace_members_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_workspace_members_user_id ON public.workspace_members USING btree (user_id);


--
-- Name: idx_workspace_members_workspace_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_workspace_members_workspace_id ON public.workspace_members USING btree (workspace_id);


--
-- Name: idx_workspaces_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_workspaces_created_by ON public.workspaces USING btree (created_by);


--
-- Name: idx_workspaces_team_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_workspaces_team_id ON public.workspaces USING btree (team_id);


--
-- Name: templates templates_set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER templates_set_updated_at BEFORE UPDATE ON public.templates FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: approvals update_approvals_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_approvals_updated_at BEFORE UPDATE ON public.approvals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: comments update_comments_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: content_library update_content_library_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_content_library_updated_at BEFORE UPDATE ON public.content_library FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: content_modules update_content_modules_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_content_modules_timestamp BEFORE UPDATE ON public.content_modules FOR EACH ROW EXECUTE FUNCTION public.update_content_modules_updated_at();


--
-- Name: proposal_system_proposals update_proposal_system_proposals_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_proposal_system_proposals_updated_at BEFORE UPDATE ON public.proposal_system_proposals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: proposal_users update_proposal_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_proposal_users_updated_at BEFORE UPDATE ON public.proposal_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: proposals update_proposals_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_proposals_updated_at BEFORE UPDATE ON public.proposals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: sows update_sows_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_sows_updated_at BEFORE UPDATE ON public.sows FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: teams update_teams_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: workspaces update_workspaces_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_workspaces_updated_at BEFORE UPDATE ON public.workspaces FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: activity_log activity_log_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: activity_log activity_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: approvals approvals_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: approvals approvals_sow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_sow_id_fkey FOREIGN KEY (sow_id) REFERENCES public.sows(id) ON DELETE CASCADE;


--
-- Name: client_dashboard_tokens client_dashboard_tokens_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_dashboard_tokens
    ADD CONSTRAINT client_dashboard_tokens_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_dashboard_tokens client_dashboard_tokens_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_dashboard_tokens
    ADD CONSTRAINT client_dashboard_tokens_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: client_notes client_notes_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_notes
    ADD CONSTRAINT client_notes_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_notes client_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_notes
    ADD CONSTRAINT client_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: client_onboarding_invitations client_onboarding_invitations_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_onboarding_invitations
    ADD CONSTRAINT client_onboarding_invitations_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: client_onboarding_invitations client_onboarding_invitations_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_onboarding_invitations
    ADD CONSTRAINT client_onboarding_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.users(id);


--
-- Name: client_proposals client_proposals_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals
    ADD CONSTRAINT client_proposals_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: client_proposals client_proposals_linked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals
    ADD CONSTRAINT client_proposals_linked_by_fkey FOREIGN KEY (linked_by) REFERENCES public.users(id);


--
-- Name: client_proposals client_proposals_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.client_proposals
    ADD CONSTRAINT client_proposals_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: collaboration_invitations collaboration_invitations_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaboration_invitations
    ADD CONSTRAINT collaboration_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.users(id);


--
-- Name: collaboration_invitations collaboration_invitations_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaboration_invitations
    ADD CONSTRAINT collaboration_invitations_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: collaborators collaborators_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.users(id);


--
-- Name: collaborators collaborators_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: collaborators collaborators_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: comment_mentions comment_mentions_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comment_mentions
    ADD CONSTRAINT comment_mentions_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.document_comments(id) ON DELETE CASCADE;


--
-- Name: comment_mentions comment_mentions_mentioned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comment_mentions
    ADD CONSTRAINT comment_mentions_mentioned_by_user_id_fkey FOREIGN KEY (mentioned_by_user_id) REFERENCES public.users(id);


--
-- Name: comment_mentions comment_mentions_mentioned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comment_mentions
    ADD CONSTRAINT comment_mentions_mentioned_user_id_fkey FOREIGN KEY (mentioned_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: comments comments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id) ON DELETE CASCADE;


--
-- Name: content_blocks content_blocks_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content_blocks
    ADD CONSTRAINT content_blocks_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.content_blocks(id) ON DELETE CASCADE;


--
-- Name: content content_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.content
    ADD CONSTRAINT content_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.content(id);


--
-- Name: document_comments document_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments
    ADD CONSTRAINT document_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: document_comments document_comments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments
    ADD CONSTRAINT document_comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.document_comments(id) ON DELETE CASCADE;


--
-- Name: document_comments document_comments_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments
    ADD CONSTRAINT document_comments_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: document_comments document_comments_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.document_comments
    ADD CONSTRAINT document_comments_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id);


--
-- Name: email_verification_events email_verification_events_invitation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.email_verification_events
    ADD CONSTRAINT email_verification_events_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.client_onboarding_invitations(id) ON DELETE CASCADE;


--
-- Name: module_versions module_versions_module_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.module_versions
    ADD CONSTRAINT module_versions_module_id_fkey FOREIGN KEY (module_id) REFERENCES public.content_modules(id) ON DELETE CASCADE;


--
-- Name: proposal_client_activity proposal_client_activity_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_activity
    ADD CONSTRAINT proposal_client_activity_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: proposal_client_activity proposal_client_activity_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_activity
    ADD CONSTRAINT proposal_client_activity_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: proposal_client_session proposal_client_session_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_session
    ADD CONSTRAINT proposal_client_session_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL;


--
-- Name: proposal_client_session proposal_client_session_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_client_session
    ADD CONSTRAINT proposal_client_session_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: proposal_feedback proposal_feedback_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_feedback
    ADD CONSTRAINT proposal_feedback_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: proposal_feedback proposal_feedback_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_feedback
    ADD CONSTRAINT proposal_feedback_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: proposal_signatures proposal_signatures_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_signatures
    ADD CONSTRAINT proposal_signatures_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: proposal_signatures proposal_signatures_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_signatures
    ADD CONSTRAINT proposal_signatures_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: proposal_system_proposals proposal_system_proposals_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_system_proposals
    ADD CONSTRAINT proposal_system_proposals_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.proposal_users(id);


--
-- Name: proposal_versions proposal_versions_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proposal_versions
    ADD CONSTRAINT proposal_versions_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: section_locks section_locks_locked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.section_locks
    ADD CONSTRAINT section_locks_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES public.users(id);


--
-- Name: section_locks section_locks_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.section_locks
    ADD CONSTRAINT section_locks_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: suggested_changes suggested_changes_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_changes
    ADD CONSTRAINT suggested_changes_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.proposals(id) ON DELETE CASCADE;


--
-- Name: suggested_changes suggested_changes_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_changes
    ADD CONSTRAINT suggested_changes_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id);


--
-- Name: suggested_changes suggested_changes_suggested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suggested_changes
    ADD CONSTRAINT suggested_changes_suggested_by_fkey FOREIGN KEY (suggested_by) REFERENCES public.users(id);


--
-- Name: team_members team_members_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: user_email_verification_tokens user_email_verification_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_email_verification_tokens
    ADD CONSTRAINT user_email_verification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: workspace_documents workspace_documents_workspace_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspace_documents
    ADD CONSTRAINT workspace_documents_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;


--
-- Name: workspace_members workspace_members_workspace_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspace_members
    ADD CONSTRAINT workspace_members_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;


--
-- Name: workspaces workspaces_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

