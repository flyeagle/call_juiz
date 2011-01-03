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
        @character = YAML::load_file(path+'juiz_character.yaml') 

        @screen_name = ''
        @text = ''
        @lang = 'ja'
        @time_zone = 'Tokyo'
        @message = ''
        @money = 0
    end

    ## Character Message
    def tachikomabot
        tachikoma = @character['tachikoma']
        return tachikoma.choice()
    end
    def no2(text)
        if text.match(/聞きたい？/) then
            return '是非聞きたいわ！'
        elsif text.match(/分かる.*ジュイス/) then
            return 'ええ、分かるわ、2G。'
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

    ## Seasonal Message
    def newyear
        return @season['newyear'].choice()
    end
    def tanzaku
        return @season['tanzaku'].choice()
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
        if showmoney then
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
                twit += '[금액:'+money_format(@money*13)+'₩]'
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
