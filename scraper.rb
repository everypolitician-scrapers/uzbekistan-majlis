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

def scrape_letters(url)
  noko = noko_for(url)
  noko.css('#alfabetDepsSearch li a/@href').each do |href|
    link = URI.join url, href
    scrape_list(link)
  end
end

def scrape_list(url)
  puts url.to_s.cyan
  noko = noko_for(url)
  seen = Set.new
  noko.css('.deputiesList li a[href*="/deputy/"]/@href').each do |href|
    link = URI.join url, href
    next if seen.include? link
    scrape_person(link, { 
      image: href.parent.css('img/@src').text,
    })
    seen << link
  end
end

def scrape_person(url, data_i)
  noko = noko_for(url)

  add_map = { 
    region: "Худуд",
    constituency: "Сайлов округи",
    party: "Партияга мансублиги",
    faction: "Фракцияга аъзолиги",
  }

  info_map = { 
    birth_date: "Туғилган сана",
    birth_place: "Туғилган жойи",
    nationality: "Миллати",
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
  puts data
  # ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_letters('http://www.parliament.gov.uz/uz/structure/deputy/')
# scrape_letters('http://www.parliament.gov.uz/en/structure/deputy/search1.php?id=+')
