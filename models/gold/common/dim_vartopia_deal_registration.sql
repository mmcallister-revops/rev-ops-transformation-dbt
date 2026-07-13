{{
    config(
        materialized = 'table',
        tags         = ['gold', 'common', 'vartopia', 'deal_registration']
    )
}}

------------------------------------------------------
-- Gold Model: dim_vartopia_deal_registration
------------------------------------------------------
--   - Business-ready consumption layer for Vartopia deal registrations
--   - Sources from stg_vartopia_deal_registration
--   - Filters deleted records
--   - Deduplicates on vartopia_sf_registration_id (Vartopia system key),
--     falling back to partner_account_id + opportunity_id + expected_close_date
--     for records not yet synced to Vartopia
--   - Resolves duplicate first/last name fields into single display name columns
--   - migrated_to_vartopia and is_native_vartopia_registration passed
--     through from staging
------------------------------------------------------

WITH deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(
                    NULLIF(TRIM(vartopia_sf_registration_id), ''),
                    partner_account_id
                        || '|' || COALESCE(opportunity_id, 'NO_OPP')
                        || '|' || COALESCE(CAST(DATE(expected_close_date) AS STRING), 'NO_DATE')
                )
            ORDER BY
                is_clone ASC,               -- originals over clones
                is_created_by_auto_reg ASC, -- manual over auto-reg
                last_modified_date DESC,    -- most recently updated wins
                vartopia_registration_id ASC -- deterministic tiebreak
        ) AS _row_num
    FROM {{ ref('stg_vartopia_deal_registration') }}
    WHERE is_deleted = FALSE
)

SELECT
    vartopia_registration_id,
    am_vartopia_record_id,
    child_registration_id,
    created_by_id,
    customer_account_id,
    customer_account_owner_id,
    customer_contact_id,
    distributor_account_id,
    distributor_contact_id,
    last_modified_by_id,
    lead_id,
    mdf_campaign_id,
    opportunity_id,
    opportunity_owner_id,
    owner_id,
    partner_account_id,
    partner_manager_id,
    partner_manager_2_id,
    partner_se_contact_id,
    primary_registration_id,
    prospect_contact_id,
    rd_manager_id,
    sales_rep_id,
    salesrep_contact_id,
    submitter_contact_id,
    vartopia_sf_registration_id,
    vendor_approval_id,
    vendor_deal_id,
    migrated_to_vartopia,
    is_native_vartopia_registration,
    CASE
        WHEN NULLIF(TRIM(submitted_by_first_name), '') IS NOT NULL
         AND NULLIF(TRIM(submitted_by_last_name), '') IS NOT NULL
        THEN INITCAP(LOWER(NULLIF(TRIM(submitted_by_first_name), '')))
             || ' ' ||
             INITCAP(LOWER(NULLIF(TRIM(submitted_by_last_name), '')))
        ELSE INITCAP(LOWER(NULLIF(TRIM(deal_registration_name), '')))
    END                                                           AS submitter_name,
    CASE
        WHEN NULLIF(TRIM(primary_salesrep_first_name), '') IS NOT NULL
         AND NULLIF(TRIM(primary_salesrep_last_name), '') IS NOT NULL
        THEN INITCAP(LOWER(NULLIF(TRIM(primary_salesrep_first_name), '')))
             || ' ' ||
             INITCAP(LOWER(NULLIF(TRIM(primary_salesrep_last_name), '')))
        ELSE NULL
    END                                                           AS primary_salesrep_name,
    CASE
        WHEN NULLIF(TRIM(partner_se_first_name), '') IS NOT NULL
         AND NULLIF(TRIM(partner_se_last_name), '') IS NOT NULL
        THEN INITCAP(LOWER(NULLIF(TRIM(partner_se_first_name), '')))
             || ' ' ||
             INITCAP(LOWER(NULLIF(TRIM(partner_se_last_name), '')))
        ELSE NULL
    END                                                           AS partner_se_name,
    CASE
        WHEN NULLIF(TRIM(customer_contact_first_name), '') IS NOT NULL
         AND NULLIF(TRIM(customer_contact_last_name), '') IS NOT NULL
        THEN INITCAP(LOWER(NULLIF(TRIM(customer_contact_first_name), '')))
             || ' ' ||
             INITCAP(LOWER(NULLIF(TRIM(customer_contact_last_name), '')))
        ELSE NULL
    END                                                           AS customer_contact_name,
    active_customer_registrations,
    am_campaign_id,
    am_incentive_amount,
    am_incentive_type,
    am_program_name,
    am_vendor_unique_id,
    approved_regs_count,
    approved_regs_partner_rep_count,
    business_justification,
    closed_won_partner_rep_count,
    closed_won_regs_count,
    comments,
    contact_geo,
    currency_iso_code,
    customer_address_line1,
    customer_address_line2,
    customer_city,
    customer_contact_email,
    customer_contact_job_title,
    customer_contact_phone,
    customer_country,
    customer_country_state,
    customer_industry,
    customer_name,
    customer_state,
    customer_website,
    customer_zip,
    days_since_approval,
    days_to_approve,
    days_to_denied,
    days_to_progress,
    deal_name,
    deal_registration_name,
    default_account_source,
    default_account_type,
    default_opp_stage,
    denial_reason,
    domain,
    dr_type_validation,
    error_message,
    extension_status,
    internal_notes,
    is_approved_by_vartopia,
    is_clone,
    is_created_by_auto_reg,
    is_created_from_mvs,
    is_created_from_registration,
    is_ez_update_eligible,
    is_registration_extended,
    is_registration_sent_to_vartopia,
    is_send_update_request,
    is_sent_to_vartopia,
    is_sync_with_vartopia,
    lead_source,
    legacy_dr_id,
    no_of_attempts,
    opportunity_amount,
    opportunity_stage_name,
    partner_notes,
    partner_se_email,
    partner_se_phone,
    partner_status,
    primary_salesrep_email,
    primary_salesrep_phone,
    program_name,
    reg_days_since_submitted,
    registration_lot_number,
    registration_url,
    reminder_emails,
    request_sent_count,
    solution_name,
    submitted_by_email,
    submitted_by_phone,
    submitter_type,
    true_source,
    updates_received_from_partner,
    vendor_status,
    approved_date,
    created_date,
    current_date_time,
    expected_close_date,
    expiration_date,
    last_activity_date,
    last_modified_date,
    last_referenced_date,
    last_request_for_update,
    last_update_provided_by_partner,
    last_updated_for_vartopia,
    last_viewed_date,
    next_update_auto_request_date,
    reg_auto_sync_time,
    reg_denied_date,
    system_mod_stamp,
    time_to_approve,
    CURRENT_TIMESTAMP()                                           AS edp_updated_at

FROM deduped
WHERE _row_num = 1
