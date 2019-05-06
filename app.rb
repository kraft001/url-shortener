require 'sinatra/base'
require 'sprockets'
require 'json'
require 'securerandom'
require 'uri'
require 'yaml'
require 'dotenv/load'
require_relative 'services/url_service'

class App < Sinatra::Base
  environment.append_path("assets/stylesheets")
  environment.append_path("assets/javascripts")

  # Allow Docker bindings
  set :bind, '0.0.0.0'

  get '/' do
    redirect ENV['HOMEPAGE_URL']
  end

  post '/shorten', provides: :json do
    begin
      pass unless request.accept? 'application/json'
      body = request.body.read
      long_url = JSON.parse(body)['url']
      long_url = "http://#{long_url}" unless long_url.start_with? 'http'

      # Check URL validity
      URI.parse(long_url)

      # Create short link
      url_service = UrlService.new
      short_path = url_service.create(long_url, ENV['SHORT_PATH_LENGTH'].to_i)
      short_url = "http://#{ENV['URL']}/#{short_path}"

      res = {
        url: {
          long: long_url,
          short: short_url
        }
      }.to_json
      [200, {}, res]
    rescue URI::InvalidURIError # bad url
      res = {
        error: {
          url: "#{params[:url]}",
          message: 'The format of this url appears invalid.'
        }
      }.to_json
      [400, {}, res]
    rescue JSON::ParserError # bad json
      res = {
        error: {
          body: "#{body}",
          message: 'The body passed is not valid JSON.'
        }
      }.to_json
      [400, {}, res]
    end
  end

  get '/terms' do
    erb :terms
  end

  get '/privacy' do
    erb :privacy
  end

  get "/assets/*" do
    env["PATH_INFO"].sub!("/assets", "")
    Sprockets::Environment.new.call(env)
  end

  get '/:short_path' do
    url_service = UrlService.new
    long_url = url_service.read(params[:short_path])
    if long_url.nil?
      halt 404
    else
      redirect long_url
    end
  end
end
