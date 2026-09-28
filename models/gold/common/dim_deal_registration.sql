{{
    config(
        materialized = 'table',
        tags         = ['gold', 'common', 'deal_registration']
    )
}}

------------------------------------------------------
-- Gold Model: dim_deal_registration
------------------------------------------------------
--   - Business-ready legacy deal registration dimension
--   - Sources from stg_deal_registration
--   - Filters deleted records
--   - Enriches with account, contact and user dim JOINs
--   - Mirrors vw_dim_deal_registration in Redshift
--   - registration_status: teaming_request_status aliased to
--     unified field name consistent with dim_unified_deal_registration
--   - deal_registration_type passed through as-is (legacy field name
--     maps directly to unified column name)
------------------------------------------------------

SELECT
    dr.deal_registration_id,
    dr.channel_account_manager_id,
    dr.created_by_id,
    CAST(dr.current_user_id AS STRING)                              AS current_user_id,
    dr.distributor_account_id,
    dr.distributor_rep_id,
    dr.infoblox_contact_id,
    dr.last_modified_by_id,
    dr.lead_id,
    dr.opportunity_id,
    dr.owner_id,
    dr.partner_account_id,
    dr.partner_sales_rep_id,
    dr.preferred_distributor_id,
    dr.rd_manager_for_approvals_id,
    dr.x18_digit_deal_registration_id,
    dr.x18_digit_owner_id,
    dr.add_teaming_partner,
    dr.am_approved,
    dr.am_rejected,
    dr.eligible_for_resubmission,
    dr.is_clone,
    dr.is_deleted,
    dr.is_resubmitted,
    dr.is_there_a_budget_defined,
    dr.partner_agrees_to_set_up_meeting,
    dr.partner_met_or_spoken_with_a_customer,
    dr.reprocess_notifications_distributor,

    -- unified field names (aligned with dim_unified_deal_registration)
    dr.teaming_request_status                                       AS registration_status,
    dr.deal_registration_type,
    dr.decline_reason                                               AS denial_reason,
    pa.account_name                                                 AS partner_account_name,
    da.account_name                                                 AS distributor_account_name,
    du.user_name                                                    AS distributor_rep_name,
    c.name                                                          AS infoblox_contact_name,
    ou.user_name                                                    AS opportunity_owner_name,
    rd.user_name                                                    AS opportunity_owner_rd_name,
    pu.user_name                                                    AS partner_sales_rep_name,
    dr.atgexternal_id,
    dr.business_justification_for_decline,
    dr.champion_business_title,
    TRIM(dr.champion_contact_email)                                 AS champion_contact_email,
    INITCAP(LOWER(NULLIF(TRIM(dr.champion_contact_first_name), ''))) AS champion_contact_first_name,
    INITCAP(LOWER(NULLIF(TRIM(dr.champion_contact_last_name), '')))  AS champion_contact_last_name,
    TRIM(dr.champion_contact_phone)                                 AS champion_contact_phone,
    TRIM(dr.company)                                                AS company,
    dr.currency_iso_code,
    dr.days_since_approval,
    dr.deal_reg_comments,
    dr.deal_registration_extension_approval,
    dr.deal_registration_name,
    dr.dealreg_extension_partner_justification,
    dr.denied_party_screening_status,
    TRIM(dr.lead_owner_email)                                       AS lead_owner_email,
    dr.infoblox_contact_mailto,
    dr.partner_support_comments,
    dr.products_of_interest,
    dr.project_driver,
    dr.reseller_company_name,
    dr.reseller_sales_rep_name,
    dr.resubmission_comments,
    dr.value_adds,
    dr.approved_date,
    dr.created_date,
    dr.expected_close_date,
    dr.expiration_date,
    dr.last_activity_date,
    dr.last_modified_date,
    dr.last_referenced_date,
    dr.last_viewed_date,
    dr.system_mod_stamp,
    CURRENT_TIMESTAMP()                                             AS edp_updated_at

FROM {{ ref('stg_deal_registration') }} dr

LEFT JOIN {{ ref('dim_account') }} pa
    ON dr.partner_account_id = pa.account_id

LEFT JOIN {{ ref('dim_account') }} da
    ON dr.distributor_account_id = da.account_id

LEFT JOIN {{ ref('dim_contact') }} c
    ON dr.infoblox_contact_id = c.contact_id

LEFT JOIN {{ ref('dim_user') }} pu
    ON dr.partner_sales_rep_id = pu.user_id

LEFT JOIN {{ ref('dim_user') }} du
    ON dr.distributor_rep_id = du.user_id

LEFT JOIN {{ ref('dim_user') }} ou
    ON dr.opportunity_owner = ou.user_id

LEFT JOIN {{ ref('dim_user') }} rd
    ON dr.opportunity_owner_rd = rd.user_id

WHERE dr.is_deleted = FALSE