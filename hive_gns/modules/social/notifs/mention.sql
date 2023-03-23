CREATE OR REPLACE FUNCTION gns.core_mention( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
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
                -- this is a comment mention
                _type := 'comment';
                _link := FORMAT('https://hive.blog/@%s/%s#@%s/%s', _parent_author, _parent_permlink, _author, _permlink);
            ELSE
                -- this is a post mention
                _type := 'post';
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);
            END IF;

            FOR _username IN SELECT DISTINCT regexp_matches(_post_body, '@([a-zA-Z0-9-]{1,16})', 'g') LOOP
                IF _username[1] = _author THEN
                    -- skip if username is the same as the author
                    CONTINUE;
                END IF;
                -- check user account
                PERFORM gns.check_account(_username[1]);

                -- check if subscribed
                _sub := gns.check_user_filter(_username[1], _module, _notif_code);

                IF _sub = true THEN

                    _remark := FORMAT('%s mentioned you in a %s', _author, _type);

                    -- make notification entry
                    PERFORM gns.save_notif(_trx_id, _username[1], _module, _notif_code, _created, _remark, _body, _link, true);
                END IF;
            END LOOP;

        END;
        $function$;