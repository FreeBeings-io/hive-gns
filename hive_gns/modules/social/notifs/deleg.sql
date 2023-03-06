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
            _sub := gns.check_user_filter(_delegatee, 'social', _notif_code);

            IF _sub = true THEN

                IF _amount > 0 THEN
                    _remark := FORMAT('%s is now delegating %s VESTS to you', _delegator, _vests);
                ELSE
                    _remark := FORMAT('%s removed their vesting delegation', _delegator);
                END IF;
                _link := FORMAT('https://hive.blog/@%s', _delegator);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _delegatee, 'social', _notif_code, _created, _remark, _body, true, _link);
            END IF;

            -- RAISE NOTICE 'value: % \n', _value;

        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;