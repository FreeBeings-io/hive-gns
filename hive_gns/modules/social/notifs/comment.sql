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
                _sub := gns.check_user_filter(_parent_author, 'social', _notif_code);

                IF _sub = true THEN

                    _remark := FORMAT('%s commented on your post', _parent_author);
                    _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                    -- make notification entry
                    INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                    VALUES (_gns_op_id, _trx_id, _author, 'social', _notif_code, _created, _remark, _body, true, _link);
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