{{ config(
    materialized = 'table',
    schema       = 'common',
    tags         = ['gold','dimension','salesforce']
) }}

-- ============================================================
-- MODEL: dim_opportunity
-- Grain: one row per opportunity (current SCD2 version)

--
-- UAT reconciliation notes (delivered separately in the .md):
--   * Owner attributes now sourced from ref('dim_user') (our enriched dim),
--     not raw ref('user'). REV attributed owner geo/territory off the
--     opportunity's own denormalised fields; this model attributes via the
--     user dim kyeed on owner_id, is_current = TRUE (point-in-time, not
--     historically-correct). Divergence is intentional and artifact-noted.
--   * record_type description now sourced from ref('recordtype') instead of
--     a hardcoded SFDC-id CASE (drift risk: a new record type = silent NULL).
--   * stage_group restored (Unqualified/Qualified)
--   * close_date_prior / _change_count / _push_count rebuilt from field history.
--   * sales_forecast_category_bridge restored (mid-year stage change accounted
--     for; keys off stage_name text, not the numeric priority).
--   * has_bva_task_without_bva_record restored (BVA team QA coverage flag).
--   * opportunity_exclude_flag_revops added alongside DL's exclude flag; the
--     closed-lost + exclude combo is left to the semantic layer by design.
--   * Boolean fields kept native boolean (no 0/1 or 'Y'/'N'
--   * tackle_flag and approval_status dropped (unsourced literals; KPMG/DL to
--     justify a hardcoded 'N' / NULL if the business needs them back).
-- ============================================================

WITH owner_lkp AS (

    SELECT
        user_id,
        user_name,
        geo,
        region,
        profile_name
    FROM {{ ref('dim_user') }}

),

bill_data AS (

    SELECT
        b.address_id,
        a.bill_country
    FROM {{ ref('dim_address') }} b
    LEFT JOIN {{ ref('dim_account') }} a
        ON b.account_id = a.account_id

),

record_type_lkp AS (

    SELECT
        record_type_id,
        record_type_name
    FROM {{ ref('recordtype') }}
    WHERE is_current = TRUE
        AND COALESCE(is_deleted, FALSE) = FALSE

),

stage_map AS (
    -- REV stage_map: supplies stage_group + stage_order. Retained verbatim.
    SELECT 'Prospect'                  AS stage_name, 1  AS stage_order, 'Unqualified' AS stage_group
    UNION ALL SELECT 'Qualify',                       2,                'Unqualified'
    UNION ALL SELECT 'Build & Validate',              3,                'Qualified'
    UNION ALL SELECT 'Negotiate',                     4,                'Qualified'
    UNION ALL SELECT 'Confirm',                       5,                'Qualified'
    UNION ALL SELECT 'Customer PO In Process',        6,                'Qualified'
    UNION ALL SELECT 'PO In House',                   7,                'Qualified'
    UNION ALL SELECT 'Awaiting Service Delivery',     8,                'Qualified'
    UNION ALL SELECT 'Closed Won',                    9,                'Closed'
    UNION ALL SELECT 'Closed Lost',                   10,               'Closed'
    UNION ALL SELECT 'Closed',                        11,               'Closed'

),

close_date_history AS (

    SELECT
        fh.opportunity_id,
        fh.created_date                          AS history_created_date,
        TRY_CAST(fh.old_value AS TIMESTAMP)      AS prior_close_date_raw,
        TRY_CAST(fh.new_value AS TIMESTAMP)      AS new_close_date_raw
    FROM {{ ref('opportunity_field_history') }} fh
    WHERE COALESCE(fh.is_deleted, FALSE) = FALSE
      AND LOWER(COALESCE(fh.field_name, '')) = 'closedate'

),

close_date_ranked AS (

    SELECT
        cdh.*,
        ROW_NUMBER() OVER (
            PARTITION BY cdh.opportunity_id
            ORDER BY cdh.history_created_date DESC
        ) AS rn_desc
    FROM close_date_history cdh

),

close_date_metrics AS (

    SELECT
        cdh.opportunity_id,
        MAX(CASE WHEN cdh.rn_desc = 1 THEN cdh.prior_close_date_raw END) AS close_date_prior,
        COUNT(*) AS close_date_change_count,
        SUM(
            CASE
                WHEN cdh.prior_close_date_raw IS NOT NULL
                 AND cdh.new_close_date_raw   IS NOT NULL
                 AND cdh.new_close_date_raw > cdh.prior_close_date_raw
                THEN 1 ELSE 0
            END
        ) AS close_date_push_count
    FROM close_date_ranked cdh
    GROUP BY cdh.opportunity_id

),

bva_task AS (

    SELECT
        t.resolved_opportunity_id            AS opportunity_id,
        COUNT(DISTINCT t.task_id)            AS bva_support_task_count
    FROM {{ ref('dim_task') }} t
    WHERE t.record_type_name = 'BVA Support Request'
      AND t.resolved_opportunity_id IS NOT NULL
    GROUP BY t.resolved_opportunity_id

),

bva AS (

    SELECT DISTINCT
        vp.opportunity_id AS opportunity_id
    FROM {{ ref('dim_vc_value_proposition') }} vp
    WHERE vp.opportunity_id IS NOT NULL

)

SELECT

    o.opportunity_id,
    o.account_id,
    o.ae_acceptance_status,
    o.age,
    o.amended_contract,
    o.bdr_created_opportunity,
    o.blox_one_ps_provider,
    COALESCE(bt.bva_support_task_count, 0) AS bva_support_task_count,
    o.campaign_id,
    o.close_date,
    COALESCE(cdm.close_date_change_count, 0) AS close_date_change_count,
    cdm.close_date_prior,
    COALESCE(cdm.close_date_push_count, 0) AS close_date_push_count,
    o.cloud_marketplace,
    o.co_sell_registered,
    o.contact,
    o.created_date,
    o.created_by_id,
    o.daybreak_status,
    o.deal_reg_type,
    o.deal_term_in_months AS deal_term_month,
    o.decommission_reason,
    o.discovery_notes,
    o.distributor2 AS distributor_id,
    o.dl_vc_has_value_proposition,
    o.drop_down_status_of_arch_workbook_sa_ow,
    o.is_ela AS ela_flag,
    o.expiration_date,
    CASE
        WHEN COALESCE(bt.bva_support_task_count, 0) > 0
         AND b.opportunity_id IS NULL
        THEN TRUE ELSE FALSE
    END AS has_bva_task_without_bva_record,
    o.health_check,
    o.hold_reasons,
    o.is_there_a_defined_budget,
    o.is_there_a_specific_need,
    o.in_flight_legal_negotiations,
    o.last_modified_by_opportunity_owner,
    o.last_stage_change_date_c AS last_stage_change_date_standard,
    o.lead_source,
    o.level_of_authority,
    o.marketplace_transaction_type,
    o.next_step,
    o.next_steps,
    CASE
        WHEN o.stage_prior_to_close IN ('Prospect', 'Qualify')
            THEN TRUE
        ELSE FALSE
    END AS non_qualified_loss_flag,
    o.opportunity_deal_source,
    o.description AS opportunity_desc,
    CASE
        WHEN o.stage_name = 'Closed Lost'
         AND (
             UPPER(COALESCE(o.win_loss_reason,'')) LIKE '%DUPLICATE OPPORTUNITY%'
             OR UPPER(COALESCE(o.win_loss_reason,'')) LIKE '%UNQUALIFIED%'
             OR UPPER(COALESCE(o.secondary_win_loss_reason,'')) LIKE '%DUPLICATE OPPORTUNITY%'
             OR UPPER(COALESCE(o.secondary_win_loss_reason,'')) LIKE '%UNQUALIFIED%'
             OR o.stage_prior_to_close IN ('Prospect','Qualify')
         )
        THEN TRUE ELSE FALSE
    END AS closed_lost_exclusion_flag,
    CASE
        WHEN COALESCE(o.win_loss_reason, 'N/A') IN (
                    'Co-Termed',
                    'Duplicate Opportunity',
                    'Co-Termed / Duplicate Opportunity')
          OR COALESCE(o.secondary_win_loss_reason, 'N/A') = 'Duplicate Opportunity'
        THEN TRUE ELSE FALSE
    END AS revops_reporting_exclusion_flag,
    o.opportunity_incumbent,
    o.name AS opportunity_name,
    bt_addr.bill_country AS opportunity_owner_country,
    ol.geo AS opportunity_owner_geo,
    o.owner_id AS opportunity_owner_id,
    ol.user_name AS opportunity_owner_name,
    ol.region AS opportunity_owner_region,
    o.record_type_id AS opportunity_record_type,
    rtl.record_type_name AS opportunity_record_type_desc,
    o.expansion as opportunity_sales_motion,
    sm.stage_group,
    o.stage_name AS opportunity_stage,
    sm.stage_order,
    o.type AS opportunity_type,
    o.order_type,
    o.om_order_type AS order_type_desc,
    o.other_primary_competitor,
    o.owner_territory,
    o.territory_id as owner_territory_id,
    o.partner_account_name,
    o.po_mismatch,
    o.primary_competitor,
    o.teaming_hunting AS primary_quote_deal_reg,
    o.compelling_project_driver AS project_driver,
    o.opportunity_source AS ps_source_opportunity,
    o.purchase_timeframe,
    o.qualified_date,
    o.renewal_at_risk,
    o.renewal_forecast,
    COALESCE(
        NULLIF(TRIM(o.synced_quote_id), ''),
        NULLIF(TRIM(o.sbqq_primary_quote), '')
    ) AS resolved_synced_quote_id,
    CASE
        WHEN NULLIF(TRIM(synced_quote_id), '') IS NOT NULL
            THEN 'RCA'
        WHEN NULLIF(TRIM(o.sbqq_primary_quote), '') IS NOT NULL
            THEN 'CPQ'
        ELSE NULL
    END AS resolved_quote_source_system,
    o.reseller_id,
    o.reseller_level,
    o.reseller_partner_classification,
    o.reseller_partner_segmentation,
    o.risk_validation,
    o.sal_date,
    o.sales_forecast_category,
    -- Sales forecast category bridge (REV): fills a null category from stage.
    -- Keys off stage_name text, so the mid-year stage renumbering doesn't affect it.
    CASE
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Build & Validate'        THEN 'Pipeline'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Closed Lost'             THEN 'Closed Lost'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Closed Won'              THEN 'Closed Won'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Confirm'                 THEN 'Strong Upside'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Negotiate'               THEN 'Upside'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name IN ('Prospect','Qualify')   THEN 'Omitted'
        WHEN o.sales_forecast_category IS NULL AND o.stage_name = 'Customer PO In Process'  THEN 'Commit'
        ELSE o.sales_forecast_category
    END AS sales_forecast_category_bridge,
    o.sbqq_amended_contract AS sbqq_amended_contract,
    o.secondary_win_loss_reason,
    o.saas_products AS sp_products,
    o.sql_date,
    o.stage_prior_to_close,
    o.technical_win,
    o.vartopia_primary_id,
    o.why_change,
    o.why_infoblox,
    o.why_now,
    o.win_loss_reason,
    o.win_loss_comments AS win_loss_reason_desc,

    -- Metadata tail (fixed order)
    o.opportunity_scd_id,
    o.last_modified_date,
    o.edp_valid_from,
    o.edp_valid_to,
    o.edp_updated_at,
    o.is_current,
    o.is_deleted

FROM {{ ref('opportunity') }} O

LEFT JOIN owner_lkp ol
    ON o.owner_id = ol.user_id

LEFT JOIN bill_data bt_addr
    ON o.bill_to = bt_addr.address_id

LEFT JOIN record_type_lkp rtl
    ON o.record_type_id = rtl.record_type_id

LEFT JOIN stage_map sm
    ON o.stage_name = sm.stage_name

LEFT JOIN close_date_metrics cdm
    ON o.opportunity_id = cdm.opportunity_id

LEFT JOIN bva_task bt
    ON o.opportunity_id = bt.opportunity_id

LEFT JOIN bva b
    ON o.opportunity_id = b.opportunity_id

WHERE is_current = TRUE