require 'rubygems'
require 'oauth'
require 'json' if RUBY_VERSION < '1.9.0'
require 'yaml'
require 'kconv'
$KCODE = 'utf-8'
require 'pp'

# OAuth接続で自分のfriendとfollowerを取得
# follower - friend はフォロー
# friend - follower は削除

class CallJuizFollow
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
    end 

    def run
        friends = get_ids('friends')
        followers = get_ids('followers')

        must_follow = followers - friends
        must_remove = friends - followers

#pp must_follow.length.to_s
#pp must_remove.length.to_s

        must_follow.each do |id|
            @access_token.post('/friendships/create.json',
                'user_id' => id
            )
#pp "followed "+id.to_s
            sleep 1
        end

#        must_remove.each do |id|
#            @access_token.post('/friendships/destroy.json',
#                'user_id' => id
#            )
#pp "removed "+id.to_s
#            sleep 1
#        end
    end

    def get_ids(command = 'friends')
        ids = []
        cursor = -1
        count = 0
        until cursor == 0 || count > 7 do
            response = @access_token.get('http://api.twitter.com/1/'+command+'/ids.json?'+
                    'screen_name='+SCREEN_NAME+
                    '&cursor='+cursor.to_s)
            JSON.parse(response.body).each do |arr|
                if arr[0] == 'ids' then
                    ids += arr[1]
                elsif arr[0] == 'next_cursor' then
                    cursor = arr[1]
                end
            end
            count += 1 # 保険
            sleep 1
        end
        return ids
    end
end

if $0 == __FILE__ then
    CallJuizFollow.new.run
end

