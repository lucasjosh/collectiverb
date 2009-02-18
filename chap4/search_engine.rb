require 'rubygems'
require 'nokogiri'
require 'set'
require 'open-uri'
require 'uri'

module SearchEngine

  class Crawler
    attr_accessor :db_name
  
    ignorewords = %w(the of to and a in is it)
  
    def initialize(db_name)
      @db_name = db_name
    end
  
    def db_commit
    
    end
  
    def get_entry_id(table, field, value, create_new = true)
      nil
    end
  
    def add_to_index(url, page)
      puts "Indexing #{url}"
    end
  
    def get_text_only(page)
      nil
    end
  
    def separate_words(text)
      return nil
    end
  
    def is_indexed(url)
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
            newpages << url if url[0,4] == "http" && !is_indexed(url)
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

c = SearchEngine::Crawler.new('')
pagelist = ['http://kiwitobes.com/wiki/Perl.html']
c.crawl(pagelist)