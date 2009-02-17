require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'uri'

class Crawler
  attr_accessor :db_name
  
  ignorewords = %w(the of to and a in is it)
  
  def initialize(db_name)
    @db_name = db_name
  end
  
  def dbcommit
    
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
    end
  end
  
  def create_index_tables
    
  end
end