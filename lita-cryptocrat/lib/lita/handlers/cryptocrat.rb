require 'json'
require 'httparty'
require 'active_support/core_ext/numeric/time'

module Lita
  module Handlers
    class Cryptocrat < Handler
      include HTTParty

      format :json

      COMMANDS = {
        coin_info: {
          regex: /![a-zA-Z]{1,5}/,
          help: {
            '!SYM' => 'Replies with basic info about the coin.'
          }
        },
        top: {
          regex: /^top/,
          help: {
            '.top [X]' => 'Replies with info on top X or 5 coins'
          }
        },
        price: {
          regex: /price/,
          help: {
            '.price [COIN] [CURRENCY] e:[exchange]' => 'Replies with price on exchange or global average'
          }
        },
        calendar: {
          regex: /cal [a-zA-Z]{1,5}/,
          help: {
            '.cal [COIN]' => 'Replies with upcoming events for the coin.'
          }
        },
        global: {
          regex: /global/,
          help: {
            '.global' => 'Replies with data about the global crypto market.'
          }
        }
      }

      def self.regex_for(name)
        COMMANDS[name][:regex]
      end

      def self.help_for(name)
        COMMANDS[name][:help]
      end

      attr_accessor :reply_message

      def initialize(*args)
        @reply_message = ""
        super
      end

      route(regex_for(:coin_info),  :coin_info, command: false, help: help_for(:coin_info))
      route(regex_for(:top),        :top,       command: true,  help: help_for(:top))
      route(regex_for(:price),      :price,     command: true,  help: help_for(:price))
      route(regex_for(:calendar),   :calendar,  command: true,  help: help_for(:calendar))
      route(regex_for(:global),     :global,    command: true,  help: help_for(:global))

      GLOBAL_URI    = 'https://api.coinmarketcap.com/v1/global/'
      CAL_COINS_URI = 'https://coinmarketcal.com/api/coins'

      def historical_price_uri(time:, coin:, currency:)
        "https://min-api.cryptocompare.com/data/pricehistorical?fsym=#{ coin }&tsyms=#{ currency }&ts=#{ time.to_i }"
      end

      def price_uri(coin:, currency:, exchange:)
        "https://min-api.cryptocompare.com/data/price?fsym=#{ coin }&tsyms=#{ currency }&e=#{ exchange }"
      end

      def ticker_uri(limit:)
        "https://api.coinmarketcap.com/v1/ticker/?limit=#{ limit }"
      end

      def multiprice_uri(coins:, tsyms:)
        "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=#{ coins.join(',') }&tsyms=#{ tsyms.join(',') }"
      end

      def calendar_uri(coin:)
        "https://coinmarketcal.com/api/events?page=1&max=10&coins=#{ coin }&showPastEvent=false"
      end

      def respond!
        if @response.message.body.include?('-p')
          @response.reply_privately @reply_message
        else
          @response.reply @reply_message
        end
      end

      def global(input_message)
        @response = input_message

        data      = self.class.get(GLOBAL_URI)

        total_mc  = commas(data['total_market_cap_usd'])
        active    = commas(data['active_currencies'])

        @reply_message += "*Total Market Cap*: $#{ total_mc }\n"
        @reply_message += "*Active Coins*: #{ active }"

        respond!
      end

      def price(input_message)
        @response = input_message

        args      = input_message.args
        coin      = args.shift.upcase
        currency  = args.find{ |x| x =~ /[a-zA-Z]+/ } || 'USD'
        exchange  = args.find{ |x| x =~ /e:[a-zA-Z]+/ } || 'CCCAGG'
        exchange.gsub!('e:','')
        exchange  = exchange.upcase
        time      = args.find{ |x| x =~ /\d+\.\w+/ }

        if time
          time          = eval("#{ time }.ago")
          price         = self.class.get(historical_price_uri(time: time, coin: coin, currency: currency))
          @reply_message = "*#{ coin }*: #{ price[coin][currency] }#{ currency } - (_#{ time.strftime('%D - %T') }_)"
        else
          price         = self.class.get(price_uri(coin: coin, currency: currency, exchange: exchange))
          @reply_message = "*#{ coin }*: #{ price[currency] }#{ currency }"
        end

        respond!
      end

      def top(input_message)
        @response = input_message

        limit     = input_message.args.first || 5
        coins     = self.class.get(ticker_uri(limit: limit))
        global    = self.class.get(GLOBAL_URI)
        total_mc  = global['total_market_cap_usd']

        coins.each do |coin|
          pct_of_market = sprintf("%0.2f", (coin['market_cap_usd'].to_f / total_mc.to_f) * 100)
          price_usd = commas(coin['price_usd'])
          price_btc = commas(coin['price_btc'])
          mc_usd    = commas(coin['market_cap_usd'])
          available = commas(coin['available_supply'])
          max       = commas(coin['max_supply'])
          pct_hr    = percent(coin['percent_change_1h'])
          pct_d     = percent(coin['percent_change_24h'])
          pct_w     = percent(coin['percent_change_7d'])

          @reply_message += "*#{ coin['name'] }*: #{ coin['symbol'] } - $#{ price_usd } / ฿#{ price_btc }\n"
          @reply_message += "   *Percent of Total Market*: #{ pct_of_market }%\n"
          @reply_message += "   *Change*: #{ pct_hr }%/hr - #{ pct_d }%/d - #{ pct_w }%/w\n"
          @reply_message += "   *Market Cap*: $#{ mc_usd }\n"
          @reply_message += "   *Supply*: #{ available } / #{ max }\n\n"
        end

        respond!
      end

      def coin_info(input_message)
        @response = input_message

        price_usd, price_eth, price_btc = nil, nil, nil

        coins = input_message.message.body.split(' ').select{ |arg| arg =~ self.class.regex_for(:coin_info) }
        coins.map!{ |arg| arg.strip.sub('!', '').upcase }
        tsyms = ['USD', 'ETH', 'BTC']

        info  = self.class.get(multiprice_uri(coins: coins, tsyms: tsyms))['DISPLAY']

        coins.each do |coin|
          @reply_message += "*#{ coin }*: "

          price_usd = info[coin]['USD']['PRICE'].gsub(' ', '')
          price_eth = info[coin]['ETH']['PRICE'].gsub(' ', '') if coin != 'ETH'
          price_btc = info[coin]['BTC']['PRICE'].gsub(' ', '') if coin != 'BTC'

          high = info[coin]['USD']['HIGH24HOUR'].gsub(' ', '')
          low  = info[coin]['USD']['LOW24HOUR'].gsub(' ', '')
          cap  = info[coin]['USD']['MKTCAP'].gsub(' ', '')
          pct  = percent(info[coin]['USD']['CHANGEPCT24HOUR'])

          @reply_message += "#{ price_usd } "
          @reply_message += "/ #{ price_eth } " if price_eth
          @reply_message += "/ #{ price_btc } " if price_btc
          @reply_message += "- *MC*: #{ cap } - *H*: #{ high } / *L*: #{ low } / #{ pct }%\n"
        end

        respond!
      end

      def calendar(input_message)
        @response = input_message

        coins     = self.class.get(CAL_COINS_URI)
        coin      = input_message.args.first
        coin      = coins.find{ |c| c.include?("(#{ coin })") }

        if coin
          events  = self.class.get(calendar_uri(coin: coin))
          events.select{ |event| event['percentage'] > 60 }.each do |event|
            title       = event['title']
            date        = Time.parse(event['date_event'])
            description = event['description']
            proof_url   = event['proof']
            categories  = event['categories']

            @reply_message += "*<!date^#{ date.to_i }^{date_short}|Unknown>*: <#{ proof_url }|#{ title }>\n"
          end
        else
          @reply_message = "Could not find coin on coinmarketcal.com."
        end

        respond!
      end

      # # # # # # # #

      def commas(str)
        str.to_s =~ /([^\.]*)(\..*)?/
        int, dec = $1.reverse, $2 ? $2 : ""
        while int.gsub!(/(,|\.|^)(\d{3})(\d)/, '\1\2,\3')
        end
        int.reverse + dec
      end

      def percent(str)
        pct = str.to_f
        pct > 0 ? "+#{ str }" : str
      end

      Lita.register_handler(self)
    end
  end
end

