CREATE OR REPLACE FUNCTION gns.core_transfer( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _from VARCHAR(16);
            _to VARCHAR(16);
            _nai VARCHAR(11);
            _amount DOUBLE PRECISION;
            _memo VARCHAR(2048);
            _currency VARCHAR(4);
            _remark VARCHAR(500);
            _read TIMESTAMP;
            _read_json JSON;
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            -- transfer_operation
            _from := _body->'value'->>'from';
            _to := _body->'value'->>'to';
            _nai := (_body->'value'->>'amount')::json->>'nai';
            _memo := _body->'value'->>'memo';

            -- TODO: user prefs filtering

            IF _nai = '@@000000013' THEN
                _currency := 'HBD';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000;
            ELSIF _nai = '@@000000021' THEN
                _currency := 'HIVE';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000;
            ELSIF _nai = '@@000000037' THEN
                _currency := 'HP';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000000;
            END IF;

            -- check if subscribed
            _sub := gns.check_user_filter(_to, 'core', _notif_code);

            IF _sub = true THEN

                _remark := FORMAT('you have received %s %s from %s', _amount, _currency, _from);
                _link := FORMAT('https://hive.blog/@%s', _from);

                -- check acount
                INSERT INTO gns.accounts (account)
                SELECT _to
                WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _to);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _to, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;

        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_gns( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
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
                        INSERT INTO gns.accounts (account)
                        SELECT _acc
                        WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _acc);
                        -- update account's prefs and set prefs_updated
                        UPDATE gns.accounts SET prefs = _data, prefs_updated = _created WHERE account = _acc;
                    END IF;
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %', SQLSTATE, SQLERRM;
        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_vote( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _voter VARCHAR(16);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _pending_payout JSON;
            _value NUMERIC(10,2);
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

            _weight BIGINT;
            _tot_weight BIGINT;
            _amount BIGINT;
        BEGIN
            _voter := _body->'value'->>'voter';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';
            --_pending_payout := _body->'value'->'pending_payout';

            _weight := _body->'value'->>'weight';
            -- RAISE NOTICE 'weight: %', _weight;
            _tot_weight := _body->'value'->>'total_vote_weight';
            -- RAISE NOTICE 'tot_weight: %', _tot_weight;
            _amount := _body->'value'->'pending_payout'->>'amount';
            -- RAISE NOTICE 'amount: %', _amount;

            IF _weight = 0 OR _tot_weight = 0 OR _amount = 0 THEN
                _value = 0;
            ELSE
                _value := (( _weight::float / _tot_weight::float) * _amount::float)::float / 1000;
            END IF;
            -- RAISE NOTICE 'value: % \n', _value;

            -- check acount
            INSERT INTO gns.accounts (account)
            SELECT _author
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _author);

            -- check if subscribed
            _sub := gns.check_user_filter(_author, 'core', _notif_code);

            IF _sub = true AND _value > 0.01 THEN

                _remark := FORMAT('%s voted on your post ($%s)', _voter, _value);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _author, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_comment( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _parent_author VARCHAR(16);
            _parent_permlink VARCHAR(500);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _title VARCHAR;
            --_json_metadata
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _parent_author := _body->'value'->>'parent_author';
            _parent_permlink := _body->'value'->>'parent_permlink';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';

            IF length(_parent_author) > 0 AND length(_parent_permlink) > 0 THEN
                -- check parent_author acount
                INSERT INTO gns.accounts (account)
                SELECT _parent_author
                WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _parent_author);
                -- check author acount
                INSERT INTO gns.accounts (account)
                SELECT _author
                WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _author);

                -- check if subscribed
                _sub := gns.check_user_filter(_parent_author, 'core', _notif_code);

                IF _sub = true THEN

                    _remark := FORMAT('%s commented on your post', _parent_author);
                    _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                    -- make notification entry
                    INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                    VALUES (_gns_op_id, _trx_id, _author, 'core', _notif_code, _created, _remark, _body, true, _link);
                END IF;
            END IF;

            -- RAISE NOTICE 'value: % \n', _value;

        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_deleg( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _delegator VARCHAR(16);
            _delegatee VARCHAR(16);
            _amount BIGINT;
            _vests NUMERIC;
            --_json_metadata
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _delegator := _body->'value'->>'delegator';
            _delegatee := _body->'value'->>'delegatee';
            _amount := _body->'value'->'vesting_shares'->>'amount';
            _vests := round((_amount::numeric)/1000000, 6);

            INSERT INTO gns.accounts (account)
            SELECT _delegatee
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _delegatee);

            -- check if subscribed
            _sub := gns.check_user_filter(_delegatee, 'core', _notif_code);

            IF _sub = true THEN

                IF _amount > 0 THEN
                    _remark := FORMAT('%s is now delegating %s VESTS to you', _delegator, _vests);
                ELSE
                    _remark := FORMAT('%s removed their vesting delegation', _delegator);
                END IF;
                _link := FORMAT('https://hive.blog/@%s', _delegator);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _delegatee, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;

            -- RAISE NOTICE 'value: % \n', _value;

        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_mention( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _parent_author VARCHAR(16);
            _parent_permlink VARCHAR(500);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _post_body TEXT;
            _type VARCHAR(10);

            _username VARCHAR(16)[];
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _parent_author := _body->'value'->>'parent_author';
            _parent_permlink := _body->'value'->>'parent_permlink';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';
            _post_body := _body->'value'->>'body';

            IF length(_parent_author) > 0 AND length(_parent_permlink) > 0 THEN
                -- this is a post mention
                _type := 'post';
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);
            ELSE
                -- this is a comment mention
                _type := 'comment';
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);
            END IF;

            -- check if body contains @username of max 16 characters
            -- using regex letters, numbers and dash
            -- extract username (without the @ character) from body if found then
                -- check user account
                -- check if subscribed
                -- make notification entry, for each username found
            FOR _username IN SELECT regexp_matches(_post_body, '@([a-zA-Z0-9-]{1,16})', 'g') LOOP
                -- check user account
                INSERT INTO gns.accounts (account)
                SELECT _username[1]
                WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _username[1]);

                -- check if subscribed
                _sub := gns.check_user_filter(_username[1], 'core', _notif_code);

                IF _sub = true THEN

                    _remark := FORMAT('%s mentioned you in a %s', _author, _type);

                    -- make notification entry
                    INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                    VALUES (_gns_op_id, _trx_id, _username[1], 'core', _notif_code, _created, _remark, _body, true, _link);
                END IF;
            END LOOP;

        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %
                USERNAME: %', SQLSTATE, SQLERRM, _body, _username;
        END;
        $function$;