# coding: utf-8

require 'sinatra/base'
require 'json'
require 'rest-client'
require 'active_record'
require './models/user'

ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

class App < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  # メッセージ受信、友達登録時
  post '/linebot/callback' do
    params = JSON.parse(request.body.read)

    change_friend_status = :none

    # TODO: 複数人のデータが同時に来る場合がありそう
    params['result'].each do |msg|
      # 友達登録/ブロックの場合
      if msg['content']['opType'] == 4
        change_friend_status = :add
      elsif msg['content']['opType'] == 8
        change_friend_status = :block
      end

      user_text = ""
      if change_friend_status == :none
        user_mid  = msg['content']['from']
        user_text = msg['content']['text']
      else
        # 友達登録/ブロックの場合はメッセージ構造が異なる
        # TODO: msg['content']['params']に複数のmidが入る場合がある？
        user_mid = msg['content']['params'].first
      end
      
      # コマンド種別の判定
      user_text_type = analyze_text(user_text, change_friend_status)
      application_type = ""
      if user_text_type == :setapp
        application_type = user_text.tr("０-２", "0-2").to_i
      end

      # コマンド実行
      response_text = execute_command(user_mid, user_text_type, application_type)

      # 返答メッセージ送信
      return send_message(user_mid, response_text)

    end

  end

  # 再生URLを踏んだとき
  get '/openapp/:appname' do
    NHK_FM_URL = "http://www3.nhk.or.jp/netradio/player/index.html?ch=fm&area=tokyo"
    NHKNETRADIO_INTENT_TO = "nhknetradio://nhk.jp/netradio"
    RAZIKO_INTENT_TO = "intent://#Intent;scheme=tagmanager.c.com.gmail.jp.raziko.radiko;package=com.gmail.jp.raziko.radiko;end"

    redirect NHK_FM_URL unless ua_android?(request) and return

    case :appname
    when "nhknetradio"
      redirect NHKNETRADIO_INTENT_TO
    when "raziko"
      redirect RAZIKO_INTENT_TO
    else
      redirect NHK_FM_URL
    end
  end

  private

  # ユーザ入力コマンドを解析
  def analyze_text(user_text, change_friend_status)
    if change_friend_status == :add
      return :add
    elsif change_friend_status == :block
      return :block
    elsif user_text =~ /^[\s　]*登録[\s　]*$/
      return :registration
    elsif user_text =~ /^[\s　]*解除[\s　]*$/
      return :unregistration
    elsif user_text =~ /^[\s　]*設定[\s　]*$/
      return :configure
    elsif user_text =~ /^[\s　]*[012０１２][\s　]*$/
      return :setapp
    end
    return :invalid
  end

  # UAの判定
  def ua_android?(request)
    ua = request.user_agent
    return ["Android"].find {|s| ua.include?(s)} == "Android"
  end

  # ユーザの入力したコマンドの実行・返答メッセージの生成
  def execute_command(user_mid, cmd_type, apptype)
    case cmd_type
    when :registration
      user = User.where(mid: user_mid).first_or_initialize
      user.mid ||= user_mid
      user.application ||= 0 # default
      user.enabled = true
      user.save
      return "番組情報の通知を設定しました。"
    when :unregistration
      user = User.where(mid: user_mid).first
      if user
        user.enabled = false
        user.save
      end
      return "番組情報の通知を解除しました。"
    when :configure
      str = <<'EOS'
番組を再生するアプリケーションを設定します(Android端末のみ)。
「らじる★らじる」を使用する場合は「1」
「Raziko」を使用する場合は「2」
ブラウザで再生する場合は「0」(デフォルト) と発言してください。
（1, 2 を指定する場合、Google Play にて対応するアプリケーションをインストールしてください。）
EOS
      return str
    when :setapp
      user = User.where(mid: user_mid).first_or_initialize
      user.mid ||= user_mid
      user.application = apptype
      user.enabled ||= false
      user.save
      
      if apptype == 1
        return "再生用リンクを「らじる★らじる」に設定しました。"
      elsif apptype == 2
        return "再生用リンクを「Raziko」に設定しました。"
      else
        return "再生用リンクをブラウザ用に設定しました。"
      end
    when :add
      str = <<'EOS'
【古楽の楽しみ 開始通知BOT(非公式)】
　このBOTは、登録をすると毎朝6時(平日のみ)にNHK-FM「古楽の楽しみ」の番組情報をお知らせします。
また、通知されたリンクをクリックすることで、再生アプリケーションを起動することができます。
（Android用アプリ「らじる★らじる」「Raziko」に対応しています。iOS・Windows等をご利用の場合はブラウザで再生画面を開きます。Android端末で再生アプリを使用する場合は、後述する設定が必要です。）

[利用方法]
・通知を登録するとき：「登録」と発言してください。
・再生アプリケーションを設定するとき：「設定」と発言します。その後案内に従い、使用するアプリケーションの番号を指定してください。
（デフォルトではブラウザで再生します。）
・通知を解除するとき：「解除」と発言してください。

[お知らせ]
このBOTはLINE「BOT API Trial Account」を使用しています。
不具合などがありましたら、Twitter: @kmz_kappa までお知らせください。
EOS
      return str
    when :block
      user = User.where(mid: user_mid).first
      if user
        user.enabled = false
        user.save
      end
      return ""
    else
      return "無効なコマンドが指定されました。使用可能なコマンドは「登録」「解除」「設定」「0～2」のいずれかです。"
    end
  end

  # 応答メッセージ送信
  def send_message(mid, res_text)
    # when blocked
    return "OK" if res_text == ""

    res_content = {
      to: [mid],
      toChannel: 1383378250, # Fixed  value
      eventType: "138311608800106203", # Fixed value
      content: {
        contentType: 1,
        toType: 1,
        text: res_text
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
    return "OK"
  end

end
