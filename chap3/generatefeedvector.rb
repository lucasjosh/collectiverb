#!/usr/bin/env ruby

require 'rubygems'
require 'simple-rss'
require 'open-uri'

def get_word_counts(url)
  rss = SimpleRSS.parse open(url)
  wc = {}
  
  rss.entries.each do |entry|
    summary = entry.summary ? entry.summary : entry.description
    summary = '' unless summary
    title = entry.title ? entry.title : ''
    words = get_words(title + ' ' + summary)
    words.each do |word|
      wc[word] = 0 unless wc[word]
      wc[word] += 1
    end
  end
  [rss.title, wc]
end

def get_words(html)
  txt = html.gsub(/<\/?[^>]*>/, "")
  words = txt.split(/[^A-Z^a-z]+/)
  ret_word = Array.new
  words.each do |word|
    ret_word << word.downcase! if word != ''
  end
  ret_word
end

apcount={}
wordcounts={}
ct = 0
IO.readlines('feedlist.txt').each do |url|
  begin
    title, wc = get_word_counts(url.strip)
    wordcounts[title]=wc
    wc.each do |word, count|
      apcount[word] = 0 unless apcount[word]
      apcount[word] += 1 if count > 1
    end
    ct += 1
  rescue
    puts "url was a problem: #{url.strip}"
  end
end

wordlist = Array.new
apcount.each do |w, bc|
  frac = bc.to_f / ct.to_f
  wordlist << w if frac > 0.1 and frac < 0.5
end

out = open('blogdata1.txt', 'w')
out << 'Blog'
wordlist.each {|word| out << "\t#{word}"}
out << "\n"

wordcounts.each do |blog, wc|
  puts blog
  out << blog
  wordlist.each do |word|
    if wc.key?(word)
      out << "\t#{wc[word]}" 
    else
      out << "\t0"
    end
  end
  out << "\n"
end
