# encoding : utf-8

require 'mechanize'
require 'nokogiri'
require 'iconv'
require 'json'
require 'mongo'

class Gdp
  attr_accessor :month,:m2,:m2_yoy_growth,:m2_chain_growth,:m1,:m1_yoy_growth,:m1_chain_growth,:m0,:m0_yoy_growth,:m0_chain_growth

  def as_json(options={})
    {
        month: @month,
        m2: @m2,
        m2_yoy_growth: @m2_yoy_growth,
        m2_chain_growth: @m2_chain_growth,
        m1: @m1,
        m1_yoy_growth: @m1_yoy_growth,
        m1_chain_growth: @m1_chain_growth,
        m0: @m0,
        m0_yoy_growth: @m0_yoy_growth,
        m0_chain_growth: @m0_chain_growth
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

end

gdp_list = Array.new

agent = Mechanize.new

(1..7).each { |i|
  url = "http://data.eastmoney.com/cjsj/moneysupply.aspx?p=%d" % [i]
  page = agent.get(url)
  page.encoding = "gb2312"
  body = Iconv.conv('UTF-8','gb2312',page.body)
  doc = Nokogiri::HTML(body,nil,"utf-8")
  doc.css('#tb tr').each_with_index {|tr,index|
    unless index<2 or tr.to_s.include?('moretr')
      td = tr.css('td')
      # puts td[6].to_s[/\-?\d+\.\d+%/]

      gdp = Gdp.new
      gdp.month = td[0].to_s[/\d+年\d+月份/]
      gdp.m2 = td[1].to_s[/\d+\.\d+/]
      gdp.m2_yoy_growth = td[2].to_s[/\-?\d+\.\d+%/]
      gdp.m2_chain_growth = td[3].to_s[/\-?\d+\.\d+%/]
      gdp.m1 = td[4].to_s[/\d+\.\d+/]
      gdp.m1_yoy_growth = td[5].to_s[/\-?\d+\.\d+%/]
      gdp.m1_chain_growth = td[6].to_s[/\-?\d+\.\d+%/]
      gdp.m0 = td[7].to_s[/\d+\.\d+/]
      gdp.m0_yoy_growth = td[8].to_s[/\-?\d+\.\d+%/]
      gdp.m0_chain_growth = td[9].to_s[/\-?\d+\.\d+%/]
      gdp_list << gdp
      # puts gdp.to_json
    end
  }
}

client = Mongo::Client.new('mongodb://127.0.0.1:27017/test')
collection = client[:gdp]
gdp_list.each { |gdp|
  document = JSON.parse(gdp.to_json)
  collection.insert_one(document)
}

# doc = { name: 'Steve', hobbies: [ 'hiking', 'tennis', 'fly fishing' ] }
# result = collection.insert_one(doc)