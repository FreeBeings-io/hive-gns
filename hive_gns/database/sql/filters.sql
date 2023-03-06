CREATE OR REPLACE FUNCTION gns.check_op_filter(_op_id INT, _body JSON, _filter JSON)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN true;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.check_user_filter(_acc VARCHAR(16), _module VARCHAR(64), _notif_code VARCHAR(3))
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _prefs JSON;
            _module_prefs JSON;
        BEGIN
            -- check if user has enabled that module and notif code, from gns.accounts.prefs
            SELECT prefs INTO _prefs FROM gns.accounts WHERE account = _acc;
            RAISE NOTICE 'prefs: %', _prefs;
            IF _prefs IS NULL THEN
                RETURN false;
            END IF;
            _module_prefs := _prefs->'enabled'->_module;
            RAISE NOTICE 'module_prefs: %', _module_prefs;
            IF _module_prefs IS NULL THEN
                RETURN false;
            END IF;
            IF '*' = ANY(ARRAY(SELECT json_array_elements_text(_module_prefs))) THEN
                RETURN true;
            END IF;
            IF _notif_code = ANY(ARRAY(SELECT json_array_elements_text(_module_prefs))) THEN
                RETURN true;
            END IF;
            RETURN false;
        END;
    $function$;


-- OP FILTERS

CREATE OR REPLACE FUNCTION gns.filter_custom_json_operation(_filter JSON)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN true;
        END;
    $function$;