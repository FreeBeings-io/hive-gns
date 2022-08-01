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
        BEGIN
            RETURN true;
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