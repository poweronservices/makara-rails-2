conn = ActiveRecord::Base.connection

conn.execute(<<-SQL
  CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    PRIMARY KEY(id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
SQL
)
conn.execute("TRUNCATE TABLE users")
