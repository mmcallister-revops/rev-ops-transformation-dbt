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
--   - Deduplicates on vartopia_sf_registration_id when populated
--   - Falls back to partner_account_id + opportunity_id + expected_close_date
--     for records not yet synced to Vartopia
--   - Enriches account and opportunity-owner attributes
--   - migrated_to_vartopia and is_native_vartopia_registration passed
--     through from staging
--   - registration_status: vendor_status aliased to unified field name
--   - deal_registration_type: true_source aliased to unified field name
------------------------------------------------------

WITH deduped AS (

    SELECT
        *,

        ------------------------------------------------------
        -- Explicit reusable deduplication key
        ------------------------------------------------------
        COALESCE(
            NULLIF(TRIM(vartopia_sf_registration_id), ''),
            CONCAT_WS(
                '|',
                COALESCE(partner_account_id, 'NO_PARTNER'),
                COALESCE(opportunity_id, 'NO_OPP'),
                COALESCE(
                    CAST(DATE(expected_close_date) AS STRING),
                    'NO_DATE'
                )
            )
        ) AS _dedupe_key,

        ROW_NUMBER() OVER (
            PARTITION BY
                COALESCE(
                    NULLIF(TRIM(vartopia_sf_registration_id), ''),
                    CONCAT_WS(
                        '|',
                        COALESCE(partner_account_id, 'NO_PARTNER'),
                        COALESCE(opportunity_id, 'NO_OPP'),
                        COALESCE(
                            CAST(DATE(expected_close_date) AS STRING),
                            'NO_DATE'
                        )
                    )
                )
            ORDER BY
                COALESCE(is_clone, FALSE) ASC,
                COALESCE(is_created_by_auto_reg, FALSE) ASC,
                last_modified_date DESC,
                vartopia_registration_id ASC
        ) AS _row_num

    FROM {{ ref('stg_vartopia_deal_registration') }}

    WHERE is_deleted = FALSE

),

current_records AS (

    SELECT *
    FROM deduped
    WHERE _row_num = 1

)

SELECT
    dr.vartopia_registration_id,
    dr.am_vartopia_record_id,
    dr.child_registration_id,
    dr.created_by_id,
    dr.customer_account_id,
    dr.customer_account_owner_id,
    dr.customer_contact_id,
    dr.distributor_account_id,
    dr.distributor_contact_id,
    dr.lead_id,
    dr.mdf_campaign_id,
    dr.opportunity_id,
    dr.opportunity_owner_id,
    dr.partner_account_id,
    dr.partner_manager_2_id,
    dr.primary_registration_id,
    dr.prospect_contact_id,
    dr.sales_rep_id,
    dr.vartopia_sf_registration_id,
    dr.vendor_approval_id,

    dr.migrated_to_vartopia,
    dr.is_native_vartopia_registration,
    dr.is_approved_by_vartopia,
    dr.is_clone,
    dr.is_created_by_auto_reg,
    dr.is_created_from_mvs,
    dr.is_created_from_registration,
    dr.is_ez_update_eligible,
    dr.is_registration_extended,
    dr.is_registration_sent_to_vartopia,
    dr.is_send_update_request,
    dr.is_sent_to_vartopia,
    dr.is_sync_with_vartopia,

    ------------------------------------------------------
    -- Unified business fields
    ------------------------------------------------------
    dr.vendor_status AS registration_status,
    dr.true_source   AS deal_registration_type,

    ------------------------------------------------------
    -- Common-dimension enrichment
    ------------------------------------------------------
    pa.account_name  AS partner_account_name,
    da.account_name  AS distributor_account_name,
    ou.user_name     AS opportunity_owner_name,

    ------------------------------------------------------
    -- Remaining Vartopia attributes
    ------------------------------------------------------
    dr.active_customer_registrations,
    dr.am_campaign_id,
    dr.am_incentive_amount,
    dr.am_incentive_type,
    dr.am_program_name,
    dr.am_vendor_unique_id,
    dr.approved_regs_count,
    dr.approved_regs_partner_rep_count,
    dr.business_justification,
    dr.closed_won_partner_rep_count,
    dr.closed_won_regs_count,
    dr.comments,
    dr.contact_geo,
    dr.customer_address_line2,
    dr.customer_name,
    dr.days_since_approval,
    dr.days_to_approve,
    dr.days_to_denied,
    dr.days_to_progress,
    dr.deal_name,
    dr.deal_registration_name,
    dr.default_account_source,
    dr.default_account_type,
    dr.default_opp_stage,
    dr.denial_reason,
    dr.error_message,
    dr.extension_status,
    dr.internal_notes,
    dr.lead_source,
    dr.legacy_dr_id,
    dr.no_of_attempts,
    dr.opportunity_amount,
    dr.opportunity_stage_name,
    dr.partner_notes,
    dr.partner_status,
    dr.program_name,
    dr.reg_days_since_submitted,
    dr.registration_lot_number,
    dr.registration_url,
    dr.request_sent_count,
    dr.solution_name,
    dr.submitter_type,
    dr.updates_received_from_partner,
    dr.approved_date,
    dr.created_date,
    dr.current_date_time,
    dr.expected_close_date,
    dr.expiration_date,
    dr.last_modified_date,
    dr.last_referenced_date,
    dr.last_request_for_update,
    dr.last_update_provided_by_partner,
    dr.last_updated_for_vartopia,
    dr.last_viewed_date,
    dr.next_update_auto_request_date,
    dr.reg_auto_sync_time,
    dr.reg_denied_date,
    dr.time_to_approve,

    CURRENT_TIMESTAMP() AS edp_updated_at

FROM current_records dr

LEFT JOIN {{ ref('dim_account') }} pa
    ON dr.partner_account_id = pa.account_id

LEFT JOIN {{ ref('dim_account') }} da
    ON dr.distributor_account_id = da.account_id

LEFT JOIN {{ ref('dim_user') }} ou
    ON dr.opportunity_owner_id = ou.user_id