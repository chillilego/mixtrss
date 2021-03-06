#!/usr/bin/env ruby
require "rubygems"
require "dalli"
require "memcachier"
require "sinatra"
require "json"
require "pony"
require "./lib/common"

set :cache, Dalli::Client.new
set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 365]

RETURN_PAGE_SIZE = 10

get "/:genre?/?:page?" do
  genre, page = genre_and_page params[:genre], params[:page]
  @mixes = mixes(genre, page)
  @description = description @mixes, genre
  @canonical = canonical genre, page
  @title = title genre, page

  erb :index
end

get "/mixes/:genre/:page" do
  content_type 'application/json'

  genre, page = genre_and_page params[:genre], params[:page]

  mixes(genre, page).to_json
end

post "/feedback" do
  # Pony.mail(:from => params[:name] + "<" + params[:email] + ">",
  #           :to => 'jmkupferman+mixtress' + '@' + 'gmail.com',
  #           :subject => "Mixtress feedback from #{params[:name]}",
  #           :body => params[:message],
  #           :port => '587',
  #           :via => :smtp,
  #           :via_options => {
  #             :address              => 'smtp.gmail.com',
  #             :port                 => '587',
  #             :enable_starttls_auto => true,
  #             :user_name            => ENV['GMAIL_SMTP_USER'],
  #             :password             => ENV['GMAIL_SMTP_PASSWORD'],
  #             :authentication       => :plain,
  #             :domain               => 'localhost.localdomain'
  #           })
  redirect '/'
end

# Helper methods

def genre_and_page genre, page
  # sanitize the incoming genre and page values to ensure they are valid
  genre = genre.to_s.strip.downcase
  genre = "all" unless Common::AVAILABLE_GENRES.include?(genre)

  page = (page || 0).to_i

  [genre, page]
end

def mixes genre, page
  offset = page * RETURN_PAGE_SIZE
  mixes_for_genre(genre)[offset...(offset + RETURN_PAGE_SIZE)]
end

def title genre, page
  if genre == "all"
    "Mixtrss - the best mixes on Soundcloud"
  else
    "#{genre.capitalize} mixes | Mixtrss"
  end
end

def description mixes, genre
  artists = mixes.map { |m| m[:artist] }[0...4].join(", ")

  display_genre = (genre == 'all') ? 'electro' : genre
  "Listen to the best #{display_genre} mixes and dj sets on the web. Mixes by #{artists}."
end

def canonical genre, page
  "http://mixtrss.com/#{URI.escape(genre)}/#{page}"
end

def mixes_for_genre genre
  # fetches the precomputed mixes from memcache
  settings.cache.get(Common.genre_key(genre)) || []
end
