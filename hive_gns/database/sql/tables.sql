CREATE TABLE IF NOT EXISTS gns.global_props(
    latest_block_num INTEGER,
    check_in TIMESTAMP,
    state_preloaded BOOLEAN DEFAULT false,
    sync_enabled BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS gns.ops(
    id BIGSERIAL PRIMARY KEY,
    op_type_id SMALLINT NOT NULL,
    block_num INTEGER NOT NULL,
    created TIMESTAMP,
    transaction_id BYTEA,
    body JSON
);

CREATE TABLE IF NOT EXISTS gns.module_state(
    module VARCHAR(64) PRIMARY KEY,
    latest_gns_op_id BIGINT DEFAULT 0,
    latest_block_num BIGINT DEFAULT 0,
    check_in TIMESTAMP,
    enabled BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS gns.module_hooks(
    module VARCHAR(64) NOT NULL REFERENCES gns.module_state(module),
    notif_name VARCHAR(128) NOT NULL,
    notif_code VARCHAR(3) NOT NULL,
    funct VARCHAR(128) NOT NULL,
    op_id SMALLINT NOT NULL,
    notif_filter JSON NOT NULL
);

CREATE TABLE IF NOT EXISTS gns.accounts(
    account VARCHAR(16) PRIMARY KEY,
    last_reads JSON DEFAULT FORMAT('{"all": "%s"}', timezone('UTC', now()) - '30 days'::interval)::json,
    prefs JSON DEFAULT '{}'::json,
    prefs_updated TIMESTAMP,
    prefs_flag BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS gns.account_notifs(
    id BIGSERIAL PRIMARY KEY,
    gns_op_id BIGINT NOT NULL REFERENCES gns.ops(id) ON DELETE CASCADE DEFERRABLE,
    trx_id BYTEA,
    account VARCHAR(16) NOT NULL REFERENCES gns.accounts(account) ON DELETE CASCADE DEFERRABLE,
    module_name VARCHAR(64) NOT NULL,
    notif_code VARCHAR(3) NOT NULL,
    created TIMESTAMP NOT NULL,
    remark VARCHAR(500) NOT NULL,
    payload JSON NOT NULL,
    verified BOOLEAN DEFAULT NULL
);