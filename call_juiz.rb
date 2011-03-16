require 'rubygems'
require 'net/https'
require 'oauth'
require 'json' if RUBY_VERSION < '1.9.0'
# for DB
require 'active_record'
class Juizline < ActiveRecord::Base
end
# for Juiz
require 'juiz_dialog.rb'
require 'kconv'
$KCODE = 'utf-8'

# 単にOAuth接続して、UserStreamを拾っているだけ
# mention に当たるもの、および返信文言については
# Juizdialog に任せている

class CallJuiz
    # bot の screen_name
    SCREEN_NAME = 'call_juiz'

    # bot の user_agent
    BOT_USER_AGENT = 'call_juiz auto reply program 1.0 by @flyeagle'

    # SSL の証明書
    HTTPS_CA_FILE_PATH = './twitter.cer'

    def initialize
        path = '/home/flyeagle/call_juiz/'
        yaml = YAML::load_file(path+'accesskey.yaml')
        accesskey = yaml['call_juiz']
        accesskey = yaml['flyeagle_echo']

        # Twitter Setting
        @consumer = OAuth::Consumer.new(
            accesskey['consumer_key'],
            accesskey['consumer_secret'],
            :site => 'http://twitter.com'
        )
        @access_token = OAuth::AccessToken.new(
            @consumer,
            accesskey['access_token'],
            accesskey['access_token_secret']
        )

        # DB Setting
        mysqlkey = yaml['mysql']
        ActiveRecord::Base.establish_connection(
            :adapter => 'mysql',
            :encoding => 'utf8',
            :host => mysqlkey['host'],
            :username => mysqlkey['username'],
            :password => mysqlkey['password'],
            :database => mysqlkey['database']
        )
        @juizline = Juizline.new
    end

    def run
        loop do
            begin
                connect do |json|
                    if json['text'] then
                        # 自分が発したものは除外
                        user = json['user']
                        if user['screen_name'] == 'flyeagle_echo' || 
                            user['screen_name'] == 'call_juiz' then
                            next
                        end

                        # ジュイス宛ではなかったら無視
                        juiz_dialog = Juizdialog.new(json)
                        if juiz_dialog.gettext == '' then
                            next
                        end

                        # bot の限界を超えてたら無視
#                        if is_bots_twittering?(user['screen_name']) then
#                            next
#                        end

                        # 解析開始
                        juiz_dialog.dialog

                        # つぶやき作成
                        twit = juiz_dialog.gettwit

# debug
if user['screen_name'] == 'sabottery' then
# debug
puts "#{user['screen_name']}: #{CGI.unescapeHTML(json['text'])}"

# debug
puts twit

                        # つぶやき、金額をDBへ記録
                        setdb(json, juiz_dialog.getmoney, 0)

                        # TODO:100億以上も今はDBにつっこんでいる
                        # TODO:定期ツイートを作らないと
                        # TODO:abuserはその際に抜く？setdbしないのもあり

                        # 返信する
                        # sleep 10
                        @access_token.post('/statuses/update.json',
                            'status' => twit
                        )
#debug
end
                    end
                end
            #rescue Timeout::Error, StandardError # 接続エラー
            rescue Timeout::Error # 接続エラー
                puts "Twitter との接続が切れました。もう一度接続します。"
            end
        end
    end

    def setdb(json, price, error)
        user = json['user']
        @juizline.id = user['id_str']
        @juizline.screen_name = user['screen_name']
        @juizline.protected = user['protected'] ? 1 : 0
        @juizline.text = json['text']
        @juizline.text_id = json['id_str']
        @juizline.created_at = Time.parse(json['created_at'].to_s).to_i
        @juizline.price = price
        @juizline.save
        @juizline = Juizline.new
    end

    def is_bots_twittering?(screen_name)
        rows = Juizline.find(:all, :order => "created_at DESC", :limit => 20)

        count = 0
        rows.each do |t|
            if t.screen_name == screen_name then
                count += 1
            end
        end

        # 最新20件の受理の中で5件以上存在すればtrue
        if count > 4 then
            return true
        else
            return false
        end
    end

    # Stream API を呼び出す
    def connect
        uri = URI.parse('https://userstream.twitter.com/2/user.json?track='+SCREEN_NAME)

        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true
        https.ca_file = HTTPS_CA_FILE_PATH
        https.verify_mode = OpenSSL::SSL::VERIFY_PEER
        https.verify_depth = 5

        https.start do |https|
            request = Net::HTTP::Get.new(uri.request_uri)
            request['User-Agent'] = BOT_USER_AGENT
            request.oauth!(https, @consumer, @access_token)

            buf = ''
            flag = false
            https.request(request) do |response|
                response.read_body do |chunk|
                    # call_juiz の場合、friendsが多すぎて大変なのでその部分を無視
                    if !flag && 
                        chunk[/^\{/] != nil && 
                        chunk[/^\{"friends"/] == nil then
                        flag = true
                    end
                    if !flag then
                        next
                    end
                    buf << chunk
                    # 改行コードで区切って1行ずつ読む
                    while (line = buf[/.*?(\r\n)+/m]) != nil
                        status = ''
                        begin
                            buf.sub!(line,'')
                            line.strip!
                            status = JSON.parse(line)
                        rescue
                            break
                        end

                        yield status
                    end
                end
            end
        end
    end
end

if $0 == __FILE__ then
    CallJuiz.new.run
end
