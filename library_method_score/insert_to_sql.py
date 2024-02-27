import MySQLdb

class SQLManiplator:
    def __init__(self, host, user, password, db):
        self.host = host
        self.user = user
        self.password = password
        self.db = "method_score_db"
        self.connection = None
        self.cursor = None
        self.connect()

    def connect(self):
        self.connection = MySQLdb.connect(
            host=self.host,
            user=self.user,
            password=self.password,
            db=self.db
        )
        self.cursor = self.connection.cursor()

    def execute(self, sql):
        self.cursor.execute(sql)
        self.connection.commit()
        return self.cursor.fetchall()
    
    def insert_method_score(self, lib_name, method_name, score):
        sql = 'insert into method_score (lib_name, method_name, score) values ("' + lib_name + '", "' + method_name + '", ' + str(score) + ');'
        self.execute(sql)