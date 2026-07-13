{{ config(
    materialized = 'table',
    tags = ['gold', 'dimension', 'salesforce']
) }}

------------------------------------------------------------------------------
-- Gold dimension: dim_product
------------------------------------------------------------------------------

with subscription_model as (
    select
        psmo.product2_id,
        max(psm.name) as product_selling_model_name
    from {{ ref('productsellingmodel') }} psm
    inner join {{ ref('productsellingmodeloption') }} psmo
        on psm.productsellingmodel_id = psmo.product_selling_model_id
    where  psm.is_deleted = FALSE
      and  psmo.is_deleted = FALSE
    group by psmo.product2_id
)

select

    p.product2_id as product2_id,
    p.base_sku,
    p.bloxone_tier,
    p.card_connectivity,
    p.created_by_id,
    p.created_date,
    p.currency_iso_code,
    p.deferred_commission_cogs_account,
    p.deferred_material_cogs_account,
    p.deferred_payroll_and_other_cogs_account,
    p.deferred_product_cogs_account,
    p.deferred_revenue_account,
    p.deferred_royalty_cogs_account,
    p.description,
    p.discount_category,
    p.dossier_included,
    p.end_customer_type,
    p.eol,
    p.eosl,
    p.evaluation_eligible,
    p.exclude_from_maintenance_calculation,
    p.family,
    p.finance_product_category,
    p.from_gsw,
    p.generate_asset,
    p.gs_hw_sw_size,
    p.hw_sw_family,
    p.hw_sw_size,
    p.in_csp,
    p.ip_count,
    p.is_active,
    p.is_assetizable,
    p.is_legacy,
    p.last_modified_by_id,
    p.lic_ddi_license_features,
    p.lic_device_limit,
    p.lic_dhcp_limit,
    p.lic_grid_wide,
    p.lic_host_type,
    p.lic_hwul_limit,
    p.lic_license_technology,
    p.lic_load_bal_limit,
    p.lic_netmri_license_features,
    p.lic_nios_limit,
    p.lic_pool_lpc_eligible,
    p.lic_sam_limit,
    p.lic_target_host_type,
    p.lic_vnios_limit,
    p.lpm,
    p.maintenance_provider,
    p.maintenance_service_level,
    p.marketplace_eligible,
    p.mlta_dca_tier,
    p.mlta_load_bal_limit,
    p.mlta_number_of_dossier_queries,
    p.mlta_oc,
    p.mlta_reporting_limit,
    p.mlta_reporting_sub_limit,
    p.mlta_saas_number_of_devices,
    p.mlta_saas_number_of_users,
    p.mlta_sec_eco_limit,
    p.mlta_spm_license_limit,
    p.msp_spla_approved,
    p.name,
    p.percent_renewal_uplift,
    p.perpetual_or_subscription,
    p.physical_or_virtual,
    p.power_supply_unit,
    p.product_category,
    p.product_class,
    p.product_code,
    p.product_generation,
    p.product_group,
    p.product_id_18,
    p.product_line,
    p.product_sub_type,
    p.product_sub_type_ii,
    p.product_type,
    p.quantity_unit_of_measure,
    p.real_standalone_availability,
    p.recognized_material_cogs_account,
    p.renewal_uplift_eligible,
    p.revenue_product_category,
    p.royalty_amount_per_unit,
    p.royalty_cogs_account,
    p.royalty_of_extended_price,
    p.royalty_vendor_name,
    p.saas_number_of_dossier_queries,
    p.saas_service_level,
    p.sales_account_id,
    p.sbqq_billing_frequency,
    p.sbqq_block_pricing_field,
    p.sbqq_component,
    p.sbqq_custom_configuration_required,
    p.sbqq_default_quantity,
    p.sbqq_exclude_from_maintenance,
    p.sbqq_exclude_from_opportunity,
    p.sbqq_externally_configurable,
    p.sbqq_has_configuration_attributes,
    p.sbqq_hidden,
    p.sbqq_hide_price_in_search_results,
    p.sbqq_include_in_maintenance,
    p.sbqq_non_discountable,
    p.sbqq_non_partner_discountable,
    p.sbqq_optional,
    p.sbqq_price_editable,
    p.sbqq_pricing_method,
    p.sbqq_pricing_method_editable,
    p.sbqq_quantity_editable,
    p.sbqq_reconfiguration_disabled,
    p.sbqq_subscription_category,
    p.sbqq_subscription_percent,
    p.sbqq_subscription_pricing as subscription_pricing_model,
    p.sbqq_subscription_term,
    p.sbqq_subscription_type,
    p.sbqq_taxable,
    p.scoping_category,
    p.shipment_schedule_required,
    p.single_partner_sku,
    p.software_entitlement,
    p.standalone_availability,
    p.threat_insight_included,
    p.tokens_in_pack,
    p.token_based_sku,
    p.training_ratable,
    p.utilize_install_base_pricing,
    p.value_derived_from_sow,
    case
        when p.finance_product_category in (
            'Term Software', 'Maintenance', 'Subscription Feed',
            'SaaS', 'Term Software - Consumption', 'SaaS - Consumption'
        ) then TRUE
        else FALSE
    end as acv_eligible_flag,


    case
        when sm.product_selling_model_name = 'Subscription - Annual'
          or p.sbqq_subscription_pricing in ('Fixed Price', 'Percent Of Total') then true
        else false
    end as nacv_pricing_eligible_flag,

    sm.product_selling_model_name,

    case
        when p.product_group = 'DDI Val Add' then 'DDI Value-Add (DDI+)'
        else p.product_group
    end as product_group_name,

    --used for historical lineage
    case
        when lower(p.finance_product_category) = 'saas'
             and lower(p.product_group) in ('bloxone ddi', 'b1 platform') then 'B1DDI'
        when lower(p.finance_product_category) = 'saas'
             and lower(p.product_group) = 'security'
             and lower(p.family) in ('activetrust cloud', 'bloxone threat defense') then 'B1TD'
    end as saas_prod_group_old,

    case
        when lower(p.finance_product_category) = 'saas'
             and lower(p.product_group) in ('bloxone ddi', 'b1 platform') then 'B1DDI'
        when lower(p.family) in ('activetrust cloud', 'bloxone threat defense') then 'B1TD'
    end as saas_prod_group,

    case
        when p.product_group = 'BloxOne DDI' then 'B1DDI'
        when p.family = 'BloxOne Threat Defense' then 'B1TD'
        when p.product_group = 'DDI Val Add' then 'DDI Value-Add (DDI+)'
        else p.product_group
    end as blox_one_product_group,

    case
        when p.is_assetizable then 'Renewable'
        else 'One-time'
    end as subscription_type_desc,

    case
        when p.finance_product_category in (
            'Appliance Software', 'Hardware', 'Other', 'Add-on Software',
            'Professional Services', 'Trainings'
        ) then 'NRR'
        else 'ARR'
    end as revenue_category,

    case
        when p.finance_product_category in ('Add-on Software', 'Appliance Software') then 'Product SW'
        when p.finance_product_category = 'Freight' then 'Other'
        else p.finance_product_category
    end as finance_product_category_rollup,

    case
        when p.finance_product_category in (
            'Add-on Software', 'Appliance Software', 'Freight', 'Hardware', 'Other'
        ) then 'Product'
        else p.finance_product_category
    end as finance_product_category_summary,

    case
        when p.family like '%BloxOne Threat Defense%'
          or p.family like '%Threat Defense%' then 'Threat Defense'
        else 'Other'
    end as product_group_new,

    '{{ var("product_logic_version", "product_conform_v1") }}' as model_logic_version,
    {{ dbt_utils.generate_surrogate_key(['p.product2_id']) }} as product_sk,
    p.last_modified_date,
    p.system_modstamp,
    p.is_deleted

from {{ ref('product2') }} p
left join subscription_model sm
    on p.product2_id = sm.product2_id
where p.is_current = true
  and p.is_deleted = false