require "db"
require "mysql"

class Database
  getter db : DB::Database

  def initialize(@url : String)
    @db = DB.open(@url)
  end

  def fetch_one(query : String, *params) : Hash(String, DB::Any)?
    args = params.size > 0 ? params.to_a : [] of DB::Any
    @db.query_one?(query, args: args) do |rs|
      hash = Hash(String, DB::Any).new
      rs.column_names.each do |name|
        hash[name] = case value
                     when Int8, Int16
                       value.to_i32
                     when Time::Span
                       value.total_seconds.to_i32
                     when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
                       value
                     else
                       value.as(DB::Any)
                     end
      end
      hash
    end
  end

  def fetch_one_as(type : T.class, query : String, *params) : T? forall T
    args = params.size > 0 ? params.to_a : [] of DB::Any
    @db.query_one?(query, args: args, as: type)
  end

  def fetch_all(query : String, *params) : Array(Hash(String, DB::Any))
    results = [] of Hash(String, DB::Any)
    args = params.size > 0 ? params.to_a : [] of DB::Any
    @db.query(query, args: args) do |rs|
      rs.each do
        hash = Hash(String, DB::Any).new
        rs.column_names.each do |name|
          value = rs.read
          hash[name] = case value
                       when Int8, Int16
                         value.to_i32
                       when Time::Span
                         value.total_seconds.to_i32
                       when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
                         value
                       else
                         value.as(DB::Any)
                       end
        end
        results << hash
      end
    end
    results
  end

  def fetch_val(query : String, *params, column : Int32 = 0) : DB::Any?
    args = params.size > 0 ? params.to_a : [] of DB::Any
    @db.query_one?(query, args: args) do |rs|
      rs.read(DB::Any)
    end
  end

  def execute(query : String, *params) : DB::ExecResult
    args = params.size > 0 ? params.to_a : [] of DB::Any
    @db.exec(query, args: args)
  end

  def transaction(&block : DB::Transaction ->)
    @db.transaction do |tx|
      block.call(tx)
    end
  end
end