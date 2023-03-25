CREATE OR REPLACE FUNCTION gns.core_gns( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _acc VARCHAR(16);
            _op_id VARCHAR;
            _payload JSONB;
            _op_header JSONB;
            _op_name VARCHAR;
            _data JSONB;
            _final_data JSONB;
        BEGIN
            _op_id := _body->'value'->>'id';
            IF _op_id = 'gns' THEN
                _req_auths := ARRAY(SELECT jsonb_array_elements_text((_body->'value'->'required_posting_auths')));
                _acc := _req_auths[1];
                _payload := _body->'value'->>'json';
                -- validate gns payload
                IF gns.validate_gns_payload(_payload) = false THEN
                    RETURN;
                END IF;

                _op_header := _payload->>0;
                _op_name := _payload->>1;
                _data := (_payload->>2)::jsonb;
                
                -- update preferences
                IF _op_name = 'enabled' THEN
                    IF _data IS NOT NULL THEN
                        -- check acount
                        PERFORM gns.check_account(_acc);
                        -- replace all module entries that contain * with the actual list of notif_codes
                        _final_data := _data;
                        FOR _module IN SELECT jsonb_object_keys(_data) LOOP
                            FOR _notif_code IN SELECT jsonb_array_elements_text(_data->_module) LOOP
                                IF '*' = ANY (ARRAY(SELECT jsonb_array_elements_text(_data->_module))) THEN
                                    _final_data := _final_data || jsonb_build_object(_module, (SELECT jsonb_agg(notif_code) FROM gns.module_hooks WHERE module = _module));
                                END IF;
                            END LOOP;
                        END LOOP;

                        -- validate prefs payload
                        IF gns.validate_prefs_enabled(_final_data) = false THEN
                            RETURN;
                        END IF;
                        
                        -- update account's prefs and set prefs_updated
                        UPDATE gns.accounts SET prefs = _final_data, prefs_updated = _created WHERE account = _acc;
                    END IF;
                
                -- if op_name = 'notifs', then check and validate then process
                ELSIF _op_name = 'options' THEN
                    IF _data IS NOT NULL THEN
                        -- check acount
                        PERFORM gns.check_account(_acc);
                        -- validate notifs payload
                        RAISE NOTICE 'validating notifs payload';
                        IF gns.validate_prefs_options(_data) = false THEN
                            RAISE NOTICE 'notifs payload is invalid';
                            RETURN;
                        END IF;
                        -- update account's notifs and set notifs_updated
                        UPDATE gns.accounts SET options = _data, options_updated = _created WHERE account = _acc;
                    END IF;
                END IF;
            END IF;
        
        END;
        $function$;