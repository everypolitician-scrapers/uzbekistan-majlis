#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'set'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_letters(fmt, lang)
  url = fmt % lang
  noko = noko_for(url % lang)
  noko.css('#alfabetDepsSearch li a/@href').each do |href|
    link = URI.join url, href
    scrape_list(link, lang)
  end
end

def scrape_list(url, lang)
  puts url.to_s.cyan
  noko = noko_for(url)
  seen = Set.new
  noko.css('.deputiesList li a[href*="/deputy/"]/@href').each do |href|
    link = URI.join url, href
    next if seen.include? link
    scrape_person(link, lang, { 
      image: href.parent.css('img/@src').text,
    })
    seen << link
  end
end

def scrape_person(url, lang, data_i)
  noko = noko_for(url)

  add_map = lang == 'uz' ? { 
    region: "Худуд",
    constituency: "Сайлов округи",
    party: "Партияга мансублиги",
    faction: "Фракцияга аъзолиги",
  } : { 
    region: "Region",
    constituency: "Constituency",
    party: "Party",
    faction: "Faction member",
  }

  info_map = lang == 'uz' ? { 
    birth_date: "Туғилган сана",
    birth_place: "Туғилган жойи",
    nationality: "Миллати",
  } : {
    birth_date: "Date of Birth",
    birth_place: "Place of Birth",
    nationality: "Nationality",
  }

  info = noko.css('#deputyPersInfo')
  add = noko.css('#addInfo')

  info_data = Hash[info_map.map { |field, str|
    [ field, info.xpath('.//td[text()="%s"]/following-sibling::td' % str).text.tidy ]
  }]

  add_data = Hash[add_map.map { |field, str|
    [ field, add.xpath('.//li[contains(.,"%s:")]' % str).text.split(':',2).last.to_s.tidy ]
  }]

  data = { 
    id: url.to_s.split('/').last,
    name: noko.css('h2 span').text.tidy,
    term: 5,
    source: url.to_s,
  }.merge(data_i).merge(info_data).merge(add_data)
  data[:image] = URI.join(url, URI.encode(data[:image])).to_s unless data[:image].to_s.empty?
  data[:birth_date] = data[:birth_date].split('.').reverse.join('-')
  # puts data[:id]
  ScraperWiki.save_sqlite([:id, :term], data)
end

@LANG = ARGV.first || 'uz'
scrape_letters('http://www.parliament.gov.uz/%s/structure/deputy/', @LANG)
# scrape_letters('http://www.parliament.gov.uz/en/structure/deputy/search1.php?id=+')
