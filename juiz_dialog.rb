require 'rtranslate'
require 'yahooapis.rb'
require 'juiz_message.rb'
require 'kconv'
$KCODE = 'utf-8'

class Juizdialog
    # 計算に入れる単語の数
    SELECT_WORD = 4

    def initialize(status)
        @ydn = Yahooapis.new
        @jms = Juizmessage.new

        # 原材料
        @status = status
        @screen_name = status['user']['screen_name']
        @text = cleanup(status['text'])
        @time_zone = status['user']['time_zone']
        @orig_text = ''

        # 途中生成物
        @lang = 'ja'
        @words = []
        @money = 0
        @url = ''
        @showtext = true
        @showmoney = true

        # 最終生成物
        @juiz_suffix = ''
        @twit = ''
    end

    def gettext
        @text
    end
    def gettwit
        @twit
    end

    def dialog
        @jms.setinfo(@screen_name, @text)
        examlang()
        @jms.setlang(@lang, @time_zone)

        examprice()
        @jms.setmoney(@money)
puts @words
puts @money
        gendialog()
    end

    def gendialog
        if @words.length < 1 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.noword(@text)
        elsif @money > 1000000000000 then
            @juiz_suffix = @jms.overmoney
        elsif @money > 10000000 then
            if @juiz_suffix == '' then
                @juiz_suffix = @jms.overmillion
            end
        elsif @money == 0 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.zeromoney
        elsif @words.length == 1 && @url != '' && (wantto = @jms.wantto(@text)) != '' then
            @juiz_suffix = wantto+' '+@url
        else
            @juiz_suffix = @jms.receive+@jms.messia
        end
        @twit = @jms.generate(@showtext, @showmoney, @juiz_suffix)
    end

    def examlang
        if @text.match(/^[0-9a-zA-Z !"#\$%&'()*+-.\/:;<=>?@\[\\\]^_`{\|}~]+$/) && !@text.match(/merry.*mas/i) then
            @lang = 'us'
            @orig_text = @text
            @text = Translate.t(@text, Language::ENGLISH, Language::JAPANESE)
        elsif (@time_zone == 'Beijing' || @time_zone == 'Hong Kong' || @time_zone == 'Chongqing' || @time_zone == 'Taipei') && !@text.match(/[ぁ-ん]/) then
            @lang = 'cn'
            @orig_text = @text
            @text = Translate.t(@text, Language::CHINESE, Language::JAPANESE)
        elsif @time_zone == 'Seoul' && !@text.match(/[ぁ-ん]/) then
            @lang = 'ko'
            @orig_text = @text
            @text = Translate.t(@text, Language::KOREAN, Language::JAPANESE)
        end
    end

    def examprice
        # ジュイスを抜く
        ext = @text.sub(/^(juiz|ジュイス|じゅいす)(\s|　|、|,|)/i, '')
puts ext
        # 単語を抜き出す
        keywords = @ydn.keyphrase(ext)
        # 前から選ぶ
        @words = keywords[0,SELECT_WORD]
        @words.each do |word|
            if word.match(/[ !"#\$%&'()*+-.\/:;<=>?@\[\\\]^_`{\|}~]/) then
                next
            end
            if word == 'ジュイス' then
                next
            end
            pricebox = get_kakaku(word)
puts pricebox
            price = pricebox['price']
            if price != nil && price > 0 then
                @url = pricebox['url']
            else
                next
            end
            prand = rand(100)
            if @money == 0 then
                @money += price
            elsif price > 10 && prand > 85 then
                @money = @money * price
            elsif price > 100 && prand > 60 then
                @money = @money * (price / 10)
            elsif price > 1000 && prand > 40 then
                @money = @money * (price / 100)
            else
                @money += price
            end
        end
    end

    def get_kakaku(word)
        xml = @ydn.websearch(word, '1', 'kakaku')
        w = WebSearch.new
        w.parse(xml)

        yentourl = []
        yens = []

        w.list.each do |result|
            if result['summary'] != nil && result['summary'].match(/[0-9,]+円/) then
                k = result['summary'].sub(/^.*?([0-9,]+)円.*$/, '\1')
                k = k.sub(/,/, '')
                k_dec = k.to_i
                if k_dec > 0 then
                    yentourl[k_dec] = result['url']
                    yens.push(k_dec)
                end
            end
        end

        median = 0
        yens.sort!
        if yens.length > 0 then
            m = ((yens.length + 1) / 2).floor
            median = yens[m]
        end

        url = ''
        if median != nil && median > 0 then
            url = yentourl[median]
        end

        return {'word' => word, 'url' => url, 'price' => median}
    end

    def cleanup(text)
        # 最初にジュイスが出てくるか、文章になるまで回す
        ptext = ''
        while ptext != text
            if text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)/) then
                break
            end
            ptext = text
            text = text.sub(/^[\s　\.]+/, '')
            text = text.sub(/^(@|＠)[a-zA-Z0-9_]+/, '')
            text = text.sub(/^[\s　\.]+/, '')
        end
        # もしジュイス宛ではなかったらfalse
        if !text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/) then
            return nil
        end
        text = text.sub(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/, '')
        text = text.sub(/^[\s　]+/, '')
        text = text.sub(/[\s　]+$/, '')
        # フッタ処理
        text = text.sub(/\[.+\]$/, '')
        text = text.sub(/\*.+\*$/, '')
        # RT処理
        text = text.gsub(/RT @/, 'RT @ ')
        # URL処理
        uris = URI.extract(text)
        uris.each {|uri|
            text = text.sub(uri, '')
        }
        return text
    end
end
