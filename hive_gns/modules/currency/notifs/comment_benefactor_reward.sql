CREATE OR REPLACE FUNCTION gns.core_comment_benefactor_reward( _trx_id BYTEA, _created TIMESTAMP, _body JSON, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _benefactor VARCHAR(16);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _hbd_payout DOUBLE PRECISION;
            _hive_payout DOUBLE PRECISION;
            _vesting_payout DOUBLE PRECISION;
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            _benefactor := _body->'value'->>'benefactor';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';
            -- check benefactor acount
            PERFORM gns.check_account(_benefactor);
            -- check if subscribed
            _sub := gns.check_user_filter(_benefactor, _module, _notif_code);
            IF _sub = true THEN
                -- calculate HBD, HIVE and VESTS values
                _hbd_payout := ((_body->'value'->>'hbd_payout')::json->>'amount')::float / 1000;
                _hive_payout := ((_body->'value'->>'hive_payout')::json->>'amount')::float / 1000;
                _vesting_payout := ((_body->'value'->>'vesting_payout')::json->>'amount')::float / 1000000;
                _remark := FORMAT('You received a benefactor reward from %s: %s HBD, %s HIVE, %s VESTS', _author, _hbd_payout, _hive_payout, _vesting_payout);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);
                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _benefactor, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;
        END;
        $function$;