require 'rubygems'
require 'net/https'
require 'oauth'
require 'json' if RUBY_VERSION < '1.9.0'
require 'yaml'
# for DB
require 'active_record'
class Juizline < ActiveRecord::Base
end
# for Juiz
require '/home/flyeagle/call_juiz/juiz_dialog.rb'
require 'kconv'
$KCODE = 'utf-8'

# 単にOAuth接続して、UserStreamを拾っているだけ
# mention に当たるもの、および返信文言の処理は
# Juizdialog に任せている

# TODO:crowl_mention


class CallJuiz
    # bot の screen_name
    SCREEN_NAME = 'call_juiz'
    #SCREEN_NAME = 'flyeagle_echo'

    # bot の user_agent
    BOT_USER_AGENT = 'call_juiz auto reply program 1.0 by @flyeagle'

    # SSL の証明書
    HTTPS_CA_FILE_PATH = '/home/flyeagle/call_juiz/twitter.cer'

    def initialize
        path = '/home/flyeagle/call_juiz/'
        yaml = YAML::load_file(path+'accesskey.yaml')
        accesskey = yaml[SCREEN_NAME]

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
        @mysqlkey = yaml['mysql']

        # abuser
        @abuser = yaml['abuser']

        # timer
        @starttime = Time.now.to_i
    end

    def run
        loop do
            begin
                connect do |json|
                    if json['event'] == 'follow' then
                        if json['source']['screen_name'] != SCREEN_NAME then
                            @access_token.post('/friendships/create.json',
                                'user_id' => json['source']['id']
                            )
                        end
                    end
                    if json['text'] then
                        # 自分が発したものは除外
                        user = json['user']
                        if user['screen_name'] == SCREEN_NAME then
                            next
                        end

                        # ジュイス宛ではなかったら無視
                        juiz_dialog = Juizdialog.new(json)
                        if juiz_dialog.gettext == '' then
                            next
                        end

                        # bot の限界を超えてたら無視
                        if is_bots_twittering?(user['screen_name']) then
                            next
                        end

                        # 解析開始
                        juiz_dialog.dialog

                        # つぶやき作成
                        twit = juiz_dialog.gettwit

# debug
#if user['screen_name'] == 'sabottery' then
# debug
#puts "#{user['screen_name']}: #{CGI.unescapeHTML(json['text'])}"

# debug
#puts twit

                        # 0 <= 金額 <= 100億の場合のみDBへ
                        # routine のほうで0円は無視する
                        if 0 <= juiz_dialog.getmoney &&
                            juiz_dialog.getmoney <= 10000000000 then

                            # abuser だった場合、protected を true に
                            # TODO:abuserを追加した際の再起動方法
                            if @abuser.index(user['screen_name']) != nil then
                                json['user']['protected'] = true
                            end

                            # つぶやき、金額をDBへ記録
                            setdb(json, juiz_dialog.gettext, juiz_dialog.getmoney, 0)
                        end

                        # 返信する
                        sleep 10
                        @access_token.post('/statuses/update.json',
                            'status' => twit,
                            'in_reply_to_status_id' => json['id']
                        )

#debug
#end
                    end
                end
            #rescue Timeout::Error, StandardError # 接続エラー
            rescue Timeout::Error # 接続エラー
                puts "Twitter との接続が切れました。もう一度接続します。"
            end
        end
    end

    def setdb(json, text, price, error)
        connect_mysql()

        user = json['user']
        juizline = Juizline.new

        juizline.id = user['id_str']
        juizline.screen_name = user['screen_name']
        juizline.protected = user['protected'] ? 1 : 0
        juizline.text = text
        juizline.text_id = json['id_str']
        juizline.created_at = Time.parse(json['created_at'].to_s).to_i
        juizline.price = price
        juizline.save

        close_mysql()
    end

    def is_bots_twittering?(screen_name)
        connect_mysql()

        rows = Juizline.find(:all, :order => "created_at DESC", :limit => 20)

        count = 0
        rows.each do |t|
            if t.screen_name == screen_name then
                count += 1
            end
        end

        close_mysql()

        # 最新20件の受理の中で5件以上存在すればtrue
        if count > 4 then
            return true
        else
            return false
        end
    end

    def connect_mysql
        ActiveRecord::Base.establish_connection(
            :adapter => 'mysql',
            :encoding => 'utf8',
            :host => @mysqlkey['host'],
            :username => @mysqlkey['username'],
            :password => @mysqlkey['password'],
            :database => @mysqlkey['database']
        )
    end

    def close_mysql
        ActiveRecord::Base.remove_connection
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

                        # 20秒に1回のセルフチェック
                        if Time.now.to_i % 20 == 0 then
                            if (Time.now.to_i - @starttime > 1 * 60 * 60 - 19) then
                                abort("started "+Time.at(@starttime).to_s+" ended "+Time.now.to_s)
                            end
                            if File.exist?('/home/flyeagle/call_juiz/abort') then
                                abort("aborted by file: started "+Time.at(@starttime).to_s+" ended "+Time.now.to_s)
                            end
                        end
                    end
                end
            end
        end
    end
end

if $0 == __FILE__ then
    CallJuiz.new.run
end
