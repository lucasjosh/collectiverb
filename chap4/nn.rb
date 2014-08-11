require 'rubygems'
require 'sqlite3/database'

class SearchNet
  attr_accessor :db
  attr_accessor :word_ids, :hidden_ids, :url_ids
  attr_accessor :ai, :ah, :ao, :wi, :wo

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

    rowid = @db.get_first_value("select rowid from #{table} where fromid=#{from_id} and toid=#{to_id}")

    unless rowid
      @db.execute("insert into #{table} (fromid, toid, strength) values (#{from_id}, #{to_id}, #{strength})")
    else
      @db.execute("update #{table} set strength=#{strength} where rowid=#{rowid}")
    end
  end

  def generate_hidden_node(wordids, urls)
    return nil if wordids.size  > 3
    create_key = "_" << wordids.sort.join("_")

    res = @db.get_first_value("select rowid from hiddennode where create_key='#{create_key}'")


    if res.nil?
      @db.transaction do
        @db.execute("insert into hiddennode(create_key) values('#{create_key}')")
      end
      hidden_id = @db.last_insert_row_id
      wordids.each do |word_id|
        set_strength(word_id, hidden_id, 0, (1.0 / wordids.size).to_f)
      end
      urls.each do |urlid|
        set_strength(hidden_id, urlid, 1, 0.1)
      end
    end
  end

  def get_all_hidden_ids(word_ids, url_ids)
    l1 = {}
    word_ids.each do |word_id|
      rows = @db.execute("select toid from wordhidden where fromid=#{word_id}")
      rows.each {|row| l1[row[0]] = 1 }
    end
    url_ids.each do |url_id|
      rows = @db.execute("select fromid from hiddenurl where toid=#{url_id}")
      rows.each {|row| l1[row[0]] = 1}
    end
    l1.keys
  end

  def setup_network(word_ids, url_ids)
    @word_ids = word_ids
    @hidden_ids = get_all_hidden_ids(word_ids, url_ids)
    @url_ids = url_ids

    @ai = [1.0] * word_ids.size
    @ah = [1.0] * hidden_ids.size
    @ao = [1.0] * url_ids.size

    @wi = Array.new
    @word_ids.each do |word_id|
      l_wi = Array.new
      @hidden_ids.each do |hidden_id|
        l_wi << get_strength(word_id, hidden_id, 0)
      end
      @wi << l_wi
    end

    @wo = Array.new
    @hidden_ids.each do |hidden_id|
      l_wo = Array.new
      @url_ids.each do |url_id|
        l_wo <<  get_strength(hidden_id, url_id, 1)
      end
      @wo << l_wo
    end

  end

  def feed_forward
    @word_ids.size.times do |i|
      @ai[i] = 1.0
    end
    @hidden_ids.size.times do |j|
      sum = 0.0
      @word_ids.size.times do |i|
        sum = sum + @ai[i].to_f * @wi[i][j].to_f
      end
      @ah[j] = Math.tanh(sum)
    end

    @url_ids.size.times do |k|
      sum = 0.0

      @hidden_ids.size.times do |j|
        sum = sum + @ah[j].to_f * @wo[j][k].to_f
      end
      @ao[k] = Math.tanh(sum)
    end
    @ao
  end

  def dtanh(y)
    1.0-y*y
  end

  def back_propagate(targets, n=0.5)
    output_deltas = [0.0] * @url_ids.size
    @url_ids.size.times do |k|
      error = targets[k].to_f - @ao[k].to_f
      output_deltas[k] = dtanh(@ao[k]) * error
    end

    hidden_deltas = [0.0] * @hidden_ids.size
    @hidden_ids.size.times do |j|
      error = 0.0
      @url_ids.size.times do |k|
        error = error + output_deltas[k].to_f * @wo[j][k].to_f
      end
      hidden_deltas[j] = dtanh(@ah[j]) * error
    end

    @hidden_ids.size.times do |j|
      @url_ids.size.times do |k|
        change = output_deltas[k].to_f * @ah[j].to_f
        @wo[j][k] = @wo[j][k].to_f + n*change
      end
    end

    @word_ids.size.times do |i|
      @hidden_ids.size.times do |j|
        change = hidden_deltas[j].to_f * @ai[i].to_f
        @wi[i][j] = @wi[i][j].to_f + n*change
      end
    end
  end

  def train_query(word_ids, url_ids, selected_url)
    generate_hidden_node(word_ids, url_ids)
    setup_network(word_ids, url_ids)
    feed_forward
    targets = [0.0] * url_ids.size
    targets[url_ids.index(selected_url)] = 1.0
    error = back_propagate(targets)
    update_database
  end

  def update_database
    @word_ids.size.times do |i|
      @hidden_ids.size.times do |j|
        set_strength(@word_ids[i], @hidden_ids[j], 0, @wi[i][j])
      end
    end
    @hidden_ids.size.times do |j|
      @url_ids.size.times do |k|
        set_strength(@hidden_ids[j], @url_ids[k], 1, @wo[j][k])
      end
    end
  end

  def get_result(word_ids, url_ids)
    setup_network(word_ids, url_ids)
    feed_forward
  end
end

mynet = SearchNet.new("nnnetwork.db")
#mynet.create_tables
wWorld, wRiver, wBank = 101, 102, 103
uWorldBank, uRiver, uEarth = 201, 202, 203
#mynet.generate_hidden_node([wWorld, wBank], [uWorldBank, uRiver, uEarth])
#
# mynet.db.execute("select * from wordhidden").each do |c|
#   puts c
# end
#
# mynet.db.execute("select * from hiddenurl").each do | c|
#   puts c
# end
mynet.train_query([wWorld, wBank], [uWorldBank, uRiver, uEarth], uWorldBank)
puts mynet.get_result([wWorld, wBank], [uWorldBank, uRiver, uEarth])