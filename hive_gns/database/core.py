import os
import psycopg2

from hive_gns.config import Config

config = Config.config

class DbSession:

    def __init__(self, pref):
        self.pref = pref
        self.new_conn()

    def new_conn(self):
        try:
            self.conn = psycopg2.connect(
                host=config['db_host'],
                database=config['db_name'],
                user=config['db_username'],
                password=config['db_password'],
                application_name='gns' + '-' + self.pref,
                connect_timeout=20,
                keepalives=1
            )
            self.conn.autocommit = True
            
        except psycopg2.OperationalError as e:
            if config['db_name'] in e.args[0] and "does not exist" in e.args[0]:
                print(f"No database found. Please create a '{config['db_name']}' database in PostgreSQL.")
                os._exit(1)
            else:
                print(e)
                os._exit(1)
    
    def do(self, query_type, sql='', data=None):
        err_count = 0
        while True:
            try:
                if query_type == 'select':
                    return self._select(sql)
                elif query_type == 'select_one':
                    return self._select_one(sql)
                elif query_type == 'select_exists':
                    return self._select_exists(sql)
                elif query_type == 'execute':
                    self._execute(sql, data)
                    break
                elif query_type == 'commit':
                    self._commit()
                    break
                else:
                    raise Exception(f"Invalid query type passed: {query_type}")
            except psycopg2.OperationalError as err:
                if "server closed the connection unexpectedly" in err.args[0]:
                    print(f"Connection lost. Reconnecting...")
                    self.new_conn()
                else:
                    print(err)
                    print(sql)
                    print(data)
                    err_count += 1
                    if err_count == 10:
                        break

    def _select(self, sql):
        cur = self.conn.cursor()
        cur.execute(sql)
        res = cur.fetchall()
        cur.close()
        if len(res) == 0:
            return None
        else:
            return res

    def _select_one(self, sql):
        cur = self.conn.cursor()
        cur.execute(sql)
        res = cur.fetchone()
        cur.close()
        if len(res) == 0:
            return None
        else:
            return res[0]
    
    def _select_exists(self, sql):
        res = self._select_one(f"SELECT EXISTS ({sql});")
        return res

    def _execute(self, sql,  data=None):
        cur = self.conn.cursor()
        if data:
            cur.execute(sql, data)
        else:
            cur.execute(sql)
        cur.close()

    def _commit(self):
        self.conn.commit()
