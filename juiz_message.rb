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

        @screen_name = ''
        @text = ''
        @message = ''
        @money = 0
    end

    def noword(text)
        nw = @normal['noword']
        if text.match(/[\?？]$/) then
            nw += @normal['noword_hatena']
        end
        return nw.choice()
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
        return accept+oblige
    end

    def messia
        return @normal['messia'].choice()
    end

    def generate(showtext, showmoney, message)
        twit = ''
        if @screen_name != '' then
            twit += '@'+@screen_name+' '
        end
        if showtext then
            twit += '「'+@text+'」'
        end
        if message != nil then
            twit += message+' '
        end
        if showmoney then
            twit += '[金額: '+money_format(@money)+'円]'
        end
        return twit
    end
    def money_format(num)
        return (num.to_s =~ /[-+]?\d{4,}/) ? (num.to_s.reverse.gsub(/\G((?:\d+\.)?\d{3})(?=\d)/, '\1,').reverse) : num.to_s
    end

    def setinfo(screen_name, text = nil, money = nil)
        if screen_name != '' then
            @screen_name = screen_name
        end
        if text != nil then
            @text = text
        end
        if money != nil then
            @money = money
        end
    end
    def setmessage(message)
        if message != nil then
            @message = message
        end
    end
end
