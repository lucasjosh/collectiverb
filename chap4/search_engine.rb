require 'rubygems'
require 'nokogiri'
require 'set'
require 'open-uri'
require 'uri'
require 'sqlite3/database'

module SearchEngine

  class Crawler
    attr_accessor :db_name, :db
  
    IGNOREWORDS = %w(the of to and a in is it)
  
    def initialize(db_name)
      @db_name = db_name
      @db = SQLite3::Database.new(@db_name)
    end
    
    def db_create
      return if File.exists?(@db_name)
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
  
    def db_commit
    
    end
  
    def get_entry_id(table, field, value, create_new = true)
      result = @db.execute("select rowid from #{table} where #{field}='#{value}'")
      res = result.first
      if res.nil?
        @db.execute("insert into #{table} (#{field}) values ('#{value}')")
        return @db.last_insert_row_id
      else
        return res[0]
      end
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
        @db.execute("insert into wordlocation(urlid, wordid, location) values (#{urlid}, #{wordid}, #{i})")
      end
      
    end
  
    def get_text_only(page)
     return page.content.strip
    end
  
    def separate_words(text)
      return text.downcase.split(/\W+/).reject { |x| x.empty? }
    end
  
    def indexed?(url)
      return false
    end
  
    def add_link_ref(url_from, url_to, link_text)
    
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
        db_commit
        pages = newpages        
      end
    end
  
    def create_index_tables
    
    end
  end
end

c = SearchEngine::Crawler.new('engine.db')
c.db_create
pagelist = ['http://kiwitobes.com/wiki/Perl.html']
c.crawl(pagelist)