require 'rubygems'
require 'oauth'
require 'json' if RUBY_VERSION < '1.9.0'
# for DB
require 'active_record'
class Juizline < ActiveRecord::Base
end
require 'kconv'
$KCODE = 'utf-8'

# routine に設定されている時間だけDBから取得し、
# 報告する

if RUBY_VERSION < '1.9.0'
    class Array
        def choice
            at(Kernel.rand(size))
        end
    end
end

class CallJuizRoutine
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

        @routine = YAML::load_file(path+'juiz_routine.yaml')

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
        hour = Time.now.strftime('%H').to_i

        greeting = @routine['greeting'][hour]
        islow = @routine['islow'][hour]
        range = @routine['range'][hour]

        if greeting != '' then
            rows = select_range(range)
            twit = ''

            # 期間中に申請がない場合
            if rows.length == 0 then
                twit = noapply(greeting, range)
            # 0時バージョン
            elsif hour == 0 then
                twit = midnight(rows, greeting)
            # 通常バージョン
            else
                twit = hourtwit(rows, greeting, range, islow)
            end

            # さて、つぶやきますよ
            @access_token.post('/statuses/update.json',
                'status' => twit
            )
        end
    end

    def noapply(greeting, range)
        twit  = greeting
        twit += "最近の"+range.to_s+"時間で一番……"
        twit += @routine['noapply'].choice()

        return twit
    end

    def hourtwit(rows, greeting, range, islow)
        twit  = greeting
        twit += "最近の"+range.to_s+"時間で"

        t = rows[0]

        # 低い
        if islow == 1 then
            t = rows.shift
            twit += "一番金額の低かった申請は "
        # 高い
        else
            t = rows.pop
            twit += "一番金額の高かった申請は "
        end

        twit += "@"+t.screen_name+" 様の「"+t.text+"」でした。"
        twit += "[金額:"+money_format(t.price)+"円]"

        return twit
    end

    def midnight(rows, greeting)
        money = 0
        rows.each do |t|
            money += t.price
        end

        money_str = money_format(money)
        twit = greeting+"昨日1日の総使用金額は"

        if money > 10000000000 then
            twit += "残念ながら、限度額の100億を超えておりました("+money_str+"円)。"
            twit += @routine['midnight_ng'].choice()
        else
            twit += money_str+"円でした。"
            twit += @routine['midnight_ok'].choice()
        end

        return twit
    end

    def money_format(num)
        return (num.to_s =~ /[-+]?\d{4,}/) ? (num.to_s.reverse.gsub(/\G((?:\d+\.)?\d{3})(?=\d)/, '\1,').reverse) : num.to_s
    end

    # now から range時間前までの申請を取ってくる
    # 金額は必ず1〜100億の間
    # 並び順は必ず金額の昇順 1から大きくなる
    def select_range(range)
        now = Time.now.to_i
        stime = now - range * 3600

        rows = Juizline.find(:all, :conditions => [
            "created_at >= :stime AND created_at < :etime AND protected = 0 AND price > 0",
            {:stime => stime, :etime => now}
        ], :order => "price ASC")

        return rows
    end
end

if $0 == __FILE__ then
    CallJuizRoutine.new.run
end
