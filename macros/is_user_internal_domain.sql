{% macro is_user_internal_domain(email_column) %}
    --------------------------------------------------------------
    -- Macro: is_user_internal_domain
    -- Returns TRUE when the email address belongs to an Infoblox
    -- internal domain (@infoblox.com). Used in dim_user to flag
    -- employees vs. external / partner users.
    -- Centralised here so the same rule is enforceable everywhere
    -- without copy-paste drift.
    --------------------------------------------------------------
    LOWER(SPLIT_PART({{ email_column }}, '@', 2)) = 'infoblox.com'
{% endmacro %}
