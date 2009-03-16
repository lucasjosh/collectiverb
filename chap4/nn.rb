require 'sqlite3/database'

class SearchNet
  attr_accessor :db
  
  def initialize(db_name)
    @db = SQLite3::Database.new(db_name)
  end
  
  def create_tables
    @db.transaction do
      @db.execute("create table hiddennode(create_key)")
      @db.execute("create table wordhidden(fromid, toid, strength)")
      @db.execute("create table hiddenurl(fromid, toid, strength)")      
    end
  end
  
  def get_strength(from_id, to_id, layer)
    table = "hiddenurl"
    table = "wordhidden" if layer == 0
    
    strength = @db.get_first_value("select strength from #{table} where fromid=#{from_id} and toid=#{to_id}")
    unless strength
      return -0.2 if layer == 0
      return 0 if layer == 1
    end
    strength
  end
  
  def set_strength(from_id, to_id, layer, strength)
    table = "hiddenurl"
    table = "wordhidden" if layer == 0
    
    rowid = @db.get_first_value("select rowid from #{table} where fromid=#{from_id} and toid=#{toid}")
    
    unless rowid
      @db.execute("insert into #{table} (fromid, toid, strength) values (#{from_id}, #{to_id}, #{strength})")
    else
      @db.execute("update #{table} set strength=#{strength} where rowid=#{rowid}")
    end
  end
  
  def generate_hidden_node(wordids, urls)
    return nil if wordids.size  > 3
    create_key = "_" << wordids.sort.join("_")
    
    res = @db.get_first_value("select rowid from hiddennode where create_key=#{create_key}")
    
    if res.nil?
      @db.transaction do 
        @db.execute("insert into hiddennode(create_key) values('#{create_key}')")
      end
      hidden_id = @db.last_insert_row_id
      wordids.each do |word_id|
        set_strength(word_id, hidden_id, 0, (1.0 / wordids.size).to_f)
      end 
      urls.each do |urlid|
        set_strength(hidden_id, url_id, 1, 0.1)
      end
    end
  end
end