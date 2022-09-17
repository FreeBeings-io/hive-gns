from hive_gns.config import Config
from hive_gns.database.access import db

GNS_OPS_FIELDS = ['gns_op_id', 'op_type_id', 'block_num', 'created', 'transaction_id', 'body']
GNS_GLOBAL_PROPS_FIELDS = [
    'latest_block_num', 'check_in',
    'sync_enabled', 'state_preloaded'
]
GNS_MODULE_STATE_FIELDS = [
    'latest_gns_op_id', 'latest_block_num',
    'check_in', 'enabled'
]

config = Config.config

class GnsOps:

    @classmethod
    def get_ops_in_range(cls, op_type_ids, lower, upper):
        fields = ", ".join(GNS_OPS_FIELDS)
        _str_ids = [str(opid) for opid in op_type_ids]
        _op_type_ids = " OR op_type_id = ".join(_str_ids)
        sql = f"""
            SELECT {fields} FROM gns.ops
            WHERE op_type_id = {_op_type_ids}
                AND gns_op_id >= {lower}
                AND gns_op_id <= {upper}
            ORDER BY gns_op_id ASC;
        """.replace("gns.", f"gns.")
        res = db.select(sql, GNS_OPS_FIELDS)
        return res

class GnsStatus:
    
    @classmethod
    def get_global_latest_state(cls):
        fields = ", ".join(GNS_GLOBAL_PROPS_FIELDS)
        sql = f"""
            SELECT {fields} FROM gns.global_props;
        """.replace("gns.", f"gns.")
        res = db.select(sql, GNS_GLOBAL_PROPS_FIELDS)
        return res[0]


    @classmethod
    def get_global_latest_gns_op_id(cls):
        state = cls.get_global_latest_state()
        return state['latest_gns_op_id']
    
    @classmethod
    def get_module_list(cls):
        _res = []
        sql = f"""
            SELECT module FROM gns.module_state;
        """.replace("gns.", f"gns.")
        res = db.select(sql, ['module'])
        for entry in res:
            _res.append(entry['module'])
        return _res

    @classmethod
    def get_module_latest_state(cls, module):
        fields = ", ".join(GNS_MODULE_STATE_FIELDS)
        sql = f"""
            SELECT {fields} FROM gns.module_state
            WHERE module = '{module}';
        """.replace("gns.", f"gns.")
        res = db.select(sql, GNS_MODULE_STATE_FIELDS)
        return res[0]

    @classmethod
    def get_module_latest_gns_op_id(cls, module):
        state = cls.get_module_latest_state(module)
        return state['latest_gns_op_id']
    
    @classmethod
    def set_module_state(cls, module, latest_gns_op_id):
        sql = f"""
            UPDATE gns.module_state
            SET latest_gns_op_id = {latest_gns_op_id}
            WHERE module = '{module}';
        """.replace("gns.", f"gns.")
        done = db.write(sql)
        if done == False:
            print(f"Failed to update state for '{module}' module. {latest_gns_op_id}")  #TODO: send to logging module
