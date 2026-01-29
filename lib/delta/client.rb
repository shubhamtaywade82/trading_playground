# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'openssl'
require 'time'
require 'uri'

# REST client for Delta Exchange (India) v2 API.
# Docs: https://docs.delta.exchange
# Public endpoints need no auth; orders/wallet need api_key + signature.
class DeltaExchangeClient
  DEFAULT_BASE_URL = 'https://api.india.delta.exchange'

  def initialize(api_key: nil, api_secret: nil, base_url: nil)
    @api_key = api_key || ENV.fetch('DELTA_API_KEY', nil)
    @api_secret = api_secret || ENV.fetch('DELTA_API_SECRET', nil)
    @base_url = (base_url || ENV['DELTA_BASE_URL'] || DEFAULT_BASE_URL).chomp('/')
  end

  def authenticated?
    @api_key.to_s != '' && @api_secret.to_s != ''
  end

  # GET /v2/products — list products (optional filter: contract_types, states)
  def products(contract_types: nil, states: nil, page_size: nil, after: nil)
    params = {}
    params[:contract_types] = contract_types if contract_types
    params[:states] = states if states
    params[:page_size] = page_size if page_size
    params[:after] = after if after
    get('/v2/products', params)
  end

  # GET /v2/products/{symbol} — product by symbol (e.g. BTCUSD)
  def product(symbol)
    get("/v2/products/#{symbol}")
  end

  # GET /v2/tickers — all tickers; optional filter contract_types, underlying_asset_symbols
  def tickers(contract_types: nil, underlying_asset_symbols: nil)
    params = {}
    params[:contract_types] = contract_types if contract_types
    params[:underlying_asset_symbols] = underlying_asset_symbols if underlying_asset_symbols
    get('/v2/tickers', params)
  end

  # GET /v2/tickers/{symbol} — single ticker
  def ticker(symbol)
    get("/v2/tickers/#{symbol}")
  end

  # GET /v2/history/candles — OHLC (resolution: 1m, 5m, 1h, etc.; symbol, start, end in seconds)
  def candles(symbol:, start_ts:, end_ts:, resolution: '5m')
    get('/v2/history/candles', resolution: resolution, symbol: symbol, start: start_ts, end: end_ts)
  end

  # GET /v2/l2orderbook/{symbol}
  def orderbook(symbol, depth: nil)
    params = depth ? { depth: depth } : {}
    get("/v2/l2orderbook/#{symbol}", params)
  end

  # GET /v2/wallet/balances — requires auth
  def wallet_balances
    authenticated_request(:get, '/v2/wallet/balances')
  end

  # GET /v2/orders — active orders; requires auth
  def orders(product_ids: nil, states: nil)
    params = {}
    params[:product_ids] = product_ids if product_ids
    params[:states] = states if states
    authenticated_request(:get, '/v2/orders', params)
  end

  # POST /v2/orders — place order. Requires product_id or product_symbol, size, side, order_type.
  # limit_price required for limit_order; optional: time_in_force (gtc|ioc), client_order_id, reduce_only.
  def place_order(size:, side:, product_id: nil, product_symbol: nil, order_type: 'limit_order',
                  limit_price: nil, time_in_force: 'gtc', client_order_id: nil, reduce_only: false)
    payload = {
      size: size,
      side: side.to_s.downcase,
      order_type: order_type.to_s
    }
    payload[:product_id] = product_id if product_id
    payload[:product_symbol] = product_symbol if product_symbol
    payload[:limit_price] = limit_price.to_s if limit_price
    payload[:time_in_force] = time_in_force
    payload[:client_order_id] = client_order_id if client_order_id
    payload[:reduce_only] = reduce_only
    authenticated_request_with_body(:post, '/v2/orders', payload)
  end

  # DELETE /v2/orders — cancel by id or client_order_id; product_id required.
  def cancel_order(product_id:, id: nil, client_order_id: nil)
    payload = { product_id: product_id }
    payload[:id] = id if id
    payload[:client_order_id] = client_order_id if client_order_id
    authenticated_request_with_body(:delete, '/v2/orders', payload)
  end

  private

  def get(path, params = {})
    url = "#{@base_url}#{path}"
    opts = { accept: 'application/json' }
    opts[:params] = params if params.any?
    resp = RestClient.get(url, opts)
    parse_response(resp)
  end

  def parse_response(resp)
    body = resp.body
    return {} if body.nil? || body.strip.empty?

    JSON.parse(body)
  end

  def authenticated_request(method, path, params = {})
    raise 'Delta API key and secret required' unless authenticated?

    query_string = params.any? ? "?#{URI.encode_www_form(params)}" : ''
    url = "#{@base_url}#{path}#{query_string}"
    timestamp = Time.now.to_i.to_s
    signature = sign(method.to_s.upcase, path, query_string, '', timestamp)

    headers = auth_headers(timestamp, signature)
    resp = method == :get ? RestClient.get(url, headers) : nil
    raise 'Only GET implemented for authenticated_request' if resp.nil?

    parse_response(resp)
  end

  def authenticated_request_with_body(method, path, payload)
    raise 'Delta API key and secret required' unless authenticated?

    body = payload.is_a?(String) ? payload : payload.to_json
    query_string = ''
    timestamp = Time.now.to_i.to_s
    signature = sign(method.to_s.upcase, path, query_string, body, timestamp)

    url = "#{@base_url}#{path}"
    headers = auth_headers(timestamp, signature)

    resp = case method
           when :post then RestClient.post(url, body, headers)
           when :delete then RestClient::Request.execute(method: :delete, url: url, payload: body, headers: headers)
           else raise "Unsupported method: #{method}"
           end
    parse_response(resp)
  end

  def auth_headers(timestamp, signature)
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'api-key' => @api_key,
      'timestamp' => timestamp,
      'signature' => signature,
      'User-Agent' => 'ruby-delta-rest-client'
    }
  end

  def sign(method, path, query_string, body, timestamp)
    message = "#{method}#{timestamp}#{path}#{query_string}#{body}"
    OpenSSL::HMAC.hexdigest('SHA256', @api_secret, message)
  end
end
