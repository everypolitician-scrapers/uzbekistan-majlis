#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
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
  noko.css('.deputiesList li a[href*="/deputy/"]/@href').each do |href|
    link = URI.join url, href
    scrape_person(link, { 
      image: href.parent.css('img/@src').text,
    })
  end
end

def scrape_person(url, data_i)
  noko = noko_for(url)

  info = noko.css('#deputyPersInfo')
  add = noko.css('#addInfo')

  data = { 
    id: url.to_s.split('/').last,
    name: noko.css('h2 span').text.tidy,
    birth_date: info.xpath('.//td[text()="Date of Birth"]/following-sibling::td').text.split('.').reverse.join('-'),
    birth_place: info.xpath('.//td[text()="Place of Birth"]/following-sibling::td').text,
    nationality: info.xpath('.//td[text()="Nationality"]/following-sibling::td').text,

    region: add.xpath('.//li[contains(.,"Region:")]').text.split(':',2).last.to_s.tidy,
    constituency: add.xpath('.//li[contains(.,"Constituency:")]').text.split(':',2).last.to_s.tidy,
    party: add.xpath('.//li[contains(.,"Party:")]').text.split(':',2).last.to_s.tidy,
    faction: add.xpath('.//li[contains(.,"Faction member:")]').text.split(':',2).last.to_s.tidy,
    term: 5,
    source: url.to_s,
  }.merge(data_i)
  data[:image] = URI.join(url, URI.encode(data[:image])).to_s unless data[:image].to_s.empty?
  puts data
  # ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_letters('http://www.parliament.gov.uz/en/structure/deputy/search1.php?id=+')
