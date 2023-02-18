-- function to handle notifications for curation rewards, checks accounts, checks subscriptions and inserts notification
CREATE OR REPLACE FUNCTION gns.core_curation_reward( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _curator VARCHAR(16);
            _reward DOUBLE PRECISION;
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            _curator := _body->'value'->>'curator';
            -- check curator acount
            INSERT INTO gns.accounts (account)
            SELECT _curator
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _curator);
            -- check if subscribed
            _sub := gns.check_user_filter(_curator, 'core', _notif_code);
            IF _sub = true THEN
                _reward := ((_body->'value'->>'reward')::json->>'amount')::float / 1000000;
                _remark := FORMAT('You received a curation reward of %s VESTS', _reward);
                _link := FORMAT('https://hive.blog/@%s/%s', _body->'value'->>'comment_author', _body->'value'->>'comment_permlink');
                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _curator, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE E'Got exception:
            SQLSTATE: % 
            SQLERRM: %
            DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;