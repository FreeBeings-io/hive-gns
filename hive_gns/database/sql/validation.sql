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

            -- check if 3rd element is either object or array _payload->2
            IF jsonb_typeof(_payload->2) != 'object' AND jsonb_typeof(_payload->2) != 'array' THEN
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