require "bundler/setup"
require "sinatra"
require "sinatra/multi_route"
require "twilio-ruby"
require 'twilio-ruby/rest/messages'
require "sanitize"
require "erb"
require "rotp"
require "haml"
require "json"
require "redditkit"
require 'rufus-scheduler'
include ERB::Util


class MyApp < Sinatra::Application
  @@scheduler = Rufus::Scheduler.new

  configure do
    set :static, true
    set :haml, { :ugly=>true }
    set :root, File.dirname(__FILE__)
  end

  before do
    @news_number = ENV['NEWS_NUMBER']
    @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
    if params[:error].nil?
      @error = false
    else
      @error = true
    end

  end

  get "/update" do
    update_reddit()
    haml :index
  end

  get "/" do
    haml :signup
  end

  get "/signup" do
    haml :signup
  end

  get "/success" do
    haml :success
  end
  route :get, :post, '/pull-news' do 
    phone_number = Sanitize.clean(params[:From])
    user = VerifiedUser.first_or_create(:phone_number => phone_number)
    post = getTheNews(phone_number)
    Twilio::TwiML::Response.new do |r|
      r.Message do |m|
        m.Body "#{post.title} - #{post.url}"
        m.Media "#{post.thumbnail}"
      end
    end.text
  end

  def getTheNews(phone_number)
    user = VerifiedUser.first(:phone_number => phone_number)
    posts = Post.all.sort_by{rand}

    posts.each_with_index do |post, i|
      user_post = user.posts.get(post.id)
      if user_post.nil? || i == posts.size
        user.posts << post
        user.save!
        return post
      else
        next
      end
    end
  end

  def parse_results(list)
    list.each do |post|
      exists = Post.get(post.id)
      img = post.image_link? ? post.url : post.thumbnail
      url = post.url
      parsed_url = URI.parse(url)
      new_url = parsed_url.scheme+"://"+parsed_url.host+parsed_url.path
      if post.over_18 == false && exists.nil?
        Post.create!(
          :id => post.id, 
          :thumbnail => img,
          :title => post.title,
          :permalink => post.permalink,
          :url => new_url)
      end
    end
  end

  # Register a subscriber through the web and send verification code
  route :get, :post, '/register' do
    content_type :json
    @phone_number = Sanitize.clean(params[:phone_number])

    begin
      @phone_number = @phone_number.length <= 10 ? "+1#{@phone_number}" : @phone_number
      p "begin"
      if @error == false
        user = VerifiedUser.create(
          :name => params[:name],
          :phone_number => @phone_number,
          :frequency => params[:frequency].to_i
        )
        if user.verified == true
          @phone_number = url_encode(@phone_number)
          redirect to("/verify?phone_number=#{@phone_number}&verified=1")
        end
        totp = ROTP::TOTP.new("upfromhere")
        code = totp.now
        user.code = code
        if user.save
          user.send_message("Your GoodNews verification code is #{code}.")
          status 200
          body "success"
        else
          user.errors.each do |e|
            puts e
          end
          status 404
          body user.errors.first[0]
        end
      end
    rescue Exception => e
      status 404
      {
        :success => 'false',
        :error => e.message
      }.to_json
    end
  end

  def update_reddit
    @reddit_client = RedditKit::Client.new ENV['REDDIT_USERNAME'], ENV['REDDIT_PW']
    p @reddit_client.signed_in? # => true
    red_links = @reddit_client.links 'UpliftingNews', :category => :new, :time => :all, :limit => 100
    parse_results(red_links)

    bros_links = @reddit_client.links 'HumansBeingBros', :category => :new, :time => :all, :limit => 100
    parse_results(bros_links)
  end

  # Endpoint for verifying code was correct
  route :get, :post, '/verify' do
    p "POST VERIFY"
    phone_number = params[:phone_number]
    code = Sanitize.clean(params[:code])
    user = VerifiedUser.first(:phone_number => phone_number)
    p "USER #{user.name}"
    if user.verified == true
      @verified = true
      status 303
      body "verified"
    elsif user.nil? or user.code != code
      phone_number = url_encode(phone_number)
      redirect to("/register?phone_number=#{phone_number}&error=1")
    else
      user.verified = true
      user.save
      user.send_news()
      p "SENT NEWS"
      # begin
      #   p "SCHEDULING 2"
      #   @@scheduler.every "#{user.frequency}m" do
      #     user.send_news()
      #   end
      #   @@scheduler.join
      #   p "SCHEDULING JOIN"
      #   break
      # rescue Exception => e
      #   puts "ERRROR ---> #{e.message}"
      # end
      status 200
      body "success"
    end
  end
end

require_relative 'lib/user'