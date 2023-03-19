CREATE OR REPLACE FUNCTION gns.core_gns( _trx_id BYTEA, _created TIMESTAMP, _body JSON, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _acc VARCHAR(16);
            _op_id VARCHAR;
            _payload JSON;
            _op_name VARCHAR;
            _data JSON;
        BEGIN
            _op_id := _body->'value'->>'id';
            IF _op_id = 'gns' THEN
                _req_auths := ARRAY(SELECT json_array_elements_text((_body->'value'->'required_posting_auths')));
                _acc := _req_auths[1];
                _payload := _body->'value'->>'json';
                _op_name := _payload->>0;
                _data := (_payload->>1)::json;
                -- update preferences
                IF _op_name = 'prefs' THEN
                    IF _data IS NOT NULL THEN
                        -- check acount
                        PERFORM gns.check_account(_acc);
                        -- validate prefs payload
                        RAISE NOTICE 'validating prefs payload';
                        IF gns.validate_prefs(_data) = false THEN
                            RAISE NOTICE 'prefs payload is invalid';
                            RETURN;
                        END IF;
                        -- update account's prefs and set prefs_updated
                        UPDATE gns.accounts SET prefs = _data, prefs_updated = _created WHERE account = _acc;
                    END IF;
                END IF;
            END IF;
        
        END;
        $function$;