-- validate user preferences payloads
CREATE OR REPLACE FUNCTION gns.validate_prefs_payload( _payload JSON )
    RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            _payload := _data::jsonb;
            -- validate structure
            IF _payload IS NULL THEN
                RAISE NOTICE 'payload is null';
                RETURN false;
            END IF;
            RAISE NOTICE 'payload is good json';
            -- main payload must be in array
            IF NOT jsonb_path_exists(_payload, '$[*]') THEN
                RAISE NOTICE 'main payload is not array';
                RETURN false;
            END IF;
            RAISE NOTICE 'main payload is array, good';

            -- check if op_header is correct
            --_op_header := jsonb_path_query(_payload, '$[0]');
            IF jsonb_path_exists(_payload, '$[0][*]') = false THEN
                RAISE NOTICE 'op_header is not array';
                RETURN false;
            END IF;
            -- check if array above is length 2
            IF jsonb_array_length(_payload->0) != 2 THEN
                RAISE NOTICE 'op_header is not length 2';
                RETURN false;
            END IF;

            -- check if op_header[0] is integer
            IF jsonb_typeof(_payload->0->0) != 'number' THEN
                RAISE NOTICE 'op_header[0] is not number, it is %', jsonb_typeof(_payload->0->0);
                RETURN false;
            END IF;
            -- check if op_header[1] is string
            IF jsonb_typeof(_payload->0->1) != 'string' THEN
                RAISE NOTICE 'op_header[1] is not string, it is %', jsonb_typeof(_payload->0->1);
                RETURN false;
            END IF;

            -- is op_name valid string?
            IF jsonb_typeof(_payload->1) != 'string' THEN
                RAISE NOTICE 'op_name is not string, it is %', jsonb_typeof(_payload->1);
                RETURN false;
            END IF;

            -- check if 3rd element is object _payload->2
            IF jsonb_typeof(_payload->2) != 'object' THEN
                RAISE NOTICE 'sub_payload is neither object or array, it is %', jsonb_typeof(_payload->2);
                RETURN false;
            END IF;
            RAISE NOTICE 'whole operation is valid, payload is %', _payload;
            RETURN true;
        EXCEPTION WHEN SQLSTATE '22P02' THEN
            -- invalid JSONB input
            RAISE NOTICE 'invalid JSONB input';
            RETURN false;
        END;
    $function$;

-- validate user preferecences
CREATE OR REPLACE FUNCTION gns.validate_prefs(_payload JSON)
    RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _valid_entry BOOLEAN;
            _valid_notif_pref BOOLEAN;
            _module VARCHAR;
            _notif_code VARCHAR;
        BEGIN
            -- check if each module, notif code is a valid module name in db
            FOR _module IN SELECT jsonb_object_keys LOOP
                FOR _notif_code IN SELECT jsonb_object_keys(_payload->>_module) LOOP
                    _valid_entry := (SELECT EXISTS (SELECT * FROM gns.module_hooks WHERE module = _module AND notif_code = _notif_code));
                    IF _valid_entry = false THEN
                        RAISE NOTICE 'module % notif_code % is not valid', _module, _notif_code;
                        RETURN false;
                    ELSE
                        _valid_notif_pref := gns.validate_notif_prefs(_module, _notif_code, _payload);
                        IF _valid_notif_pref = false THEN
                            RETURN false;
                        END IF;
                    END IF;
                END LOOP;
            END LOOP;
            RETURN true;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.validate_notif_prefs(_module VARCHAR, _notif_code VARCHAR, _payload JSON)
    RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _prefs_validation JSON;
            _key VARCHAR;
            _path VARCHAR;
        BEGIN
            -- for each key in _payload check if it is in _prefs_validation
            FOR _key IN SELECT jsonb_object_keys(_payload) LOOP
                IF NOT jsonb_path_exists(_prefs_validation, '$.' || _key) THEN
                    RAISE NOTICE 'key % is not in prefs_validation', _key;
                    RETURN false;
                ELSE
                    _path := '$.' || _key || '?(@.type() == "' || _prefs_validation->>_key::jsonpath || '"';
                    IF jsonb_path_exists(_payload, _path) = false THEN
                        RAISE NOTICE 'path % does not exist', _path;
                        RETURN false;
                    END IF;
                END IF;
            END LOOP;
        RETURN true;
        END;
    $function$;
