-- notification for when rewards are paid to an author
CREATE OR REPLACE FUNCTION gns.core_author_reward( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _title VARCHAR;
            _hbd_payout DOUBLE PRECISION;
            _hive_payout DOUBLE PRECISION;
            _vesting_payout DOUBLE PRECISION;

            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';

            -- check author acount
            INSERT INTO gns.accounts (account)
            SELECT _author
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _author);

            -- check if subscribed
            _sub := gns.check_user_filter(_author, 'core', _notif_code);

            IF _sub = true THEN

                -- calculate HBD, HIVE and VESTS values
                _hbd_payout := ((_body->'value'->>'hbd_payout')::json->>'amount')::float / 1000;
                _hive_payout := ((_body->'value'->>'hive_payout')::json->>'amount')::float / 1000;
                _vesting_payout := ((_body->'value'->>'vesting_payout')::json->>'amount')::float / 1000000;

                _remark := FORMAT('You received a reward for your post. %s HBD, %s HIVE, %s HP', _hbd_payout, _hive_payout, _vesting_payout);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _author, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;

            -- RAISE NOTICE 'value: % \n', _value;

        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;