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

# cron登録してない

# OAuth接続して、mentionを拾います
# UserStreamで取りこぼしたものについて、フォローする形
# mention に当たるもの、および返信文言の処理は
# Juizdialog に任せている

class CallJuizMention
    # bot の screen_name
    SCREEN_NAME = 'call_juiz'

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
    end

    # mention API を呼び出す
    def mention
        response = @access_token.get('http://api.twitter.com/1/statuses/mentions.json?count=200')
        JSON.parse(response.body).each do |json|
            if json['text'] then
                # 1分以内の mention は除外
                created_at = Time.parse(json['created_at'].to_s).to_i
                if Time.now.to_i - 60 <= created_at then
                    next
                end

                # 1時間以上過ぎている mention も除外
                if created_at < Time.now.to_i - 3600 then
                    next
                end

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

                # すでにDBで処理していたら無視
                if is_exist?(json['id_str']) then
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

                # 0 <= 金額 <= 100億の場合のみDBへ
                # routine のほうで0円は無視する
                if 0 <= juiz_dialog.getmoney &&
                    juiz_dialog.getmoney <= 10000000000 then

                    # abuser だった場合、
                    # mention はもう返さない
                    if @abuser.index(user['screen_name']) != nil then
                        next
                    end

                    # つぶやき、金額をDBへ記録
                    setdb(json, juiz_dialog.gettext, juiz_dialog.getmoney, 0)
                end
# debug
puts "#{user['screen_name']}: #{CGI.unescapeHTML(json['text'])}"
puts twit


                # 返信する
                sleep 10
                @access_token.post('/statuses/update.json',
                    'status' => twit,
                    'in_reply_to_status_id' => json['id']
                )

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

    def is_exist?(text_id)
        connect_mysql()

        rows = Juizline.find(:all, :conditions => [
            "text_id = :text_id", {:text_id => text_id}
        ])

        close_mysql()

        if rows != nil && rows.length > 0 then
            return true
        else
            return false
        end
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

end

if $0 == __FILE__ then
    CallJuizMention.new.mention
end
