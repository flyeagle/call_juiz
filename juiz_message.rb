require 'yaml'
require 'kconv'
$KCODE = 'utf-8'

if RUBY_VERSION < '1.9.0'
    class Array
        def choice
            at(Kernel.rand(size))
        end
    end
end

class Juizmessage
    def initialize
        path = '/home/flyeagle/call_juiz/'
        @normal = YAML::load_file(path+'juiz_normal.yaml') 
        @season = YAML::load_file(path+'juiz_season.yaml') 
        @textmes = YAML::load_file(path+'juiz_textmes.yaml') 
        @gourmet = YAML::load_file(path+'juiz_gourmet.yaml') 
        @character = YAML::load_file(path+'juiz_character.yaml') 

        @screen_name = ''
        @text = ''
        @lang = 'ja'
        @time_zone = 'Tokyo'
        @message = ''
        @money = 0
    end

    ## Gourmet Message
    def gourmet_drink_cold
        drink = @gourmet['drink_cold'].choice().split('#')
        return {'message' => drink[0], 'money' => drink[1].to_i}
    end
    def gourmet_drink_hot
        drink = @gourmet['drink_hot'].choice().split('#')
        return {'message' => drink[0], 'money' => drink[1].to_i}
    end
    def gourmet_drink
        drink = (@gourmet['drink_cold']+@gourmet['drink_hot']).choice().split('#')
        return {'message' => drink[0], 'money' => drink[1].to_i}
    end
    def gourmet_food
        food = @gourmet['food'].choice().split('#')
        return {'message' => food[0], 'money' => food[1].to_i}
    end
    def gourmet_winter
        item = @gourmet['item'].choice().split('#')
        return {'message' => item[0], 'money' => item[1].to_i}
    end

    ## Seasonal Message
    def newyear
        return @season['newyear'].choice()
    end
    def tanzaku
        return @season['tanzaku'].choice()
    end

    ## Text Message
    def text_extu
        return @textmes['text_extu'].choice()
    end
    def text_thankyou
        return @textmes['text_thankyou'].choice()
    end
    def text_congrats
        return @textmes['text_congrats'].choice()
    end
    def text_morning
        return @textmes['text_morning'].choice()
    end
    def text_sleep
        return @textmes['text_sleep'].choice()
    end
    def text_sorry
        return @textmes['text_sorry'].choice()
    end
    def merry_fail
        return @textmes['merry_fail'].choice()
    end
    def merry_success
        return @textmes['merry_success'].choice()
    end
    def feel_sleepy
        h = Time.now.hour
        if h > 6 && h < 12 then
            return '昨晩あまりお休みになれなかったのですね。Noblesse Oblige。'+messia()
        elsif h > 11 && h < 16 then
            return '少しお昼寝を取られてはいかがでしょう？Noblesse Oblige。'+messia()
        elsif h > 15 && h < 19 then
            return '気分転換に散歩などいかがでしょう？Noblesse Oblige。'+messia()
        elsif h > 18 && h < 22 then
            return 'なにやらお疲れのようですね。Noblesse Oblige。早めにお休みになってください。'
        elsif h > 2 && h < 7 then
            return '今夜は徹夜ですか？Noblesse Oblige。無理なさらないで下さいね。'
        else
            return '無理せずにお休みになったほうがよろしいのでは。Noblesse Oblige。'+messia()
        end
    end

    ## Normal Message
    def noword(text)
        nw = @normal['noword']
        if text.match(/[\?？]$/) then
            nw += @normal['noword_hatena']
        end
        return nw.choice()
    end
    def longtext
        return @normal['longtext'].choice()
    end
    def overmoney
        return @normal['overmoney'].choice()
    end
    def overmillion
        oblige = @normal['oblige'].choice().strip
        om = @normal['overmillion'].choice()
        return oblige+om
    end
    def zeromoney
        return @normal['zeromoney'].choice()
    end
    def wantto(text)
        if text.match(/(かってき|買って|何か|なにか|たべたい|食べたい|をお願い)/) then
            return @normal['wantto'].choice()
        end
        return ''
    end

    def receive
        accept = @normal['accept'].choice()
        oblige = @normal['oblige'].choice().strip
        if @lang == 'us' then
            accept = 'Understood.'
            oblige = ' '
        elsif @lang == 'cn' then
            accept = '已受理，'
            oblige = 'noblesse oblige，'
        elsif @lang == 'ko' then
            accept = ''
            oblige = 'Noblesse Oblige. '
        end
        return accept+oblige
    end

    def messia
        messia = @normal['messia'].choice()
        if @lang == 'us' then
            messia = 'I pray for your continuing service as a savior.'
        elsif @lang == 'cn' then
            messia = '請繼續履行救世主的義務'
        elsif @lang == 'ko' then
            messia = '앞으로도 당신이 구세주로써 변함이 없기를..'
        end
        return messia
    end

    ## Character Message
    def tachikomabot
        tachikoma = @character['tachikoma']
        return tachikoma.choice()
    end
    def no2(text)
        if text.match(/聞きたい？/) then
            return '是非聞きたいわ！ #realEOTE '
        elsif text.match(/国家ぐるみで.*分かる/) then
            return 'ええ、分かるわ2G。 #realEOTE '
        elsif text.match(/被害者最強/) then
            return '素晴らしいわ、2G。わたしゾクゾクしちゃう。 #realEOTE '
        elsif text.match(/帰国早々/) then
            return 'Yes, 2G。いつまでもカッティング・エッジーな救世主たらんことを。……ところで、どうやって彼にTシャツを？ #realEOTE '
        else
            no2 = @character['no2']
            return no2.choice()
        end
    end
    def no7(text)
        if text.match(/片棒/) then
            return 'いえ、いいんです。あなたのお役に立てるのなら……'
        elsif text.match(/え？/) then
            return 'すみません……忘れてください。'
        elsif text.match(/告白/) then
            return 'ほ、本当ですか！'
        else
            no7 = @character['no7']
            return no7.choice()
        end
    end
    def no10
        no10 = @character['no10']
        return no10.choice()
    end

    def generate(showtext, showmoney, message)
        twit = ''
        if @screen_name != '' then
            twit += '@'+@screen_name+' '
        end
        if showtext then
            if @lang != 'ja' then
                twit += '"'+@text+'" '
            else
                twit += '「'+@text+'」'
            end
        end
        if message != nil then
            twit += message+' '
        end
        if showmoney && @money > 0 then
            if @lang == 'us' then
                twit += '[Price:$'+money_format(@money/85)+']'
            elsif @lang == 'cn' then
                if @time_zone == 'Hong Kong' then
                    twit += '[金額:HK$'+money_format(@money/12)+']'
                elsif @time_zone == 'Taipei' then
                    twit += '[金額:NT$'+money_format(@money/3)+']'
                else
                    twit += '[金額:'+money_format(@money/14)+'元]'
                end
            elsif @lang == 'ko' then
                twit += '[금액:'+money_format(@money*13)+'원]'
            else
                twit += '[金額:'+money_format(@money)+'円]'
            end
        end
        return twit
    end
    def money_format(num)
        return (num.to_s =~ /[-+]?\d{4,}/) ? (num.to_s.reverse.gsub(/\G((?:\d+\.)?\d{3})(?=\d)/, '\1,').reverse) : num.to_s
    end

    def setinfo(screen_name, text = nil)
        if screen_name != '' then
            @screen_name = screen_name
        end
        if text != nil then
            @text = text
        end
    end
    def setlang(lang, time_zone)
        @lang = lang
        @time_zone = time_zone
    end
    def setmessage(message)
        if message != nil then
            @message = message
        end
    end
    def setmoney(money)
        if money != nil then
            @money = money
        end
    end
end
