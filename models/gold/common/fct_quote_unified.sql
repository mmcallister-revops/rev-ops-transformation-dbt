------------------------------------------------------
-- Gold Layer Fact: fct_quote_unified
-- Grain: one row per quote header (RCA + CPQ), latest row per quote.
------------------------------------------------------
{{ config(materialized='table') }}

WITH rca_latest AS (
    SELECT * FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY quote_id
            ORDER BY system_modstamp DESC, created_date DESC) AS _rn
        FROM {{ ref('quote') }}
        WHERE is_deleted = FALSE
    ) WHERE _rn = 1
),
rca AS (
    SELECT
        'RCA' AS source_system,
        quote_id,
        approval_status,
        co_term_end_date,
        created_date,
        end_date,
        expiration_date,
        is_deleted,
        CASE
            WHEN NULLIF(TRIM(legacy_quote_id),'') IS NOT NULL THEN TRUE
            ELSE FALSE
        END AS is_migrated_quote,
        CASE
            WHEN refresh_quote = TRUE
              OR COALESCE(TRY_CAST(gross_refresh_acv AS DECIMAL(33,15)),0) > 0
            THEN TRUE ELSE FALSE
        END AS is_refresh_quote,
        is_syncing,
        deal_reg_type AS primary_deal_reg_type,
        quote_number AS quote_name,
        quote_number,
        status AS quote_status,
        type AS quote_type,
        CASE
            WHEN refresh_quote = TRUE
            THEN TRUE ELSE FALSE
        END AS refresh_quote_flag,
        start_date,
        submitted_date,
        acv,
        acv_downsell,
        acv_override_gross_renewal_acv,
        b1ddi_net_renewal_acv,
        b1ddi_new_business_acv,
        b1td_net_renewal_acv,
        b1td_net_renewal_acv_override,
        b1td_new_business_acv,
        converted_perp_sw_acv,
        converted_term_sw_acv,
        existing_business_renewed_acv,
        expiring_acv_being_renewed,
        gross_renewal_acv_historical,
        renewal_forecast,
        saas_acv,
        saas_net_renewal_acv,
        saas_new_business_acv,
        true_expansion_acv,
        crosssell_upsell_acv,
        downsell_acv,
        expansion_acv,
        expiring_acv,
        expiring_acv_to_be_renewed,
        expiring_n_acv,
        gross_refresh_acv,
        gross_renewal_acv,
        acv_delta AS new_business_acv,
        prorated_expiring_acv,
        raw_expiring_acv,
        refresh_acv,
        refresh_retiring_acv,
        renewal_acv,
        tcv,
        uplift_acv,
        uplift_override
    FROM rca_latest
),
cpq_latest AS (
    SELECT * FROM {{ ref('sbqq__quote__c') }}
    WHERE is_current = TRUE AND is_deleted = FALSE
),
cpq AS (
    SELECT
        'CPQ' AS source_system,
        sbqq_quote_id AS quote_id,
        approval_status,
        CAST(NULL AS TIMESTAMP) AS co_term_end_date,
        created_date,
        sbqq_end_date AS end_date,
        sbqq_expiration_date AS expiration_date,
        is_deleted,
        FALSE AS is_migrated_quote,
        CASE
            WHEN refresh_quote = TRUE
              OR COALESCE(TRY_CAST(refresh_acv AS DECIMAL(30,4)),0) > 0
            THEN TRUE ELSE FALSE
        END AS is_refresh_quote,
        sbqq_primary AS is_syncing,
        deal_reg_type AS primary_deal_reg_type,
        quote_name,
        name AS quote_number,
        sbqq_status AS quote_status,
        sbqq_type AS quote_type,
        refresh_quote AS refresh_quote_flag,
        sbqq_start_date AS start_date,
        submitted_date,
        acv,
        acv_downsell,
        acv_override_gross_renewal_acv,
        b1ddi_net_renewal_acv,
        b1ddi_new_business_acv,
        b1td_net_renewal_acv,
        b1td_net_renewal_acv_override,
        b1td_new_business_acv,
        converted_perp_sw_acv,
        converted_term_sw_acv,
        renewal_acv AS existing_business_renewed_acv,
        CAST(0.00 AS DECIMAL(30,4)) AS expiring_acv_being_renewed,
        expiring_acv AS gross_renewal_acv_historical,
        renewal_forecast,
        CAST(0.00 AS DECIMAL(30,4)) AS saas_acv,
        CAST(0.00 AS DECIMAL(30,4)) AS saas_net_renewal_acv,
        saas_ddi_new_business_acv AS saas_new_business_acv,
        true_expansion_acv,
        expansion_acv AS crosssell_upsell_acv,
        downsell_acv,
        expansion_acv,
        expiring_acv,
        expiring_acv_to_be_renewed,
        expiring_n_acv,
        refresh_acv AS gross_refresh_acv,
        gross_renewal_acv,
        acv_delta AS new_business_acv,
        prorated_expiring_acv,
        raw_expiring_acv,
        refresh_acv,
        refresh_retiring_acv,
        renewal_acv,
        tcv,
        uplift2_acv AS uplift_acv,
        uplift_override
    FROM cpq_latest
),
unioned AS ( SELECT * FROM rca UNION ALL SELECT * FROM cpq ),

line_refresh_rollup AS (
    SELECT
        quote_id,
        MAX(CASE WHEN is_refresh_quote_line THEN 1 ELSE 0 END) AS _has_refresh_quote_line
    FROM {{ ref('fct_quote_line_unified') }}
    GROUP BY quote_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['source_system', 'quote_id']) }} AS quote_unified_sk,
    u.source_system,
    u.quote_id,
    u.approval_status,
    u.co_term_end_date,
    u.created_date,
    u.end_date,
    u.expiration_date,
    u.is_deleted,
    u.is_migrated_quote,
    u.is_refresh_quote,
    u.is_syncing,
    u.primary_deal_reg_type,
    u.quote_name,
    u.quote_number,
    u.quote_status,
    u.quote_type,
    u.refresh_quote_flag,
    u.start_date,
    u.submitted_date,
    CASE
        WHEN COALESCE(lr._has_refresh_quote_line, 0) = 1 THEN TRUE
        ELSE FALSE
    END AS has_refresh_quote_line,
    u.acv,
    u.acv_downsell,
    u.acv_override_gross_renewal_acv,
    u.b1ddi_net_renewal_acv,
    u.b1ddi_new_business_acv,
    u.b1td_net_renewal_acv,
    u.b1td_net_renewal_acv_override,
    u.b1td_new_business_acv,
    u.converted_perp_sw_acv,
    u.converted_term_sw_acv,
    u.crosssell_upsell_acv,
    u.downsell_acv,
    u.existing_business_renewed_acv,
    u.expansion_acv,
    u.expiring_acv,
    u.expiring_acv_being_renewed,
    u.expiring_acv_to_be_renewed,
    u.expiring_n_acv,
    u.gross_refresh_acv,
    u.gross_renewal_acv,
    u.gross_renewal_acv_historical,
    u.new_business_acv,
    u.prorated_expiring_acv,
    u.raw_expiring_acv,
    u.refresh_acv,
    u.refresh_retiring_acv,
    u.renewal_acv,
    u.renewal_forecast,
    u.saas_acv,
    u.saas_net_renewal_acv,
    u.saas_new_business_acv,
    u.tcv,
    u.true_expansion_acv,
    u.uplift_acv,
    u.uplift_override
FROM unioned u
LEFT JOIN line_refresh_rollup lr
    ON u.quote_id = lr.quote_id