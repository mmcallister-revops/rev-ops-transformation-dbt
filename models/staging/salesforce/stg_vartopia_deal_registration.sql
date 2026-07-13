{{
    config(
        materialized = 'view',
        tags         = ['staging', 'salesforce', 'vartopia', 'deal_registration']
    )
}}

------------------------------------------------------
-- Staging Model: stg_vartopia_deal_registration
------------------------------------------------------
--   - Thin rename layer over
--     bronze_salesforce.salesforce_vartopiadrs__registration__c
--   - Removes vartopiadrs__ prefixes and __c suffixes
--   - Normalises boolean fields
--   - No deduplication — applied at gold layer
--   - migrated_to_vartopia flag:
--       TRUE  = opportunity_id matches a live record in
--               stg_deal_registration (legacy deal registration exists)
--       FALSE = no matching deal registration; native post-rollout Vartopia record
--   - is_native_vartopia_registration flag (inverse):
--       TRUE  = genuine post-June 2024 Vartopia registration
--       FALSE = migrated from legacy deal registration object
------------------------------------------------------

WITH legacy_dr_opps AS (
    -- Distinct opportunity IDs from the legacy deal registration staging model.
    -- Used to compute migrated_to_vartopia without a correlated subquery.
    SELECT DISTINCT opportunity_id
    FROM {{ ref('stg_deal_registration') }}
    WHERE is_deleted = FALSE
      AND opportunity_id IS NOT NULL
)

SELECT
    src.id                                                    AS vartopia_registration_id,

    src.createdbyid                                           AS created_by_id,
    src.distributor_contact__c                                AS distributor_contact_id,
    src.infoblox_partner_manager_2__c                         AS partner_manager_2_id,
    src.lastmodifiedbyid                                      AS last_modified_by_id,
    src.ownerid                                               AS owner_id,
    src.rd_manager__c                                         AS rd_manager_id,
    src.vartopiadrs__child_registration__c                    AS child_registration_id,
    src.vartopiadrs__customer__c                              AS customer_account_id,
    src.vartopiadrs__customer_account_ownerid__c              AS customer_account_owner_id,
    src.vartopiadrs__customer_contact__c                      AS customer_contact_id,
    src.vartopiadrs__distributor_account__c                   AS distributor_account_id,
    src.vartopiadrs__lead__c                                  AS lead_id,
    src.vartopiadrs__mdf_campaign__c                          AS mdf_campaign_id,
    src.vartopiadrs__opportunity__c                           AS opportunity_id,
    src.vartopiadrs__opportunity_ownerid__c                   AS opportunity_owner_id,
    src.vartopiadrs__partner_account__c                       AS partner_account_id,
    src.vartopiadrs__partner_manager__c                       AS partner_manager_id,
    src.vartopiadrs__partner_se_contact__c                    AS partner_se_contact_id,
    src.vartopiadrs__primary_registration1__c                 AS primary_registration_id,
    src.vartopiadrs__prospect_contact_id__c                   AS prospect_contact_id,
    src.vartopiadrs__sales_rep__c                             AS sales_rep_id,
    src.vartopiadrs__salesrep_contact__c                      AS salesrep_contact_id,
    src.vartopiadrs__submitter_contact__c                     AS submitter_contact_id,
    src.vartopiadrs__am_vartopia_record_id__c                 AS am_vartopia_record_id,
    src.vartopiadrs__vartopia_registration_id__c              AS vartopia_sf_registration_id,
    src.vartopiadrs__vendor_approval_id__c                    AS vendor_approval_id,
    src.vartopiadrs__vendor_deal_id__c                        AS vendor_deal_id,

    CASE
        WHEN src.vartopiadrs__opportunity__c IS NOT NULL
         AND legacy_dr_opps.opportunity_id IS NOT NULL
        THEN TRUE
        ELSE FALSE
    END                                                       AS migrated_to_vartopia,

    CASE
        WHEN src.vartopiadrs__opportunity__c IS NOT NULL
         AND legacy_dr_opps.opportunity_id IS NOT NULL
        THEN FALSE
        ELSE TRUE
    END                                                       AS is_native_vartopia_registration,

    CASE
        WHEN LOWER(TRIM(CAST(src.isdeleted AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_deleted,
    CASE
        WHEN LOWER(TRIM(CAST(src.is_clone__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_clone,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__approved_by_vartopia__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_approved_by_vartopia,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__created_by_auto_reg__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_created_by_auto_reg,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__created_from_mvs__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_created_from_mvs,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__created_from_registration__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_created_from_registration,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__ez_update_eligible__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_ez_update_eligible,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__registration_extended__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_registration_extended,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__registration_sent_to_vartopia__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_registration_sent_to_vartopia,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__send_update_request__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_send_update_request,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__sent_to_vartopia__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_sent_to_vartopia,
    CASE
        WHEN LOWER(TRIM(CAST(src.vartopiadrs__sync_registration_with_vartopia__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                                       AS is_sync_with_vartopia,

    TRIM(src.business_justification__c)                       AS business_justification,
    TRIM(src.default_account_source__c)                       AS default_account_source,
    TRIM(src.default_account_type__c)                         AS default_account_type,
    TRIM(src.default_opp_stage__c)                            AS default_opp_stage,
    TRIM(src.dr_type_validation__c)                           AS dr_type_validation,
    TRIM(src.infoblox_contact_geo__c)                         AS contact_geo,
    TRIM(src.internal_notes__c)                               AS internal_notes,
    TRIM(src.legacy_dr_id__c)                                 AS legacy_dr_id,
    TRIM(src.reminder_emails__c)                              AS reminder_emails,
    src.vartopiadrs__active_customer_registrations__c         AS active_customer_registrations,
    src.vartopiadrs__am_campaign_id__c                        AS am_campaign_id,
    src.vartopiadrs__am_incentive_amount__c                   AS am_incentive_amount,
    TRIM(src.vartopiadrs__am_incentive_type__c)               AS am_incentive_type,
    TRIM(src.vartopiadrs__am_program_name__c)                 AS am_program_name,
    TRIM(src.vartopiadrs__am_vendor_unique_id__c)             AS am_vendor_unique_id,
    CAST(src.vartopiadrs__approved_date__c AS TIMESTAMP)      AS approved_date,
    TRIM(src.vartopiadrs__comments__c)                        AS comments,
    TRIM(src.vartopiadrs__customer_addressline1__c)           AS customer_address_line1,
    TRIM(src.vartopiadrs__customer_addressline2__c)           AS customer_address_line2,
    TRIM(src.vartopiadrs__customer_city__c)                   AS customer_city,
    TRIM(src.vartopiadrs__customer_contact_email_new__c)      AS customer_contact_email,
    TRIM(src.vartopiadrs__customer_contact_first_name__c)     AS customer_contact_first_name,
    TRIM(src.vartopiadrs__customer_contact_job_title__c)      AS customer_contact_job_title,
    TRIM(src.vartopiadrs__customer_contact_last_name__c)      AS customer_contact_last_name,
    TRIM(src.vartopiadrs__customer_contact_phone__c)          AS customer_contact_phone,
    TRIM(src.vartopiadrs__customer_country__c)                AS customer_country,
    TRIM(src.vartopiadrs__customer_country_state__c)          AS customer_country_state,
    TRIM(src.vartopiadrs__customer_industry__c)               AS customer_industry,
    TRIM(src.vartopiadrs__customer_name__c)                   AS customer_name,
    TRIM(src.vartopiadrs__customer_state__c)                  AS customer_state,
    TRIM(src.vartopiadrs__customer_website__c)                AS customer_website,
    TRIM(src.vartopiadrs__customer_zip__c)                    AS customer_zip,
    CAST(src.vartopiadrs__current_date_time__c AS TIMESTAMP)  AS current_date_time,
    src.vartopiadrs__days_to_approve__c                       AS days_to_approve,
    src.days_since_approval__c                                AS days_since_approval,
    src.vartopiadrs__days_to_denied__c                        AS days_to_denied,
    src.vartopiadrs__days_to_progress__c                      AS days_to_progress,
    TRIM(src.vartopiadrs__deal_name__c)                       AS deal_name,
    TRIM(src.vartopiadrs__denial_reason__c)                   AS denial_reason,
    TRIM(src.vartopiadrs__domain__c)                          AS domain,
    TRIM(src.vartopiadrs__error_message__c)                   AS error_message,
    CAST(src.vartopiadrs__expected_close_date__c AS TIMESTAMP) AS expected_close_date,
    src.vartopiadrs__expected_revenue__c                      AS expected_revenue,
    CAST(src.vartopiadrs__expiration_date__c AS TIMESTAMP)    AS expiration_date,
    TRIM(src.vartopiadrs__extension_status__c)                AS extension_status,
    TRIM(src.vartopiadrs__lead_source__c)                     AS lead_source,
    CAST(src.vartopiadrs__last_request_for_update__c AS TIMESTAMP)          AS last_request_for_update,
    CAST(src.vartopiadrs__last_update_provided_by_partner__c AS TIMESTAMP)  AS last_update_provided_by_partner,
    CAST(src.vartopiadrs__last_updated_for_vartopia__c AS TIMESTAMP)        AS last_updated_for_vartopia,
    TRIM(src.name)                                            AS deal_registration_name,
    CAST(src.vartopiadrs__next_update_auto_request_date__c AS TIMESTAMP)    AS next_update_auto_request_date,
    src.vartopiadrs__no_of_attempts__c                        AS no_of_attempts,
    src.vartopiadrs__of_approved_regs__c                      AS approved_regs_count,
    src.vartopiadrs__of_approved_regs_partner_rep__c          AS approved_regs_partner_rep_count,
    src.vartopiadrs__of_closed_won_partner_rep__c             AS closed_won_partner_rep_count,
    src.vartopiadrs__of_closed_won_regs__c                    AS closed_won_regs_count,
    src.vartopiadrs__opportunity_amount__c                    AS opportunity_amount,
    TRIM(src.vartopiadrs__opportunity_stagename__c)           AS opportunity_stage_name,
    TRIM(src.vartopiadrs__partner_notes__c)                   AS partner_notes,
    TRIM(src.vartopiadrs__partner_se_email__c)                AS partner_se_email,
    TRIM(src.vartopiadrs__partner_se_firstname__c)            AS partner_se_first_name,
    TRIM(src.vartopiadrs__partner_se_lastname__c)             AS partner_se_last_name,
    TRIM(src.vartopiadrs__partner_se_phonenumber__c)          AS partner_se_phone,
    TRIM(src.vartopiadrs__partner_status__c)                  AS partner_status,
    TRIM(src.vartopiadrs__primary_salesrep_email_new__c)      AS primary_salesrep_email,
    TRIM(src.vartopiadrs__primary_salesrep_firstname__c)      AS primary_salesrep_first_name,
    TRIM(src.vartopiadrs__primary_salesrep_lastname__c)       AS primary_salesrep_last_name,
    TRIM(src.vartopiadrs__primary_salesrep_phone__c)          AS primary_salesrep_phone,
    TRIM(src.vartopiadrs__program_name__c)                    AS program_name,
    CAST(src.vartopiadrs__reg_auto_sync_time__c AS TIMESTAMP) AS reg_auto_sync_time,
    src.vartopiadrs__reg_days_since_submitted__c              AS reg_days_since_submitted,
    CAST(src.vartopiadrs__reg_denied_date__c AS TIMESTAMP)    AS reg_denied_date,
    src.vartopiadrs__registration_lot_number__c               AS registration_lot_number,
    TRIM(src.vartopiadrs__registration_url__c)                AS registration_url,
    src.vartopiadrs__request_sent__c                          AS request_sent_count,
    TRIM(src.vartopiadrs__solution_name__c)                   AS solution_name,
    TRIM(src.vartopiadrs__submitted_by_email_new__c)          AS submitted_by_email,
    TRIM(src.vartopiadrs__submitted_by_firstname__c)          AS submitted_by_first_name,
    TRIM(src.vartopiadrs__submitted_by_lastname__c)           AS submitted_by_last_name,
    TRIM(src.vartopiadrs__submitted_by_phonenumber__c)        AS submitted_by_phone,
    TRIM(src.vartopiadrs__submitter_type__c)                  AS submitter_type,
    CAST(src.vartopiadrs__time_to_approve__c AS TIMESTAMP)    AS time_to_approve,
    TRIM(src.vartopiadrs__true_source__c)                     AS true_source,
    src.vartopiadrs__updates_received_from_partner__c         AS updates_received_from_partner,
    TRIM(src.vartopiadrs__vendor_status__c)                   AS vendor_status,
    TRIM(src.currencyisocode)                                 AS currency_iso_code,
    CAST(src.createddate AS TIMESTAMP)                        AS created_date,
    CAST(src.lastactivitydate AS TIMESTAMP)                   AS last_activity_date,
    CAST(src.lastmodifieddate AS TIMESTAMP)                   AS last_modified_date,
    CAST(src.lastreferenceddate AS TIMESTAMP)                 AS last_referenced_date,
    CAST(src.lastvieweddate AS TIMESTAMP)                     AS last_viewed_date,
    CAST(src.systemmodstamp AS TIMESTAMP)                     AS system_mod_stamp

FROM {{ source('bronze_salesforce', 'salesforce_vartopiadrs__registration__c') }} src
LEFT JOIN legacy_dr_opps
    ON src.vartopiadrs__opportunity__c = legacy_dr_opps.opportunity_id
