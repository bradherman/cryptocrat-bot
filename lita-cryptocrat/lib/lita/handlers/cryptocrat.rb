require 'json'
require 'httparty'

module Lita
  module Handlers
    class Cryptocrat < Handler
      route(/![A-Z]{1,5}/, :coin_info, command: false, help: {
        "!SYM" => "Replies with info about coin."
      })

      route(/^top/, :top, command: true, help: {
        ".top [X]" => "Replies with info on top X or 5 coins"
      })

      route(/price/, :price, command: true, help: {
        ".price [COIN] [CURRENCY] [exchange]" => "Replies with price on exchange or global average"
      })

      def price(response)
        coin      = response.args.shift
        currency  = response.args.find{ |x| x =~ /[A-Z]+/ } || 'USD'
        exchange  = response.args.find{ |x| x =~ /[a-z]+/ } || 'CCCAGG'

        url   = "https://min-api.cryptocompare.com/data/price?fsym=#{ coin }&tsyms=#{ currency }&e=#{ exchange }"
        resp  = HTTParty.get(url)
        price = JSON.parse(resp.body)
        msg   = "#{ coin }: #{ price[currency] }#{ currency }"

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

        coins.each do |coin|
          price_usd = commas(coin['price_usd'])
          price_btc = commas(coin['price_btc'])
          mc_usd    = commas(coin['market_cap_usd'])
          available = commas(coin['available_supply'])
          max       = commas(coin['max_supply'])
          pct_hr    = percent(coin['percent_change_1h'])
          pct_d     = percent(coin['percent_change_24h'])
          pct_w     = percent(coin['percent_change_7d'])

          msg += "#{ coin['name'] }: #{ coin['symbol'] } - $#{ price_usd } / ฿#{ price_btc }\n"
          msg += "#{ pct_hr }%/hr - #{ pct_d }%/d - #{ pct_w }%/w\n"
          msg += "Market Cap: $#{ mc_usd }\n"
          msg += "Supply: #{ available } / #{ max }\n\n"
        end

        if response.message.body.include?('-p')
          response.reply_privately msg
        else
          response.reply msg
        end
      end

      def coin_info(response)
        coin  = response.match_data[0].strip.sub('!', '')
        tsyms = ['USD', 'ETH', 'BTC']
        tsyms.delete(coin)
        url   = "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=#{ coin }&tsyms=#{ tsyms.join(',') }"
        resp  = HTTParty.get(url)

        info  = JSON.parse(resp.body)['DISPLAY'][coin]
        msg   = "#{ coin }: "

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
        msg += "- MC: #{ cap } - H: #{ high } / L: #{ low } / #{ pct }%"

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
