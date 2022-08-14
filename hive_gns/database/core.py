import os
import psycopg2
from psycopg2 import DatabaseError

from hive_gns.config import Config

config = Config.config

class DbSession:

    def __init__(self, pref):
        self.new_conn(pref)

    def new_conn(self, pref):
        try:
            self.conn = psycopg2.connect(
                host=config['db_host'],
                database=config['db_name'],
                user=config['db_username'],
                password=config['db_password'],
                application_name=config['main_schema'] + '-' + pref,
                connect_timeout=0
            )
            self.conn.autocommit = True
        except psycopg2.OperationalError as e:
            if config['db_name'] in e.args[0] and "does not exist" in e.args[0]:
                print(f"No database found. Please create a '{config['db_name']}' database in PostgreSQL.")
                os._exit(1)
            else:
                print(e)
                os._exit(1)

    def select(self, sql):
        cur = self.conn.cursor()
        try:
            cur.execute(sql)
            res = cur.fetchall()
            cur.close()
            if len(res) == 0:
                return None
            else:
                return res
        except Exception as e:
            print(e)
            print(f"SQL:  {sql}")
            try:
                self.conn.rollback()
                cur.close()
            except:
                raise Exception ('DB error occurred')

    def select_one(self, sql):
        cur = self.conn.cursor()
        try:
            cur.execute(sql)
            res = cur.fetchone()
            cur.close()
            if len(res) == 0:
                return None
            else:
                return res[0]
        except Exception as e:
            print(e)
            print(f"SQL:  {sql}")
            self.conn.rollback()
            cur.close()
            raise Exception ('DB error occurred')
    
    def select_exists(self, sql):
        res = self.select_one(f"SELECT EXISTS ({sql});")
        return res

    def execute(self, sql,  data=None):
        cur = self.conn.cursor()
        try:
            if data:
                cur.execute(sql, data)
            else:
                cur.execute(sql)
            cur.close()
        except Exception as e:
            print(e)
            print(f"SQL:  {sql}")
            print(f"DATA:   {data}")
            self.conn.rollback()
            cur.close()
            raise Exception({'data': data, 'sql': sql})

    def commit(self):
        self.conn.commit()

    def is_open(self):
        return self.conn.closed == 0
