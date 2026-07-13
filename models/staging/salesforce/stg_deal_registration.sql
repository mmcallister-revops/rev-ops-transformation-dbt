{{
    config(
        materialized = 'view',
        tags         = ['staging', 'salesforce', 'deal_registration']
    )
}}

------------------------------------------------------
-- Staging Model: stg_deal_registration
------------------------------------------------------
--   - Thin rename layer over bronze_salesforce.deal_registration__c
--   - Removes __c suffixes, normalises booleans
--   - No deduplication, no business logic
--   - Is the source of truth for legacy deal registrations
--     (pre-Vartopia go-live)
--   - Referenced by gold.dim_deal_registration and used as the
--     lookup for migrated_to_vartopia in stg_vartopia_deal_registration
------------------------------------------------------

SELECT
    id                                                AS deal_registration_id,
    channel_account_manager__c                        AS channel_account_manager_id,
    createdbyid                                       AS created_by_id,
    current_user__c                                   AS current_user_id,
    distributor_account__c                            AS distributor_account_id,
    distributor_rep__c                                AS distributor_rep_id,
    infoblox_contact__c                               AS infoblox_contact_id,
    lastmodifiedbyid                                  AS last_modified_by_id,
    lead__c                                           AS lead_id,
    opportunity__c                                    AS opportunity_id,
    ownerid                                           AS owner_id,
    partner_account__c                                AS partner_account_id,
    partner_sales_rep__c                              AS partner_sales_rep_id,
    preferred_distributor__c                          AS preferred_distributor_id,
    rd_manager_for_approvals__c                       AS rd_manager_for_approvals_id,
    x18_digit_deal_registration_id__c                 AS x18_digit_deal_registration_id,
    x18_digit_owner_id__c                             AS x18_digit_owner_id,
    CASE
        WHEN LOWER(TRIM(CAST(add_teaming_partner__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS add_teaming_partner,
    CASE
        WHEN LOWER(TRIM(CAST(am_approved__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS am_approved,
    CASE
        WHEN LOWER(TRIM(CAST(am_rejected__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS am_rejected,
    CAST(approved_date__c AS TIMESTAMP)               AS approved_date,
    atgexternalid__c                                  AS atgexternal_id,
    business_justification_for_decline__c             AS business_justification_for_decline,
    champion_business_title__c                        AS champion_business_title,
    champion_contact_email__c                         AS champion_contact_email,
    champion_contact_first_name__c                    AS champion_contact_first_name,
    champion_contact_last_name__c                     AS champion_contact_last_name,
    champion_contact_phone__c                         AS champion_contact_phone,
    company__c                                        AS company,
    CAST(createddate AS TIMESTAMP)                    AS created_date,
    currencyisocode                                   AS currency_iso_code,
    days_since_approval__c                            AS days_since_approval,
    deal_reg_comments__c                              AS deal_reg_comments,
    deal_registration_extension_approval__c           AS deal_registration_extension_approval,
    deal_registration_type__c                         AS deal_registration_type,
    dealreg_extension_partner_justification__c        AS dealreg_extension_partner_justification,
    decline_reason__c                                 AS decline_reason,
    denied_party_screening_status__c                  AS denied_party_screening_status,
    CASE
        WHEN LOWER(TRIM(CAST(eligible_for_resubmission__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS eligible_for_resubmission,
    CAST(expected_close_date__c AS TIMESTAMP)         AS expected_close_date,
    expected_opportunity_amount__c                    AS expected_opportunity_amount,
    CAST(expiration_date__c AS TIMESTAMP)             AS expiration_date,
    infoblox_contact_mailto__c                        AS infoblox_contact_mailto,
    CASE
        WHEN LOWER(TRIM(CAST(is_clone__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS is_clone,
    CASE
        WHEN LOWER(TRIM(CAST(isdeleted AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS is_deleted,
    CASE
        WHEN LOWER(TRIM(CAST(resubmitted__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS is_resubmitted,
    is_there_a_budget_defined__c                      AS is_there_a_budget_defined,
    CAST(lastactivitydate AS TIMESTAMP)               AS last_activity_date,
    CAST(lastmodifieddate AS TIMESTAMP)               AS last_modified_date,
    CAST(lastreferenceddate AS TIMESTAMP)             AS last_referenced_date,
    CAST(lastvieweddate AS TIMESTAMP)                 AS last_viewed_date,
    lead_owner_email__c                               AS lead_owner_email,
    name                                              AS deal_registration_name,
    opportunity_owner__c                              AS opportunity_owner,
    opportunity_owner_rd__c                           AS opportunity_owner_rd,
    CASE
        WHEN LOWER(TRIM(CAST(partner_agrees_to_set_up_meeting__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS partner_agrees_to_set_up_meeting,
    CASE
        WHEN LOWER(TRIM(CAST(partner_met_or_spoken_with_a_customer__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS partner_met_or_spoken_with_a_customer,
    partner_support_comments__c                       AS partner_support_comments,
    product_s_of_interest__c                          AS products_of_interest,
    project_driver__c                                 AS project_driver,
    CASE
        WHEN LOWER(TRIM(CAST(reprocess_notifications_distributor__c AS VARCHAR(20)))) IN (
            'true', 't', '1', 'y', 'yes'
        ) THEN TRUE ELSE FALSE
    END                                               AS reprocess_notifications_distributor,
    reseller_company_name__c                          AS reseller_company_name,
    reseller_sales_rep_name__c                        AS reseller_sales_rep_name,
    resubmission_comments__c                          AS resubmission_comments,
    CAST(systemmodstamp AS TIMESTAMP)                 AS system_mod_stamp,
    teaming_request_status__c                         AS teaming_request_status,
    value_adds__c                                     AS value_adds

FROM {{ source('bronze_salesforce', 'deal_registration__c') }}
