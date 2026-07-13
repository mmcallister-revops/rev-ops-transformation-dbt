------------------------------------------------------
-- Gold Layer Dimension: dim_quote_unified
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
line_count_rollup AS (
    SELECT quote_id, COUNT(*) AS _quote_line_count
    FROM {{ ref('fct_quote_line_unified') }}
    GROUP BY quote_id
),
rca AS (
    SELECT
        'RCA' AS source_system,
        q.quote_id,
        q.account_id,
        q.created_by_id,
        q.distributor AS distributor_id,
        q.last_modified_by_id,
        q.legacy_quote_id,
        q.opportunity_id,
        q.owner_id,
        q.partner_account_id  AS partner_account_id, --api name partneraccountid; fix from null in {quote}
        q.pricebook2_id,
        q.price_book AS price_book_id,
        q.record_type_id,
        q.reseller AS reseller_id,
        q.sales_rep AS sales_rep_id,
        q.ship_to_contact AS ship_to_contact_id,
        q.ship_to_id,
        q.submitted_user AS submitted_user_id,
        q.approval_status,
        q.co_term_end_date,
        q.created_date,
        q.deal_justification AS business_justification,
        CAST(NULL AS STRING) AS discount_justification,
        q.end_date,
        q.expiration_date,
        q.is_deleted,
        CASE
            WHEN NULLIF(TRIM(q.legacy_quote_id),'') IS NOT NULL THEN TRUE
            ELSE FALSE
        END AS is_migrated_quote,
        CASE
            WHEN q.refresh_quote = TRUE
              OR COALESCE(TRY_CAST(q.gross_refresh_acv AS DECIMAL(33,15)),0) > 0
            THEN TRUE
            ELSE FALSE
        END AS is_refresh_quote,
        q.is_syncing,
        q.line_item_count,
        q.opportunity_close_date,
        q.deal_reg_type AS primary_deal_reg_type,
        q.promotion,
        q.quote_number AS quote_name,
        COALESCE(lc._quote_line_count, 0) AS quote_line_count,
        q.quote_number,
        q.status AS quote_status,
        q.type AS quote_type,
        CASE
            WHEN q.refresh_quote = TRUE
            THEN TRUE
            ELSE FALSE
        END AS refresh_quote_flag,
        q.start_date,
        q.subscription_term,
        q.submitted_date,
        q.system_modstamp
    FROM rca_latest q
    LEFT JOIN line_count_rollup lc
        ON q.quote_id = lc.quote_id
),
cpq_latest AS (
    SELECT * FROM {{ ref('sbqq__quote__c') }}
    WHERE is_current = TRUE AND is_deleted = FALSE
),
cpq AS (
    SELECT
        'CPQ' AS source_system,
        sbqq_quote_id AS quote_id,
        sbqq_account AS account_id,
        created_by_id,
        sbqq_distributor AS distributor_id,
        last_modified_by_id,
        CAST(NULL AS STRING) AS legacy_quote_id,
        sbqq_opportunity2 AS opportunity_id,
        owner_id,
        CAST(NULL AS STRING) AS partner_account_id,
        sbqq_pricebook_id AS pricebook2_id,
        sbqq_price_book AS price_book_id,
        record_type_id,
        reseller AS reseller_id,
        sbqq_sales_rep AS sales_rep_id,
        CAST(NULL AS STRING) AS ship_to_contact_id,
        ship_to AS ship_to_id,
        submitted_user AS submitted_user_id,
        approval_status,
        CAST(NULL AS TIMESTAMP) AS co_term_end_date,
        created_date,
        business_justification,
        discount_justification,
        sbqq_end_date AS end_date,
        sbqq_expiration_date AS expiration_date,
        is_deleted,
        FALSE AS is_migrated_quote,
        CASE
            WHEN refresh_quote = TRUE
              OR COALESCE(TRY_CAST(refresh_acv AS DECIMAL(33,15)),0) > 0
            THEN TRUE ELSE FALSE
        END AS is_refresh_quote,
        sbqq_primary AS is_syncing,
        sbqq_line_item_count AS line_item_count,
        opportunity_close_date,
        deal_reg_type AS primary_deal_reg_type,
        promotion,
        quote_name,
        sbqq_line_item_count AS quote_line_count,
        name AS quote_number,
        sbqq_status AS quote_status,
        sbqq_type AS quote_type,
        refresh_quote AS refresh_quote_flag,
        sbqq_start_date AS start_date,
        sbqq_subscription_term AS subscription_term,
        submitted_date,
        system_modstamp
    FROM cpq_latest
),
unioned AS ( SELECT * FROM rca UNION ALL SELECT * FROM cpq )

SELECT
    {{ dbt_utils.generate_surrogate_key(['source_system', 'quote_id']) }} AS quote_unified_sk,
    u.source_system,
    u.quote_id,
    u.account_id,
    u.created_by_id,
    u.distributor_id,
    u.last_modified_by_id,
    u.legacy_quote_id,
    u.opportunity_id,
    /*
    CASE
        WHEN u.quote_id = pq.resolved_synced_quote_id THEN TRUE
        ELSE FALSE
    END AS is_opportunity_synced_quote,
    has_synced_quote_flag,
    pq.synced_quote_source,
    pq.has_both_rca_and_cpq_synced,
    */
    u.owner_id,
    u.partner_account_id,
    u.pricebook2_id,
    u.price_book_id,
    u.record_type_id,
    rt.record_type_name,
    u.reseller_id,
    u.sales_rep_id,
    u.ship_to_contact_id,
    u.ship_to_id,
    u.submitted_user_id,
    u.approval_status,
    u.co_term_end_date,
    u.created_date,
    u.discount_justification,
    u.end_date,
    u.expiration_date,
    u.is_migrated_quote,
    u.is_refresh_quote,
    u.is_syncing,
    u.line_item_count,
    u.opportunity_close_date,
    u.primary_deal_reg_type,
    u.promotion,
    u.quote_line_count,
    u.quote_name,
    u.quote_number,
    u.quote_status,
    u.quote_type,
    u.refresh_quote_flag,
    u.start_date,
    u.subscription_term,
    u.submitted_date,
    u.system_modstamp,
    u.is_deleted
FROM unioned u
LEFT JOIN {{ ref('recordtype') }} rt
    ON u.record_type_id = rt.recordtype_id   -- was rt.record_type_id

/*
LEFT JOIN {{ ref('int_opportunity_synced_quote') }} pq
    ON u.opportunity_id = pq.opportunity_id
*/