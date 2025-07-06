require "db"
require "mysql"

class Database
  getter db : DB::Database

  def initialize(@url : String)
    @db = DB.open(@url)
  end

  def fetch_one(query : String, *params) : Hash(String, DB::Any)?
    @db.query_one?(query, args: params) do |rs|
      rs.column_names.zip(rs.read_values).to_h
    end
  end

  def fetch_one_as(type : T.class, query : String, *params) : T? forall T
    @db.query_one?(query, args: params.to_a, as: type)
  end

  def fetch_all(query : String, *params) : Array(Hash(String, DB::Any))
    results = [] of Hash(String, DB::Any)
    @db.query(query, args: params) do |rs|
      rs.each do
        results << rs.column_names.zip(rs.read_values).to_h
      end
    end
    results
  end

  def fetch_val(query : String, *params, column : Int32 = 0) : DB::Any?
    @db.query_one?(query, args: params) do |rs|
      rs.read(column)
    end
  end

  def execute(query : String, *params) : Int64
    @db.exec(query, args: params)
  end

  def transaction(&block : DB::Transaction ->)
    @db.transaction do |tx|
      block.call(tx)
    end
  end
end