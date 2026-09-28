{{
    config(
        materialized = 'table',
        tags         = ['gold', 'common', 'deal_registration', 'unified']
    )
}}

------------------------------------------------------
-- Gold Model: dim_unified_deal_registration
------------------------------------------------------
--   - Combines legacy and Vartopia deal registration
--     records into a single gold model
--   - Grain: one row per registration record per source system
--   - source_system distinguishes 'LEGACY' vs 'VARTOPIA'
--   - Legacy side sourced from dim_deal_registration
--   - Vartopia side sourced from dim_vartopia_deal_registration
--   - Both sources already deduped and dim-enriched upstream
--   - Trimmed to business-required columns only
--   - Full column sets available in the individual source models
--   - migrated_to_vartopia:
--       TRUE  = Vartopia reg has a matching legacy deal registration
--       FALSE = native post-rollout Vartopia registration
--   - is_native_vartopia_registration (inverse of migrated_to_vartopia):
--       TRUE  = genuine post-rollout Vartopia record
--       FALSE = migrated from legacy deal registration object
--   - registration_status: unified approval/status field
--       Legacy source:   teaming_request_status__c
--       Vartopia source: vendor_status
--   - deal_registration_type: unified deal type field
--       Legacy source:   deal_registration_type__c
--       Vartopia source: true_source (vartopiadrs__true_source__c)
------------------------------------------------------

------------------------------------------------------
-- LEGACY side
------------------------------------------------------
SELECT
    'LEGACY'                                                AS source_system,
    deal_registration_id                                    AS registration_id,

    CAST(NULL AS BOOLEAN)                                   AS migrated_to_vartopia,
    CAST(NULL AS BOOLEAN)                                   AS is_native_vartopia_registration,

    created_by_id,
    distributor_account_id,
    opportunity_id,

    CAST(NULL AS STRING)                                    AS opportunity_owner_id,

    partner_account_id,
    partner_sales_rep_id,
    distributor_account_name,
    opportunity_owner_name,
    partner_account_name,
    is_clone,
    is_deleted,
    add_teaming_partner,
    eligible_for_resubmission,
    is_resubmitted,
    approved_date,
    created_date,
    days_since_approval,
    deal_registration_name,
    denial_reason,
    expected_close_date,
    expiration_date,
    last_modified_date,
    deal_registration_type,
    registration_status,
    company,
    deal_reg_comments,
    partner_support_comments,
    products_of_interest,

    CAST(NULL AS STRING)                                    AS comments,
    CAST(NULL AS STRING)                                    AS customer_name,
    CAST(NULL AS STRING)                                    AS deal_name,
    CAST(NULL AS STRING)                                    AS internal_notes,
    CAST(NULL AS BOOLEAN)                                   AS is_registration_extended,
    CAST(NULL AS TIMESTAMP)                                 AS last_updated_for_vartopia,
    CAST(NULL AS TIMESTAMP)                                 AS reg_denied_date,

    edp_updated_at

FROM {{ ref('dim_deal_registration') }}

UNION ALL

------------------------------------------------------
-- VARTOPIA side
------------------------------------------------------
SELECT
    'VARTOPIA'                                              AS source_system,
    vartopia_registration_id                                AS registration_id,
    migrated_to_vartopia,
    is_native_vartopia_registration,
    created_by_id,
    distributor_account_id,
    opportunity_id,
    opportunity_owner_id,
    partner_account_id,

    CAST(NULL AS STRING)                                    AS partner_sales_rep_id,

    distributor_account_name,
    opportunity_owner_name,
    partner_account_name,
    is_clone,
    is_deleted,

    CAST(NULL AS BOOLEAN)                                   AS add_teaming_partner,
    CAST(NULL AS BOOLEAN)                                   AS eligible_for_resubmission,
    CAST(NULL AS BOOLEAN)                                   AS is_resubmitted,

    approved_date,
    created_date,
    days_since_approval,
    deal_registration_name,
    denial_reason,
    expected_close_date,
    expiration_date,
    last_modified_date,
    deal_registration_type,
    registration_status,

    CAST(NULL AS STRING)                                    AS company,
    CAST(NULL AS STRING)                                    AS deal_reg_comments,
    CAST(NULL AS STRING)                                    AS partner_support_comments,
    CAST(NULL AS STRING)                                    AS products_of_interest,

    comments,
    customer_name,
    deal_name,
    internal_notes,
    is_registration_extended,
    last_updated_for_vartopia,
    reg_denied_date,
    edp_updated_at

FROM {{ ref('dim_vartopia_deal_registration') }}