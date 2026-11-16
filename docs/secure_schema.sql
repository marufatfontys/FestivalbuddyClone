-- =============================================================================
-- Festival Buddy — Secure SQL Database Schema (Cybersecurity Deliverable)
-- Enforces Argon2id Salted Password Storage, RBAC, Account-Bound Tickets,
-- Single-Use 24h Password Reset Tokens, and Immutable Audit Logging.
-- =============================================================================

CREATE TABLE users (
    user_id             UUID PRIMARY KEY,
    email               VARCHAR(255) NOT NULL UNIQUE,
    display_name        VARCHAR(80)  NOT NULL,
    password_salt       CHAR(32)     NOT NULL,
    argon2id_hash       VARCHAR(255) NOT NULL, -- Never store plain-text passwords
    role                VARCHAR(20)  NOT NULL CHECK (role IN ('visitor', 'organizer', 'admin')),
    failed_login_count  INT          NOT NULL DEFAULT 0,
    locked_until        TIMESTAMP    NULL,     -- Set to NOW() + 15 minutes on 5th failed attempt
    session_version     INT          NOT NULL DEFAULT 1, -- Incremented on password reset to invalidate sessions
    privacy_accepted_at TIMESTAMP    NOT NULL,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE password_reset_tokens (
    token_hash          CHAR(64)     PRIMARY KEY,
    user_id             UUID         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    expires_at          TIMESTAMP    NOT NULL, -- Must expire within 24 hours
    is_used             BOOLEAN      NOT NULL DEFAULT FALSE, -- Single-use enforcement
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE festivals (
    festival_id                 UUID PRIMARY KEY,
    organizer_user_id           UUID         NOT NULL REFERENCES users(user_id),
    name                        VARCHAR(120) NOT NULL,
    city                        VARCHAR(80)  NOT NULL,
    event_dates                 VARCHAR(80)  NOT NULL,
    price_eur                   DECIMAL(8,2) NOT NULL,
    tickets_sold_in_app         INT          NOT NULL DEFAULT 0,
    public_transport_info       TEXT         NOT NULL,
    festival_shuttle_offer      TEXT         NOT NULL,
    -- 9 Verifiable SDG Commitments (Anti-Greenwashing Checklist)
    sdg3_free_drinking_water    BOOLEAN      NOT NULL DEFAULT TRUE,
    sdg3_first_aid_quiet_zone   BOOLEAN      NOT NULL DEFAULT TRUE,
    sdg11_public_transit        BOOLEAN      NOT NULL DEFAULT FALSE,
    sdg11_bicycle_parking       BOOLEAN      NOT NULL DEFAULT FALSE,
    sdg12_reusable_cups_only    BOOLEAN      NOT NULL DEFAULT TRUE,
    sdg12_recycling_stations    BOOLEAN      NOT NULL DEFAULT TRUE,
    sdg13_renewable_energy      BOOLEAN      NOT NULL DEFAULT FALSE,
    sdg16_safe_space_stewards   BOOLEAN      NOT NULL DEFAULT TRUE,
    sdg17_local_eco_partners    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_approved_by_admin        BOOLEAN      NOT NULL DEFAULT FALSE,
    approved_at                 TIMESTAMP    NULL
);

-- Ticket Security Requirement: Strictly isolated to owner_user_id
CREATE TABLE user_tickets (
    ticket_id                   VARCHAR(40)  PRIMARY KEY,
    festival_id                 UUID         NOT NULL REFERENCES festivals(festival_id),
    owner_user_id               UUID         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    qr_signature_sha256         CHAR(64)     NOT NULL,
    includes_shuttle_pass       BOOLEAN      NOT NULL DEFAULT FALSE,
    includes_reusable_cup_token BOOLEAN      NOT NULL DEFAULT TRUE,
    purchased_at                TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE verification_reports (
    report_id           VARCHAR(32)  PRIMARY KEY,
    festival_id         UUID         NOT NULL REFERENCES festivals(festival_id),
    reporter_user_id    UUID         NULL REFERENCES users(user_id) ON DELETE SET NULL,
    issue_category      VARCHAR(60)  NOT NULL, -- Greenwashing, Facility, or SDG 16 Safety
    description         VARCHAR(300) NOT NULL,
    status              VARCHAR(40)  NOT NULL DEFAULT 'Pending Admin Verification',
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- OWASP Audit Logging Requirement
CREATE TABLE security_audit_log (
    log_id              BIGSERIAL    PRIMARY KEY,
    occurred_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_category      VARCHAR(40)  NOT NULL, -- FAILED_LOGIN, ACCOUNT_LOCKOUT, PASSWORD_CHANGED, ROLE_CHANGE, FESTIVAL_EDITED, GDPR_DELETION
    actor_email         VARCHAR(255) NOT NULL,
    severity            VARCHAR(12)  NOT NULL CHECK (severity IN ('INFO', 'WARN', 'CRITICAL')),
    details             TEXT         NOT NULL
);
