require 'open-uri'
require 'json' if RUBY_VERSION < '1.9.0'
require 'rexml/document'

class Yahooapis
    def initialize
        path = '/home/flyeagle/call_juiz/'
        yaml = YAML::load_file(path+'accesskey.yaml')
        @appid = yaml['yahooapis']['appid']
    end

    def daservice(sentence)
        api_url  = 'http://jlp.yahooapis.jp/DAService/V1/parse?'
        api_url += 'appid='+@appid
        api_url += '&sentence='+sentence

        enc_uri = URI.encode(api_url)
        f = open(enc_uri)
        xml = f.read
        f.close

        return xml
    end

    # 現在使われておりません
    def chiebukuro(query)
        api_url  = 'http://chiebukuro.yahooapis.jp/Chiebukuro/V1/questionSearch?'
        api_url += 'appid='+@appid
        api_url += '&query='+query
        api_url += '&condition=solved'
        api_url += '&posteddevice=pc'
        api_url += '&results=20'

        enc_uri = URI.encode(api_url)
        f = open(enc_uri)
        xml = f.read
        f.close

        return xml
    end

    def websearch(query, start = '1', type = 'kakaku')
        ret = []
        if !query then
            return ret
        end

        api_url  = 'http://search.yahooapis.jp/WebSearchService/V2/webSearch?'
        api_url += 'appid='+@appid
        api_url += '&query='+query
        if type == 'kakaku' then
            api_url += ' 円'
        end
        api_url += '&start='+start
        api_url += '&results=20'
        api_url += '&format=xml'
        if type == 'chie' then
            api_url += '&site=detail.chiebukuro.yahoo.co.jp'
        else
            api_url += '&site=item.rakuten.co.jp'
        end

        enc_uri = URI.encode(api_url)
        f = open(enc_uri)
        xml = f.read
        xml = xml.gsub('(\r|\n|\r\n|\s)+', '')
        f.close

        return xml
    end

    def shorten_url(long_url)
        api_url  = 'http://api.bit.ly/shorten?'
        api_url += 'longUrl='+long_url
        api_url += '&login=flyeagle'
        api_url += '&apiKey=R_79b5ab47d6180cdcb141cc1318167041'
        api_url += '&version=2.0.1'

        enc_uri = URI.encode(api_url)
        f = open(enc_uri)
        json = f.read
        f.close

        result = JSON.parse(json)
        result['results'].each_pair {|key, value|
            if key == long_url then
                return value['shortUrl']
            end
        }
        return long_url
    end

    def keyphrase(text)
        if text == nil then
            return ''
        end
        api_url  = 'http://jlp.yahooapis.jp/KeyphraseService/V1/extract?'
        api_url += 'sentence='+text
        api_url += '&appid='+@appid
        api_url += '&output=json'

        enc_uri = URI.encode(api_url)
        f = open(enc_uri)
        json = f.read
        f.close

        obj = JSON.parse(json)
        obj = obj.to_a.sort{|a, b|
            (b[1] <=> a[1]) * 2 + (a[0] <=> b[0])
        }
        ret = []
        obj.each {|keyphrase|
            if keyphrase[0] == 'Error' then
                next
            end
            ret.push(keyphrase[0])
        }
        return ret
    end
end

class WebSearch
    attr_accessor :list

    def parse(xml)
        @list = []
        doc = REXML::Document.new xml
        doc.elements.each('ResultSet/Result'){|result|
            if result.has_elements? then
                title = result.elements['Title'].text
                summary = result.elements['Summary'].text
                url = result.elements['Url'].text
                line = {'title' => title, 'summary' => summary, 'url' => url}
                @list.push(line)
            end
        }
    end

end

class Morphem
    attr_accessor :surface,:reading,:baseform,:pos,:feature

    def initialize(elements)
        @surface = elements['Surface'].text
        @reading = elements['Reading'].text
        @baseform = elements['Baseform'].text
        @pos = elements['POS'].text
        @feature = elements['Feature'].text
    end
end

class Chunk
    attr_accessor :id,:dependency,:morphemlist

    def initialize(elements)
        @id = elements['Id'].text
        @dependency = elements['Dependency'].text
        @morphemlist = []
        elements.each('MorphemList/Morphem') {|result|
            m = Morphem.new(result.elements)
            @morphemlist.push(m)
        }
    end

    def surfaces
        ret = []
        @morphemlist.each {|m|
            ret.push(m.surface)
        }
        return ret
    end

    def poss
        ret = []
        @morphemlist.each {|m|
            ret.push(m.pos)
        }
        return ret
    end
end

class DAService
    attr_accessor :chunklist

    def parse(xml)
        @chunklist = []
        doc = REXML::Document.new xml
        doc.elements.each('ResultSet/Result/ChunkList/Chunk'){|result|
            if result.has_elements? then
                e = Chunk.new(result.elements)
                @chunklist[e.id.to_i] = e
            end
        }
    end

    def normal(n = 1, type = 'surface')
        retlist = []
        chunklist.each {|c|
            tmp = []
            t = c.id.to_i
            if t + n > chunklist.length then
                break
            end
            for i in 1..n
                if type == 'pos' then
                    tmp.push(chunklist[t].poss)
                else
                    tmp.push(chunklist[t].surfaces)
                end
                t = c.dependency.to_i
                if t == -1 then
                    break
                end
            end
            retlist.push(tmp)
        }
        return retlist
    end
end

