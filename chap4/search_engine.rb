require 'rubygems'
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
      weights = {}
      rows.each do |row|
        total_scores[row[0]] = 0
      end
      
      weights.each do |weigh, scores|
        total_scores.each_key do |url|
          total_scores[url] += weight * scores[url]
        end
      end
      total_scores      
    end
    
    def get_url_name(id)
      @db.get_first_value("select url from urllist where rowid=#{id}")      
    end
    
    def query(q)
      rows, word_ids = get_match_rows(q)
      scores = get_scored_list(rows, word_ids)
      ranked_scores = scores.sort {|a,b| b[1] <=> a[1]}
      #ranked_scores = tmp_scores.invert
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
      #return if File.exists?(@db_name)
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
         links = doc.xpath("//a")
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

#c = SearchEngine::Crawler.new('engine.db')
#c.db_create
#pagelist = ['http://kiwitobes.com/wiki/Perl.html']
#c.crawl(pagelist)

s = SearchEngine::Searcher.new("engine.db")
s.query("functional programming")