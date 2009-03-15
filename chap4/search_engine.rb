require 'rubygems'
gem 'nokogiri', '= 1.1.1'
require 'nokogiri'
require 'set'
require 'open-uri'
require 'uri'
require 'sqlite3/database'

module SearchEngine
  class Searcher
    attr_accessor :db
    
    def initialize(db_name)
      @db = SQLite3::Database.new(db_name)
    end
    
    def get_match_rows(query)
      field_list = "w0.urlid"
      table_list = ""
      clause_list = ""
      word_ids = Array.new
      
      words = query.split(" ")
      table_number = 0
      
      words.each do |word|
        result = @db.execute("select rowid from wordlist where word='#{word}'")
        res = result.first
        if res
          word_id = res[0]
          word_ids << word_id
          if table_number > 0
            table_list << ","
            clause_list << " and "
            clause_list << "w#{table_number - 1}.urlid=w#{table_number}.urlid and "
          end
          field_list << ",w#{table_number}.location"
          table_list << "wordlocation w#{table_number}"
          clause_list << "w#{table_number}.wordid=#{word_id}"
          table_number += 1
        end
      end
      full_query = "select #{field_list} from #{table_list} where #{clause_list}"
      rows = @db.execute(full_query)
      [rows, word_ids]
    end
    
    def get_scored_list(rows, word_ids)
      total_scores = {}
      weights = [[1.0, frequency_score(rows)], 
                 [1.0, location_score(rows)],
                 [1.0, page_rank_score(rows)],
                 [1.0, link_text_score(rows, word_ids)]
                ]
      rows.each do |row|
        total_scores[row[0]] = 0
      end
      
      weights.each do |weight, scores|
        total_scores.keys.each do |url|
          total_scores[url] += weight * scores[url]
        end
      end
      total_scores      
    end
    
    def get_url_name(id)
      @db.get_first_value("select url from urllist where rowid=#{id}")      
    end
    
    def normalize_scores(scores, small_is_better = false)
      vsmall = 0.00001
      s = {}      
      if small_is_better
        min_score = scores.values.min
        min_score = vsmall if min_score == 0
        scores.each do |u, l|
          s[u] = min_score.to_f / [vsmall, l].max
        end
      else
        max_score = scores.values.max
        max_score = vsmall if max_score == 0
        scores.each do |u, c|
          s[u] = c.to_f / max_score
        end
      end
      s
    end
    
    def frequency_score(rows)
      counts = {}
      rows.each {|row| counts[row[0]] = 0}
      rows.each {|row| counts[row[0]] += 1}
      
      normalize_scores(counts)
      
    end
    
    def location_score(rows)
      locations = {}
      rows.each {|row| locations[row[0]] = 1000000}
      rows.each do |row|
        loc = row[1...-1].inject(0) {|sum, r| sum + r.to_f}
        locations[row[0]] = loc if loc < locations[row[0]]
      end
      normalize_scores(locations, true)
    end
    
    def distance_score(rows)
      distances = {}
      rows.each {|row| distances[row[0]] = 1.0}
      return distances if rows[0].size <= 2
      
      min_distance = {}
      rows.each {|row| min_distances[row[0]] = 1000000}
      
      rows.each do |row|
        sum = 0
        2.upto(row.size) do |i|
          sum += (row[i] - row[i - 1]).abs
        end
        min_distance[row[0]] = dist if dist < min_distance[row[0]]
      end
      normalize_scores(min_distance, true)
    end
    
    def inbound_link_score(rows)
      unique_urls = (rows.collect {|row| row[0]}).uniq
      inbound_count = {}
      unique_urls.each do |u|
        v = @db.get_first_value("select count(*) from link where toid=#{u}")
        inbound_count[u] = v
      end
      normalize_scores(inbound_count)
    end
    
    def calculate_page_rank(iterations = 20)
      @db.execute("drop table if exists pagerank")
      @db.execute("create table pagerank(urlid primary key, score)")
      @db.execute("insert into pagerank select rowid, 1.0 from urllist")
      
      1.upto(iterations) do |i|
        puts "Iteration #{i}"
        
        
        result = @db.execute("select rowid from urllist")
        result.each do |urlid|
          pr = 0.15
          linker_result = @db.execute("select distinct fromid from link where toid=#{urlid}")
          linker_result.each do |linker|
            linking_pr = @db.get_first_value("select score from pagerank where urlid=#{linker}")
            linking_count = @db.get_first_value("select count(*) from link where fromid=#{linker}")
            pr += 0.85 * (linking_pr.to_f / linking_count.to_f)
          end
          @db.execute("update pagerank set score=#{pr} where urlid=#{urlid}")
        end
      end
      
    end
    
    def page_rank_score(rows)
      pageranks = {}
      rows.each do |row|
        pr = @db.get_first_value("select score from pagerank where urlid=#{row[0]}")
        pageranks[row[0]] = pr
      end
      maxrank = pageranks.values.max
      normalized_scores = {}
      pageranks.each do |u, l|
        normalized_scores[u] = l.to_f / maxrank.to_f
      end
      normalized_scores
    end
    
    def link_text_score(rows, wordids)
      link_scores = {}
      rows.each {|row| link_scores[row[0]] = 0}
      wordids.each do |wordid|
        result = @db.execute("select link.fromid, link.toid from linkwords, link where wordid=#{wordid} and linkwords.linkid=link.rowid")
        result.each do |fromid, toid|
          if link_scores.key?(toid)
            pr = @db.get_first_value("select score from pagerank where urlid=#{fromid}")
            link_scores[toid] += pr.to_f
          end
        end        
      end
      max_score = link_scores.values.max
      normalized_scores = {}
      link_scores.each do |u, l|
        normalized_scores[u] = l.to_f / max_score.to_f
      end
      normalized_scores
    end
    
    def query(q)
      rows, word_ids = get_match_rows(q)
      scores = get_scored_list(rows, word_ids)
      ranked_scores = scores.sort {|a,b| b[1] <=> a[1]}
      ranked_scores.each do |urlid, score|
        puts "#{score} => #{get_url_name(urlid)}"
      end
    end
  end

  class Crawler
    attr_accessor :db_name, :db
  
    IGNOREWORDS = %w(the of to and a in is it)
  
    def initialize(db_name)
      @db_name = db_name
      @db = SQLite3::Database.new(@db_name)
    end
    
    def db_create
      @db.transaction do
        @db.execute("create table urllist(url)")
        @db.execute("create table wordlist(word)")
        @db.execute("create table wordlocation(urlid, wordid, location)")
        @db.execute("create table link(fromid integer, toid integer)")
        @db.execute("create table linkwords(wordid, linkid)")
        @db.execute("create index wordidx on wordlist(word)")
        @db.execute("create index urlidx on urllist(url)")
        @db.execute("create index wordurlidx on wordlocation(wordid)")
        @db.execute("create index urltoidx on link(toid)")
        @db.execute("create index urlfromidx on link(fromid)")
      end
      #db_commit
    end
  
    def db_commit
      @db.commit
    end
  
    def get_entry_id(table, field, value, create_new = true)
      result = @db.execute("select rowid from #{table} where #{field}='#{value}'")
      res = result.first
      if res.nil?
        @db.transaction do
          @db.execute("insert into #{table} (#{field}) values ('#{value}')")
        end
        return @db.last_insert_row_id
      else
        return res[0]
      end
    end
    
    def indexed?(url)
      result = @db.execute("select rowid from urllist where url='#{url}'").first
      return false if result.nil?
      
      result = @db.execute("select count(*) from wordlocation where urlid=#{result[0]}")
      (result && result.first[0].to_i > 1) ? true : false
    end
  
    def add_to_index(url, page)
      return if indexed?(url)
      puts "Indexing #{url}"
      
      text = get_text_only(page)
      words = separate_words(text)
      
      urlid = get_entry_id('urllist', 'url', url)
      
      words.size.times do |i|
        word = words[i]
        next if IGNOREWORDS.include?(word)
        
        wordid = get_entry_id('wordlist', 'word', word)
        @db.transaction do
          @db.execute("insert into wordlocation(urlid, wordid, location) values (#{urlid}, #{wordid}, #{i})")
        end
      end
      
    end
  
    def get_text_only(page)
     return page.content.strip
    end
  
    def separate_words(text)
      return text.downcase.split(/\W+/).reject { |x| x.empty? }
    end
  
    def add_link_ref(url_from, url_to, link_text)
      words = separate_words(link_text)
      from_id = get_entry_id('urllist', 'url', url_from)
      to_id = get_entry_id('urllist', 'url', url_to)
      return if from_id == to_id
      @db.transaction do
        @db.execute("insert into link(fromid, toid) values (#{from_id}, #{to_id})")
      end
      link_id = @db.last_insert_row_id
      words.each do |word|
        word_id = get_entry_id('wordlist', 'word', word)
        @db.transaction do
          @db.execute("insert into linkwords(linkid, wordid) values (#{link_id}, #{word_id})")
        end
      end
      
    end
    
    def crawl(pages, depth=2)
      depth.times do |i|
        newpages = Set.new      
        pages.each do |page|
          begin
            doc = Nokogiri::HTML(open(page))
          rescue
            puts "Could not open => #{page}"
            next
          end
         add_to_index(page, doc)
         links = doc.search("//a")
         links.each do |link|
           if link.attributes.key? 'href'
            url = URI.join(page, link.attributes['href'].to_s).to_s
            next if url =~ /'/
            url = url.split('#')[0]
            newpages << url if url[0,4] == "http" && !indexed?(url)
            link_text = get_text_only(link)
            add_link_ref(page, url, link_text)
           end
         end
        end
        pages = newpages        
      end
    end
  end
end

#c = SearchEngine::Crawler.new('full_engine.db')
#c.db_create
#pagelist = ['http://kiwitobes.com/wiki/Categorical_list_of_programming_languages.html']
#c.crawl(pagelist)

s = SearchEngine::Searcher.new("full_engine.db")

# Uncomment the below if you need to run the initial pagerank equation
#s.calculate_page_rank

s.query("functional programming")

