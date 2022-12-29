conn = ActiveRecord::Base.connection

if conn.table_exists? "users"
  conn.execute("TRUNCATE TABLE users")
else
  conn.execute(<<-SQL
    CREATE TABLE users (
      id INT NOT NULL AUTO_INCREMENT,
      name VARCHAR(255),
      PRIMARY KEY(id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  SQL
  )
end
