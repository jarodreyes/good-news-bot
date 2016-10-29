require 'data_mapper'
require "twilio-ruby"
require 'twilio-ruby/rest/messages'

DataMapper::Logger.new(STDOUT, :debug)
DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://@localhost/goodnews')

class VerifiedUser
  include DataMapper::Resource
  @@client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']


  property :id, Serial
  property :code, String, :length => 10
  property :name, String
  property :phone_number, String, :length => 30
  property :verified, Boolean, :default => false
  property :frequency, Integer, :default => 60

  has n, :posts, :through => Resource

  after :create, :welcome_user

  def send_message(msg, media=nil)
    p msg
    p media
    p "sending message"
    if media.nil?
      message = @@client.account.messages.create(
        :from => ENV['NEWS_NUMBER'],
        :to => @phone_number,
        :body => msg)
      puts message.to
    else
      message = @@client.account.messages.create(
        :from => ENV['NEWS_NUMBER'],
        :to => @phone_number,
        :body => msg,
        :media_url => media)
      puts message.to
    end
    
  end

  def get_news
    begin
      p "get news !!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      ps = Post.all.sort_by{rand}
      ps.each_with_index do |post, i|
        user_post = self.posts.get(post.id)
        p "$$$$$$$$$$$$$$$$ #{user_post} ---- #{post.id} ---- #{self.posts}"
        if user_post.nil? || i == ps.size
          self.posts << post
          self.save!
          return post
        else
          next
        end
      end
    rescue Exception => e
      puts "ERRROR ---> #{e.message}"
    end
    
  end

  def send_news
    post = get_news()
    send_message("#{post.title} - #{post.url}", "#{post.thumbnail}")
  end

  def welcome_user
    send_message("Hello #{@name}, Welcome to the Good News Robot! Whenever you need a pick-me-up just text this number 'Something Good'.")
  end
end

class Post
  include DataMapper::Resource

  property :id, String, :key => true
  property :url, String, :length => 255
  property :thumbnail, String, :length => 255
  property :title, Text
  property :permalink, String, :length => 255

  has n, :verified_users, :through => Resource
end

DataMapper.finalize
DataMapper.auto_upgrade!