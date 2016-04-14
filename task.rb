# coding: utf-8

require 'open-uri'
require 'nokogiri'
require 'capybara'
require 'capybara/poltergeist'
require 'rest-client'
require 'active_record'
require './models/user'

class Task

  NHK_GUIDE_URL = "http://www4.nhk.or.jp/kogaku/"
  LINK_HOST = "http://kmz-haruko.herokuapp.com/"
  @program_title = ""
  @program_description = ""

  # NHKのサイトから番組情報を強引に取得する
  def get_web_guide

    #poltergistの設定
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, {:js_errors => false, :timeout => 1000 })
    end
    Capybara.default_selector = :xpath
    session = Capybara::Session.new(:poltergeist)

    session.driver.headers = { 'User-Agent' => "Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20100101 Firefox/10.0" } 
    session.visit NHK_GUIDE_URL
    page = Nokogiri::HTML.parse(session.html)

    @program_title = page.css(".program-title").text
    page.search('br').each {|br| br.replace("\n")}
    @program_description = page.css(".program-description").css("p")[1].text
  end

  # 番組情報を登録者に配信
  def send_web_guide
    message = Time.now.strftime("%m/%d(#{%w(日 月 火 水 木 金 土)[Time.now.wday]})")
    message += "の放送内容\n"
    message += @program_title
    message += "\n\n"
    message += @program_description

    users = User.where(enabled: true)
    mids = []
    users.each do |user|
      mids << user.mid
    end
    send_message(message, mids)
    return "OK"
  end

  # 再生リンクを登録者に配信
  def send_play_link
    users_nhknetradio = User.where(enabled: true).where(application: 1)
    users_raziko      = User.where(enabled: true).where(application: 2)
    users_browser     = User.where(enabled: true).where(application: 0)
    mids_nhknetradio = []
    mids_raziko  = []
    mids_browser = []
    users_nhknetradio.each {|u| mids_nhknetradio << u.mid }
    users_raziko.each {|u| mids_raziko << u.mid }
    users_browser.each {|u| mids_browser << u.mid }
    message_nhknetradio = "番組再生\n" + LINK_HOST + "openapp/nhknetradio"
    message_raziko      = "番組再生\n" + LINK_HOST + "openapp/raziko"
    message_browser     = "番組再生\n" + LINK_HOST + "openapp/open"

    send_message(message_nhknetradio, mids_nhknetradio)
    send_message(message_raziko, mids_raziko)
    send_message(message_browser, mids_browser)

    return "OK"
  end

  private

  # メッセージ送信処理
  def send_message(message, mids)
    res_content = {
      to: mids,
      toChannel: 1383378250, # Fixed  value
      eventType: "138311608800106203", # Fixed value
      content: {
        contentType: 1,
        toType: 1,
        text: message
      }
    }

    endpoint_uri = 'https://trialbot-api.line.me/v1/events'
    content_json = res_content.to_json

    RestClient.proxy = ENV['FIXIE_URL'] if ENV['FIXIE_URL']
    RestClient.post(endpoint_uri, content_json, {
      'Content-Type' => 'application/json; charset=UTF-8',
      'X-Line-ChannelID' => ENV["LINE_CHANNEL_ID"],
      'X-Line-ChannelSecret' => ENV["LINE_CHANNEL_SECRET"],
      'X-Line-Trusted-User-With-ACL' => ENV["LINE_CHANNEL_MID"]
    })

  end
end

# Heroku schedulerで毎朝6時頃に実行する
# bundle exec ruby task.rb
wday = Time.now.wday
# 月～金のみ
if wday >= 1 && wday <= 5
  task = Task.new
  task.get_web_guide
  task.send_web_guide
  task.send_play_link
end

