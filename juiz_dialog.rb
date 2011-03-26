require 'rubygems'
require 'easy_translate'
require '/home/flyeagle/call_juiz/yahooapis.rb'
require '/home/flyeagle/call_juiz/juiz_message.rb'
require 'kconv'
$KCODE = 'utf-8'

# 使っている情報は今4つ
# @screen_name
# @text
# @lang
# @time_zone

# examlang で言語判定
# タイムゾーンと、ひらがなのあるなし

# examprice で値段判定
# 単語4つの値段を足したり掛けたりして合計金額まで出す

# gendialog で台詞決定
## Special Message
### DBがないと動けないもの

## Gourmet Message
### 食べもの、飲み物、寒い

## Seasonal Message
### あけおめ、めりくり、たなばた

## Neta Message

## Text Message
### 普通の東のエデンの反応

## Greetings Message
### ありがとう、おめでとう

## Normal Message
### 値段がない、ワードがない、100万こえたなど

## Character Message
### タチコマ、7番、2番、10番

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
        @text_length = @text.split(//u).length
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
    def getmoney
        @money
    end

    def dialog
        @jms.setinfo(@screen_name, @text)
        examlang()
        @jms.setlang(@lang, @time_zone)

        examprice()

        gendialog()
    end

    def gendialog
        ## Special Message
        # TODO: 既に100億使い切っている人 after summation
#        if @text.match(/(今日|本日|きょう)の最高金額/) then
            # TODO after db
#        elsif @text.match(/(今日|本日|きょう)の最低金額/) then
            # TODO after db
#        elsif @text.match(/残(金|額|高|りの金額).*(いくら|教えて|わかる|は？)/) then
            # TODO after db
#        elsif @text.match(/(明日|あした|今月|本日|今日)の予定は(？|\?)/) then
            # TODO
#        elsif @text.match(/教えて/) && !@text.match(/教えて(くれた|やって)/) then
            # TODO
        if @text.match(/(と|って|て)(言って|諭して)[^た]/) then
            tmp = @text.sub(/^.*(「|『)(.+)(』|」)(と|って|て)(言って|諭して).*/, '\2')
            if tmp == @text then
                tmp = @text.sub(/^.*(、|。|・)(.+)(と|って|て)(言って|諭して).*/, '\2')
                if tmp != @text then
                    @showtext = false
                    @juiz_suffix = '「'+tmp+'」…これでよろしいでしょうか？'
                    @money = 1000
                end
            else
                @showtext = false
                @juiz_suffix = '「'+tmp+'」…これでよろしいでしょうか？'
                @money = 1000
            end

        ## Gourmet Message
        elsif (@text.match(/((なに|何)か).*(のみ|飲み)(もの|物).*(を|のみたい|飲みたい|ほしい|欲しい|ちょうだい|頂戴|お願い|おねがい)/) || @text.match(/(喉|のど).*(渇|乾|かわ)いた/)) then
            drink = @jms.gourmet_drink
            if @text.match(/(冷|つめ)たい/) then
                drink = @jms.gourmet_drink_cold
            elsif @text.match(/(あったか|あたた|温|暖)/) then
                drink = @jms.gourmet_drink_hot
            end
            @juiz_suffix = drink['message']
            @money = drink['money']
        elsif (@text.match(/((なに|何)か).*(たべ|食べ|食べる)(もの|物).*(を|たべたい|食べたい|ほしい|欲しい|ちょうだい|頂戴|お願い|おねがい)/) || @text.match(/(おなか|お腹|はら|腹).*(すいた|へった|減った)/)) then
            food = @jms.gourmet_food
            @juiz_suffix = food['message']
            @money = food['money']
        elsif @text.match(/(さむ|寒)い.*なんとか/) || @text.match(/(さむ|寒)く.*(こま|困)/) then
            item = @jms.gourmet_winter
            @juiz_suffix = item['message']
            @money = item['money']

        ## Seasonal Message
        elsif @text.match(/(あけ|明け)(おめ|オメ|御目)/) || @text.match(/(こと|コト)(よろ|ヨロ)/) || @text.match(/(今年|ことし).*(よろし|宜しく|ヨロシク|夜露)/) || @text.match(/(あけま|明けま).*(おめで|オメデ|お目出|御目出)/) || @text.match(/(昨年|去年).*(ありがと|有難|アリガト|お世話|世話)/) then
            if @text_length < 20 then
                @showmoney = false
            end
            @juiz_suffix = @jms.newyear
        elsif @text.match(/#tanzaku/)  || @text.match(/よ(う|ー)に(|。)$/) || @text.match(/短冊/) then
            @juiz_suffix = @jms.tanzaku
        elsif @text.match(/(めり|メリ)(くり|クリ)/) && @text_length < 12 then
            @showmoney = false
            @juiz_suffix = 'Merry X\'mas。'+@jms.messia
        elsif @text.match(/(めりー|メリー|merry).*(くりすます|クリスマス|mas)/i) && @text_length < 18 then
            @showmoney = false
            @juiz_suffix = 'Merry X\'mas。'+@jms.messia

        ## Neta Message
        elsif @text.match(/えっ(|？)$/) then
            @showmoney = false
            @juiz_suffix = @jms.text_extu
        elsif @text.match(/(1|１|一)番(いい|良い).*頼む/) then
            @showmoney = false
            @juiz_suffix = 'Mr.Outside は言っています。ここでセレソンを諦めるべきではないと――'
        elsif @text.match(/(て|で)大丈夫か(\?|？|$)/) then
            @showmoney = false
            @juiz_suffix = '大丈夫です。きっと問題ありません。'
        elsif @text.match(/(ぬ|ヌ)(る|ル)(ぽ|ポ)/) then
            @showmoney = false
            @juiz_suffix = 'ガッ'
        elsif @text.match(/(昼|ひる)ぽ(|.|..)ー/) then
            @showmoney = false
            @juiz_suffix = '昼ぽっぽーですね。午後もあなたが救世主たらんことを。'
        elsif @text.match(/(夜|よる)ほ(|.|..)ー/) then
            @showmoney = false
            @juiz_suffix = '夜ほっほーですね。今夜もあなたが救世主たらんことを。'
        elsif @text.match(/爆発しろ！/) then
            @juiz_suffix = '"Bang!!!" …これでよろしいですか？'
            @money = 1000
        elsif @text.match(/しろ(。|！|$)/) || @text.match(/(ろ|やれ|れよ|ろよ)！$/) then
            @juiz_suffix = '受理しましたが…もう少し口のきき方をわきまえた救世主たらんことを！'
        elsif @text.match(/起こして/) then
            @juiz_suffix = @jms.receive+'良い夢を。'
            @money = 1000
        elsif @text.match(/(眠|ねむ)い/) then
            @money = 1100
            @juiz_suffix = @jms.feel_sleepy
        elsif @text.match(/単位.*く(れ|だ)/) && Kernel.rand(10) > 5 then
            @showmoney = false
            @juiz_suffix = 'さぁ。セレソンに単位を授与する基準をジュイスは聞かされておりませんので。'
        elsif @text.match(/内定.*く(れ|だ)/) then
            @juiz_suffix = 'みん就の書き込みの中から内定に最適な方法を抽出いたしました。Noblesse Oblige。'+@jms.messia
            @money = 10
        elsif @text.match(/(なお|直|治)して/) then
            @juiz_suffix = 'それは心配ですね。すぐに手配いたします。Noblesse Oblige。くれぐれもお大事に。'

        ## Text Message
        elsif @text.match(/(だれ|誰)？(きみ|君)/) then
            @showmoney = false
            @juiz_suffix = 'あなたのコンシェルジュです。'+@jms.messia
        elsif @text.match(/誰(|.|..)？/) || @text.match(/誰だか知ってるの？/) then
            @showmoney = false
            @juiz_suffix = '誰か？誰かということはわかりかねますが。'
        elsif @text.match(/って知ってる？/) then
            @showmoney = false
            @juiz_suffix = 'いいえ。お調べいたしますか？'
        elsif @text.match(/たの？/) then
            @showmoney = false
            @juiz_suffix = '申し訳ありません。その後については、把握しておりません。'
        elsif @text.match(/ってこと？/) then
            @showmoney = false
            @juiz_suffix = 'はい。ありていに言えばそういうことです。'
        elsif @text.match(/どこまで/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'どこまで、と言いますと？'
        elsif @text.match(/キャンセル(。|して|ね)/) || @text.match(/取り消し(。|て)/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'そうですか。少々惜しい気もします。'
        elsif @text.match(/(エレガント|華麗)(な|に)/) then
            @juiz_suffix = '心得ております。Noblesse Oblige。'+@jms.messia
        elsif @text.match(/言わせ/) then
            @juiz_suffix = @jms.receive+'テレビの前でお待ちください。'+@jms.messia
            @money = 60
        elsif @text.match(/(なん|何)(とか|でも)/) then
            @juiz_suffix = @jms.receive+'国家権力を笠に着てもなお誠実な救世主たらんことを。'
        elsif @text.match(/シャンパン/) then
            @showtext = false
            @juiz_suffix = '今宵ゲームの勝者は決定しませんでした。したがって祝杯は後ほど。Noblesse Oblige。Mr.Outsideの指示に従って、今後も救世主たるべくゲームを続行してください。'
        elsif @text.match(/この國には.*役回り/) || @text.match(/だって.*信じてくれた/) then
            @showtext = false
            @juiz_suffix = '…受理されました。Noblesse Oblige。今度会うときは素敵な王子様たらんことを。'
            @money = 10000
        elsif @text.match(/この国の王様にして/) then
            if Kernel.rand(10) > 5 then
                @juiz_suffix = '…受理されました。Noblesse Oblige。今度会うときは素敵な王子様たらんことを。'
                @money = 10000
            else
                @showmoney = false
                @juiz_suffix = '王様？ですか？'
            end
        elsif @text.match(/どう？/) || @text.match(/(のぶおり|ノブオリ)/) then
            @juiz_suffix = '素晴らしいわ '+@screen_name+' 。いつまでもカッティング・エッジーな救世主たらんことを。'
        elsif @text.match(/記憶を消して/) then
            if Kernel.rand(10) > 5 then
                @juiz_suffix = '…受理されました。ATO播磨脳科学研究所の洗脳プログラムをノブレス携帯へ転送します。'
                @money = 900
            else
                @showmoney = false
                @juiz_suffix = '本当によろしいのですか？'
            end
        elsif @text.match(/過去の履歴.*消/) then
            if Kernel.rand(10) > 5 then
                @juiz_suffix = '…受理されました。ノブレス携帯の全履歴を消去いたします。'
                @money = 40
            else
                @showmoney = false
                @juiz_suffix = '本当によろしいのですか？'
            end
        elsif @text.match(/ジョニーを/) then
            if Kernel.rand(10) > 4 then
                @showmoney = false
                @juiz_suffix = 'ジョニー…をですか？'
            else
                @juiz_suffix = @jms.receive+@jms.messia
            end
        elsif @text.match(/結婚し(て|よう)/) || @text.match(/一緒に/) then
            if Kernel.rand(10) > 3 then
                @showmoney = false
                @juiz_suffix = @jms.merry_fail
            else
                @money = 1000000
                @juiz_suffix = @jms.merry_success
            end

        ## Greetings Message
        elsif @text.match(/もういいよ/) then
            @showmoney = false
            @juiz_suffix = '了解しました。Noblesse Oblige。'+@jms.messia
        elsif @text.match(/ありがと/) || @text.match(/(すば|素晴)らしい！/) || @text.match(/サンキュ/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_thankyou
        elsif @text.match(/おめでとう/) && !@text.match(/おめでとう(」|って|と)/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_congrats
        elsif @text.match(/残念(|.|..|...|....)$/) && @text_length < 10 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'ご要望に沿えず、申し訳ございません…。'
        elsif @text.match(/(面白|おもしろ)かった(よ|！)/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = '楽しんでいただけてなによりです。Noblesse Oblige。'+@jms.messia
        elsif @text.match(/おはよ(う|ー)/) || @text.match(/おっはー/) || @text.match(/グッ.*モーニン/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_morning
        elsif @text.match(/おやすみ/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = @jms.text_sleep
        elsif @text.match(/こんばん(は|わ)/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = 'こんばんは。'+@jms.messia
        elsif @text.match(/こんにち(は|わ)/) || @text.match(/ご(きげん|機嫌)よう/) then
            if @text_length < 18 then
                @showtext = false
                @showmoney = false
            end
            @juiz_suffix = 'はい、ジュイスです。'+@jms.messia
        elsif @text.match(/ただいま/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'お帰りになられたのですね。何かご要望はございますか？'
        elsif @text.match(/(行|い)って(き|来)ま/) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'はい、お気をつけて。行ってらっしゃい！'
        elsif @text.match(/す(い|み)ません/) || @text.match(/(ゴメン|ごめん)(ネ|ね|なさい)/) then
            @juiz_suffix = @jms.text_sorry
            @money = Kernel.rand(10000)+10
        elsif @text.match(/お(つか|疲)れ(さん|さま|様|$)/) && @text_length < 13 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = 'お気遣いありがとうございます。'+@jms.messia

        ## Normal Message
        elsif @words.length < 1 then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.noword(@text)
        elsif @text_length > 65 && !(@text.match(/この国には.*役回り/) || @text.match(/だって.*信じてくれた/)) then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.longtext
        elsif @money > 10000000000 then
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

        ## Character Message
        if @screen_name == 'tachikomabot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.tachikomabot
        elsif @screen_name == '2G_bot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no2(@text)
        elsif @screen_name == 'no_7_kaoru_bot' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no7(@text)
        elsif @screen_name == 'SELECAO_10' then
            @showtext = false
            @showmoney = false
            @juiz_suffix = @jms.no10
        end

        if !@showmoney then
            @money = 0
        end

        @jms.setmoney(@money)
        @twit = @jms.generate(@showtext, @showmoney, @juiz_suffix)
    end

    def examlang
        if @text.match(/^[0-9a-zA-Z !"#\$%&'()*+-.\/:;<=>?@\[\\\]^_`{\|}~]+$/) && !@text.match(/merry.*mas/i) then
            @lang = 'us'
            @orig_text = @text
            @text = EasyTranslate.translate(@text, :to => :ja)
        elsif (@time_zone == 'Beijing' || @time_zone == 'Hong Kong' || @time_zone == 'Chongqing' || @time_zone == 'Taipei') && !@text.match(/[ぁ-ん]/) then
            @lang = 'cn'
            @orig_text = @text
            @text = EasyTranslate.translate(@text, :to => :ja)
        elsif @time_zone == 'Seoul' && !@text.match(/[ぁ-ん]/) then
            @lang = 'ko'
            @orig_text = @text
            @text = EasyTranslate.translate(@text, :to => :ja)
        end
    end

    def examprice
        # ジュイスを抜く
        ext = @text.sub(/^(juiz|ジュイス|じゅいす)(\s|　|、|,|)/i, '')
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
# debug
#puts pricebox
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
        # 改行を取る
        text = text.gsub(/[\r\n]/, '')
        # 最初にジュイスが出てくるか、文章になるまで回す
        ptext = ''
        while ptext != text
            if text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)/i) then
                break
            end
            ptext = text
            text = text.sub(/^[\s　\.]+/, '')
            text = text.sub(/^(@|＠)[a-zA-Z0-9_]+/, '')
            text = text.sub(/^[\s　\.]+/, '')
        end
        # もしジュイス宛ではなかったらfalse
        if !text.match(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/i) then
            return '' 
        end
        text = text.sub(/^(\.@|@|＠)(flyeagle_echo|call_juiz|ジュイス)( |　|、|,|)/i, '')
        text = text.sub(/^[\s　]+/, '')
        # フッタ処理
        text = text.sub(/\[.+\]$/, '')
        text = text.sub(/\*.+\*$/, '')
        # 文末空白処理
        text = text.sub(/[\s　]+$/, '')
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
