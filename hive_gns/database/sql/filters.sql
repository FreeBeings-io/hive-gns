CREATE OR REPLACE FUNCTION gns.check_op_filter(_op_id SMALLINT, _body JSON, _filter VARCHAR)
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
            -- if acc is null, raise exception
            IF _acc IS NULL THEN
                RAISE EXCEPTION 'Account is null';
            END IF;
            -- check if user has enabled that module and notif code, from gns.accounts.prefs
            SELECT prefs INTO _prefs FROM gns.accounts WHERE account = _acc;
            IF _prefs IS NULL THEN
                RAISE NOTICE 'No prefs found: acc: %', _acc;
                RETURN false;
            END IF;
            _module_prefs := _prefs->'enabled'->_module;
            IF _module_prefs IS NULL THEN
                RAISE NOTICE 'No module_prefs: %', _acc;
                RETURN false;
            END IF;
            IF '*' = ANY(ARRAY(SELECT json_array_elements_text(_module_prefs))) THEN
                RETURN true;
            END IF;
            IF _notif_code = ANY(ARRAY(SELECT json_array_elements_text(_module_prefs))) THEN
                RETURN true;
            END IF;
            RAISE NOTICE 'No prefs match: %', _acc;
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