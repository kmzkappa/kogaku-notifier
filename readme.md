# 古楽の楽しみ 開始通知BOT(非公式)

## 概要
NHK-FM「古楽の楽しみ」の番組情報を発言するLINE BOTです。  

App`app.rb`側でユーザ登録、メッセージの待ち受け・応答などを行います。  
Task`task.rb`側で番組情報の取得およびユーザへの通知を行います。

`task.rb`はバッチ処理で番組開始前（朝6時頃）に定期実行されることを想定しています。  

## 特徴
番組で放送される曲名・奏者名を自動的に取得することができます。また同時に再生用のリンクが通知されます。  
リンクを押下したとき、デフォルトでは[らじる★らじるの再生ページ](http://www3.nhk.or.jp/netradio/player/index.html?ch=fm&area=tokyo)をブラウザで開きます。  
Android端末の場合、トーク画面で設定をすることでアプリ版の [らじる★らじる](https://play.google.com/store/apps/details?id=jp.nhk.netradio&hl=ja) または
[Raziko](https://play.google.com/store/apps/details?id=com.gmail.jp.raziko.radiko&hl=ja) を起動することができます。

## 必要ライブラリ
バッチ側の実行には`PhantomJS`が必要です。  
これは[NHKの番組サイト](http://www4.nhk.or.jp/kogaku/")から番組情報を取得しており、サイトではJavaScriptを使用して番組の詳細をレンダリングしているためです。  
（番組情報詳細の取得方法として「らじる★らじる」で使用されているAPIなどが存在しますが、利用条件を調べられなかったため使用していません。）

## 注意
番組情報は番組サイトのDOMを解析して取得しているため、サイトレイアウトが変更されると動作しなくなります。

## 不具合
多分たくさんあります

## その他
改変などはご自由にどうぞ。何かありましたら @kmz_kappa まで。
