from hive_gns.database.core import DbSession
from hive_gns.tools import populate_by_schema, normalize_types


class DbAccess:

    _write_db = DbSession('write_db')
    _read_db = DbSession('read_db')

    def __init__(self) -> None:
        print('DB access session created.')
        pass

    def select(self, sql:str, schema:list, one:bool = False):
        _res = self._read_db.do('select', sql)
        res = []
        if _res:
            assert len(schema) == len(_res[0]), 'invalid schema'
            for x in _res:
                res.append(populate_by_schema(x,schema))
            if one:
                return normalize_types(res)[0]
            else:
                return normalize_types(res)

    def write(self, sql:str):
        try:
            self._write_db.do('execute', sql)
            self._write_db.do('commit')
            return True
        except:
            return False

    def perform(self, func:str, params:list):
        #for p in params:
            #assert isinstance(p, str), 'function params must be strings'
        string_params = ["%s" for p in params]
        parameters = ", ".join(string_params)
        try:
            self._write_db.do('execute', f"SELECT {func}( {parameters} );", params)
            self._write_db.do('commit')
            return True
        except:
            return False

    def delete(self, sql:str):
        try:
            self._write_db.do('execute', sql)
            self._write_db.do('commit')
            return True
        except:
            return False

    def alter_schema(self, sql:str):
        self._write_db.do('execute', sql)
        self._write_db.do('commit')

db = DbAccess()