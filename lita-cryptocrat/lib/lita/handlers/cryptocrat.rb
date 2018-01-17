require 'json'
require 'httparty'
require 'active_support/core_ext/numeric/time'

module Lita
  module Handlers
    class Cryptocrat < Handler
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

      route(regex_for(:coin_info),  :coin_info, command: false, help: help_for(:coin_info))
      route(regex_for(:top),        :top,       command: true,  help: help_for(:top))
      route(regex_for(:price),      :price,     command: true,  help: help_for(:price))
      route(regex_for(:calendar),   :calendar,  command: true,  help: help_for(:calendar))
      route(regex_for(:global),     :global,    command: true,  help: help_for(:global))

      def global(response)
        url   = 'https://api.coinmarketcap.com/v1/global/'
        resp  = HTTParty.get(url)
        data  = JSON.parse(resp.body)

        msg   = ""

        total_mc = data['total_market_cap_usd']
        active   = data['active_currencies']

        msg += "*Total Market Cap*: $#{ total_mc }\n"
        msg += "*Active Coins*: #{ active }"

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
      end

      def price(response)
        args      = response.args
        coin      = args.shift.upcase
        currency  = args.find{ |x| x =~ /[a-zA-Z]+/ } || 'USD'
        exchange  = args.find{ |x| x =~ /e:[a-zA-Z]+/ } || 'CCCAGG'
        exchange.gsub!('e:','')
        exchange  = exchange.upcase
        time      = args.find{ |x| x =~ /\d+\.\w+/ }

        if time
          time  = eval("#{ time }.ago")
          url   = "https://min-api.cryptocompare.com/data/pricehistorical?fsym=#{ coin }&tsyms=#{ currency }&ts=#{ time.to_i }"
          resp  = HTTParty.get(url)
          price = JSON.parse(resp.body)
          msg   = "*#{ coin }*: #{ price[coin][currency] }#{ currency } - (_#{ time.strftime('%D - %T') }_)"
        else
          url   = "https://min-api.cryptocompare.com/data/price?fsym=#{ coin }&tsyms=#{ currency }&e=#{ exchange }"
          resp  = HTTParty.get(url)
          price = JSON.parse(resp.body)
          msg   = "*#{ coin }*: #{ price[currency] }#{ currency }"
        end

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
      end

      def top(response)
        limit = response.args.first || 5
        url   = "https://api.coinmarketcap.com/v1/ticker/?limit=#{ limit }"
        resp  = HTTParty.get(url)
        coins = JSON.parse(resp.body)
        msg   = ""

        global_url  = 'https://api.coinmarketcap.com/v1/global/'
        resp        = HTTParty.get(url)
        global      = JSON.parse(resp.body)
        total_mc    = global['total_market_cap_usd']

        coins.each do |coin|
          pct_of_market = sprintf("%0.2f", percent(coin['price_usd'] / total_mc))
          price_usd = commas(coin['price_usd'])
          price_btc = commas(coin['price_btc'])
          mc_usd    = commas(coin['market_cap_usd'])
          available = commas(coin['available_supply'])
          max       = commas(coin['max_supply'])
          pct_hr    = percent(coin['percent_change_1h'])
          pct_d     = percent(coin['percent_change_24h'])
          pct_w     = percent(coin['percent_change_7d'])

          msg += "*#{ coin['name'] }*: #{ coin['symbol'] } - $#{ price_usd } / ฿#{ price_btc }\n"
          msg += "   *Percent of Total Market*: #{ pct_of_market }%"
          msg += "   *Change*: #{ pct_hr }%/hr - #{ pct_d }%/d - #{ pct_w }%/w\n"
          msg += "   *Market Cap*: $#{ mc_usd }\n"
          msg += "   *Supply*: #{ available } / #{ max }\n\n"
        end

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
      end

      def coin_info(response)
        coin  = response.match_data[0].strip.sub('!', '').upcase
        tsyms = ['USD', 'ETH', 'BTC']
        tsyms.delete(coin)
        url   = "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=#{ coin }&tsyms=#{ tsyms.join(',') }"
        resp  = HTTParty.get(url)

        info  = JSON.parse(resp.body)['DISPLAY'][coin]
        msg   = "*#{ coin }*: "

        price_usd, price_eth, price_btc = nil, nil, nil

        price_usd = info['USD']['PRICE'].gsub(' ', '')
        price_eth = info['ETH']['PRICE'].gsub(' ', '') if info['ETH']
        price_btc = info['BTC']['PRICE'].gsub(' ', '') if info['BTC']

        high = info['USD']['HIGH24HOUR'].gsub(' ', '')
        low  = info['USD']['LOW24HOUR'].gsub(' ', '')
        cap  = info['USD']['MKTCAP'].gsub(' ', '')
        pct  = percent(info['USD']['CHANGEPCT24HOUR'])

        msg += "#{ price_usd } "
        msg += "/ #{ price_eth } " if price_eth
        msg += "/ #{ price_btc } " if price_btc
        msg += "- *MC*: #{ cap } - *H*: #{ high } / *L*: #{ low } / #{ pct }%"

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
      end

      def calendar(response)
        coins_url = "https://coinmarketcal.com/api/coins"
        resp      = HTTParty.get(coins_url)
        coins     = JSON.parse(resp.body)
        coin      = response.args.first
        coin      = coins.find{ |c| c.include?("(#{ coin })") }
        cal_url   = "https://coinmarketcal.com/api/events?page=1&max=10&coins=#{ coin }&showPastEvent=false"
        resp      = HTTParty.get(cal_url)
        events    = JSON.parse(resp.body)
        msg       = ""

        events.select{ |event| event['percentage'] > 60 }.each do |event|
          title       = event['title']
          date        = Time.parse(event['date_event'])
          description = event['description']
          proof_url   = event['proof']
          categories  = event['categories']

          msg += "*<!date^#{ date.to_i }^{date_short}|Unknown>*: <#{ proof_url }|#{ title }>\n"
        end

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
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

