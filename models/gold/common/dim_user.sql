{{ config(
    materialized = 'table',
    schema       = 'sales'
) }}

-- ============================================================
-- MODEL: dim_user
-- Grain: one row per user
-- ============================================================

WITH base_user AS (
    SELECT
        u.user_id,
        NULLIF(TRIM(u.territory), '')      AS assigned_territory,
        NULLIF(TRIM(u.company_name), '')   AS company_name,
        NULLIF(TRIM(u.created_by_id), '')  AS created_by_id,
        u.created_date,
        NULLIF(TRIM(u.department), '')     AS department,
        NULLIF(TRIM(u.email), '')          AS email,
        INITCAP(LOWER(NULLIF(TRIM(u.first_name), ''))) AS first_name,
        u.geo,
        u.region,
        u.is_active,
        -- is_infoblox_employee domain rule lifted into a macro so the
        -- same logic is enforceable anywhere it's needed, not re-written.
        {{ is_internal_domain('u.email') }} AS is_infoblox_employee,
        u.last_modified_date,
        INITCAP(LOWER(NULLIF(TRIM(u.last_name), ''))) AS last_name,
        NULLIF(TRIM(u.manager_id), '')     AS manager_id,
        NULLIF(TRIM(u.profile_id), '')     AS profile_id,
        u.role_start_date,
        u.system_modstamp,
        NULLIF(TRIM(u.title), '')          AS title,
        CASE
            WHEN NULLIF(TRIM(u.first_name), '') IS NOT NULL
             AND NULLIF(TRIM(u.last_name), '') IS NOT NULL
            THEN CONCAT(
                     INITCAP(LOWER(NULLIF(TRIM(u.first_name), ''))), ' ',
                     INITCAP(LOWER(NULLIF(TRIM(u.last_name), '')))
                 )
            ELSE INITCAP(LOWER(NULLIF(TRIM(u.name), '')))
        END AS user_name,
        NULLIF(TRIM(u.user_role_id), '')   AS user_role_id,
        NULLIF(TRIM(u.user_type), '')      AS user_type,
        NULLIF(TRIM(u.username), '')       AS login_username,
        NULLIF(TRIM(u.vp_sales), '')       AS vp_sales_id
    FROM {{ ref('user') }} u
    WHERE u.is_current = TRUE
),

role_lkp AS (
    SELECT
        r.userrole_id AS user_role_id,
        NULLIF(TRIM(r.name), '') AS user_role_name
    FROM {{ ref('userrole') }} r
    WHERE r.is_current = TRUE
),

profile_lkp AS (
    SELECT
        p.profile_id,
        NULLIF(TRIM(p.name), '') AS profile_name
    FROM {{ ref('profile') }} p
    WHERE p.is_current = TRUE
),

manager_flag AS (
    SELECT DISTINCT
        manager_id AS user_id,
        TRUE AS is_manager_flag
    FROM base_user
    WHERE manager_id IS NOT NULL
)

SELECT
    bu.user_id,
    bu.assigned_territory,
    bu.company_name,
    bu.created_by_id,
    bu.created_date,
    bu.department,
    m1.user_name AS direct_manager_name,
    m1.title     AS direct_manager_title,
    bu.email,
    bu.first_name,
    bu.geo,
    CASE WHEN bu.manager_id IS NOT NULL THEN TRUE ELSE FALSE END AS has_manager_flag,
    CASE WHEN bu.vp_sales_id IS NOT NULL THEN TRUE ELSE FALSE END AS has_vp_sales_flag,
    bu.is_active,
    bu.is_infoblox_employee,
    COALESCE(mf.is_manager_flag, FALSE) AS is_manager_flag,
    bu.last_name,
    bu.login_username,
    CASE
        WHEN m7.user_id IS NOT NULL THEN 7
        WHEN m6.user_id IS NOT NULL THEN 6
        WHEN m5.user_id IS NOT NULL THEN 5
        WHEN m4.user_id IS NOT NULL THEN 4
        WHEN m3.user_id IS NOT NULL THEN 3
        WHEN m2.user_id IS NOT NULL THEN 2
        WHEN m1.user_id IS NOT NULL THEN 1
        ELSE 0
    END AS manager_chain_depth,
    bu.manager_id,
    m1.user_name AS manager_level_1_name,
    m1.title     AS manager_level_1_title,
    m1.user_id   AS manager_level_1_user_id,
    m2.user_name AS manager_level_2_name,
    m2.title     AS manager_level_2_title,
    m2.user_id   AS manager_level_2_user_id,
    m3.user_name AS manager_level_3_name,
    m3.title     AS manager_level_3_title,
    m3.user_id   AS manager_level_3_user_id,
    m4.user_name AS manager_level_4_name,
    m4.title     AS manager_level_4_title,
    m4.user_id   AS manager_level_4_user_id,
    m5.user_name AS manager_level_5_name,
    m5.title     AS manager_level_5_title,
    m5.user_id   AS manager_level_5_user_id,
    m6.user_name AS manager_level_6_name,
    m6.title     AS manager_level_6_title,
    m6.user_id   AS manager_level_6_user_id,
    m7.user_name AS manager_level_7_name,
    m7.title     AS manager_level_7_title,
    m7.user_id   AS manager_level_7_user_id,
    bu.profile_id,
    pl.profile_name,
    bu.region,
    bu.role_start_date,
    bu.title,
    COALESCE(m7.user_name, m6.user_name, m5.user_name, m4.user_name,
             m3.user_name, m2.user_name, m1.user_name) AS top_manager_name,
    COALESCE(m7.title, m6.title, m5.title, m4.title,
             m3.title, m2.title, m1.title)             AS top_manager_title,
    bu.user_name,
    bu.user_role_id,
    rl.user_role_name,
    bu.user_type,
    bu.vp_sales_id,
    vps.user_name AS vp_sales_name,
    vps.title     AS vp_sales_title,
    bu.last_modified_date,
    bu.system_modstamp,
    CURRENT_TIMESTAMP AS edp_updated_at

FROM base_user bu
LEFT JOIN role_lkp rl     ON bu.user_role_id = rl.user_role_id
LEFT JOIN profile_lkp pl  ON bu.profile_id = pl.profile_id
LEFT JOIN base_user vps   ON bu.vp_sales_id = vps.user_id
LEFT JOIN manager_flag mf ON bu.user_id = mf.user_id
LEFT JOIN base_user m1    ON bu.manager_id = m1.user_id
LEFT JOIN base_user m2    ON m1.manager_id = m2.user_id
LEFT JOIN base_user m3    ON m2.manager_id = m3.user_id
LEFT JOIN base_user m4    ON m3.manager_id = m4.user_id
LEFT JOIN base_user m5    ON m4.manager_id = m5.user_id
LEFT JOIN base_user m6    ON m5.manager_id = m6.user_id
LEFT JOIN base_user m7    ON m6.manager_id = m7.user_id
