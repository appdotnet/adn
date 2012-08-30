#
# ADNRuby - A simple and easy to use App.net Ruby library
# 
# Copyright (c) 2012 Kishyr Ramdial
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'net/https'
require 'uri'
require 'json'
require 'date'

APIHOST = "alpha-api.app.net"
ADNHTTP = Net::HTTP.new(APIHOST, 443)
ADNHTTP.use_ssl = true

module ADN
  def self.token=(token)
    @token = token
  end

  def self.token
    @token
  end

  class User
    attr_accessor :user_id
    attr_accessor :avatar_image, :counts, :cover_image, :created_at, :description, :follows_you, :id, :is_follower, :is_following, :is_muted, :locale, :name, :timezone, :type, :username, :you_follow, :you_muted

    def initialize(user)
      if user.is_a? Hash
        user.each do |k, v|
          self.instance_variable_set "@#{k}", v
        end
        @user_id = self.id
      else
        @user_id = user
        details = self.details
        if details.has_key? "data"
          details["data"].each do |k, v|
            self.instance_variable_set "@#{k}", v
          end
        end
      end
    end

    def details
      if self.id
        h = {}
        self.instance_variables.each { |iv| h[iv.to_s.gsub(/[^a-zA-Z0-9_]/, '')] = self.instance_variable_get(iv) }
        h
      else
        ADN::API::User.retrieve(@user_id)
      end
    end


    # Followers/Users

    def get_user(user)
      user.is_a?(ADN::User) ? user.id : user
    end

    def follow(user)
      user_id = get_user(user)
      result = ADN.post("/stream/0/users/#{user_id}/follow")
      User.new(result["data"]) unless result.has_error?
    end

    def unfollow(user)
      user_id = get_user(user)
      result = ADN.delete("/stream/0/users/#{user_id}/follow")
      User.new(result["data"]) unless result.has_error?
    end

    def followers
      result = ADN::API::User.followers(@user_id)
      result["data"].collect { |u| User.new(u) } unless result.has_error?
    end

    def following
      result = ADN::API::User.following(@user_id)
      result["data"].collect { |u| User.new(u) } unless result.has_error?
    end

    
    # Mute

    def mute(user)
      user_id = get_user(user)
      result = ADN.post("/stream/0/users/#{user_id}/mute")
      User.new(result["data"]) unless result.has_error?
    end

    def unmute(user)
      user_id = get_user(user)
      result = ADN.delete("/stream/0/users/#{user_id}/mute")
      User.new(result["data"]) unless result.has_error?
    end

    def mute_list
      result = ADN.get("/stream/0/users/me/muted")
      result["data"].collect { |u| User.new(u) } unless result.has_error?
    end

    
    # Posts

    def posts(params = nil)
      result = ADN::API::Post.by_user(@user_id, params)
      result["data"].collect { |p| Post.new(p) } unless result.has_error?
    end

    def stream(params = nil)
      result = ADN::API::Post.stream(params)
      result["data"].collect { |p| Post.new(p) } unless result.has_error?
    end

    def mentions(params = nil)
      result = ADN::API::Post.mentioning_user(@user_id, params)
      result["data"].collect { |p| Post.new(p) } unless result.has_error?
    end

    # Errors

    def has_error?
      self.id.nil?
    end

  end

  class Post
    attr_accessor :post_id, :created_at, :entities, :html, :id, :num_replies, :reply_to, :source, :text, :thread_id, :user

    def self.send(params)
      result = ADN::API::Post.new(params)
      Post.new(result["data"]) unless result.has_error?
    end

    def initialize(raw_post)
      if raw_post.is_a? Hash
        raw_post.each do |k, v|
          self.instance_variable_set "@#{k}", v
        end
        @post_id = @id
      else
        @post_id = raw_post
        details = self.details
        if details.has_key? "data"
          details["data"].each do |k, v|
            self.instance_variable_set "@#{k}", v
          end
        end
      end
    end

    def details
      if self.id
        h = {}
        self.instance_variables.each { |iv| h[iv.to_s.gsub(/[^a-zA-Z0-9_]/, '')] = self.instance_variable_get(iv) }
        h
      else
        ADN::API::Post.by_id(@post_id)
      end
    end

    def created_at
      DateTime.parse(@created_at)
    end

    def user
      ADN::User.new @user
    end

    def reply_to_post
      result = ADN::API::Post.by_id @reply_to
      Post.new(result["data"]) unless result.has_error?
    end

    def replies(params = nil)
      result = ADN::API::Post.replies(@id, params)
      result["data"].collect { |p| Post.new(p) } unless result.has_error?
    end

    def delete
      result = ADN::API::Post.delete(@id)
      Post.new(result["data"]) unless result.has_error?
    end

  end


  # API Modules

  module API
    module User

      def self.retrieve(user_id)
        ADN.get("/stream/0/users/#{user_id}")
      end

      def self.by_id(user_id)
        self.retrieve(user_id)
      end

      def self.following(user_id)
        ADN.get("/stream/0/users/#{user_id}/following")
      end

      def self.followers(user_id)
        ADN.get("/stream/0/users/#{user_id}/followers")
      end

    end

    module Post
      def self.new(params)
        ADN.post("/stream/0/posts", params)
      end

      def self.retrieve(post_id)
        ADN.get("/stream/0/posts/#{post_id}")
      end

      def self.by_id(post_id)
        self.retrieve(post_id)
      end

      def self.delete(post_id)
        ADN.delete("/stream/0/posts/#{post_id}")
      end

      def self.replies(post_id, params = nil)
        ADN.get("/stream/0/posts/#{post_id}/replies", params)
      end

      def self.by_user(user_id, params = nil)
        ADN.get("/stream/0/users/#{user_id}/posts", params)
      end

      def self.mentioning_user(user_id, params = nil)
        ADN.get("/stream/0/users/#{user_id}/mentions", params)
      end

      def self.stream(params = nil)
        ADN.get("/stream/0/posts/stream", params)
      end

      def self.global_stream(params = nil)
        ADN.get("/stream/0/posts/stream/global", params)
      end

      def self.by_hashtag(hashtag, params = nil)
        ADN.get("/stream/0/posts/tag/#{hashtag}", params)
      end

    end

    module Stream
      # Not Yet Implemented
      # https://github.com/appdotnet/api-spec/blob/master/resources/streams.md
    end

    module Subscription
      # Not Yet Implemented
      # https://github.com/appdotnet/api-spec/blob/master/resources/subscriptions.md
    end

    module Filter
      # Not Yet Implemented
      # https://github.com/appdotnet/api-spec/blob/master/resources/filters.md
    end

    module Token
      def self.current
        result = ADN.get("/stream/0/token")
        result["data"] unless result.has_error?
      end
    end
  end


  private 

  def self.get_response(request)
    request.add_field("Authorization", "Bearer #{ADN.token}")
    response = ADNHTTP.request(request)
    JSON.parse(response.body)
  end 

  def self.get(url, params = nil)
    get_url = params.nil? ? url : "#{url}?#{URI.encode_www_form(params)}"
    self.get_response(Net::HTTP::Get.new(get_url))
  end

  def self.post(url, params = nil)
    request = Net::HTTP::Post.new(url)
    request.set_form_data(params) if params
    self.get_response(request)
  end

  def self.put(url, params = nil)
    request = Net::HTTP::Put.new(url)
    request.set_form_data(params) if params
    self.get_response(request)
  end

  def self.delete(url, params = nil)
    request = Net::HTTP::Delete.new(url)
    self.get_response(request)
  end
end

class Hash
  def has_error?
    self.has_key? "error"
  end
end