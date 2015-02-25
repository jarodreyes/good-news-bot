require "bundler/setup"
require "sinatra"
require "sinatra/multi_route"
require "data_mapper"
require "twilio-ruby"
require 'twilio-ruby/rest/messages'
require "sanitize"
require "erb"
require "rotp"
require "haml"
include ERB::Util

set :static, true
set :root, File.dirname(__FILE__)

DataMapper::Logger.new(STDOUT, :debug)
DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://postgres:postgres@localhost/jreyes')

class AnonUser
  include DataMapper::Resource

  property :id, Serial
  property :phone_number, String, :length => 30

  has n, :messages

end

class Message
  include DataMapper::Resource

  property :id, Serial
  property :body, Text

  belongs_to :anon_user

end
DataMapper.finalize
DataMapper.auto_upgrade!

before do
  @cowork_number = ENV['COWORK_NUMBER']
  @twilio_number = ENV['TWILIO_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

get "/" do
  haml :index
end

def sendMessage(from, to, body)
  message = @client.account.messages.create(
    :from => from,
    :to => to,
    :body => body
  )
  puts message.to
end

get "/messages" do
  @messages = Message.all
  haml :messages
end

# Register a subscriber through the web and send verification code
route :get, :post, '/sms-register' do
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body]
  puts @error

  if @error == false
    user = AnonUser.first_or_create(:phone_number => @phone_number)
    if not @body.nil?
      user.messages.create(:body => @body)
      user.save
    end
  end

  @msg = "Hi! I am the candy machine. Please let me know what would you like to be in the candy machine next month?"
  message = @client.account.messages.create(
    :from => @cowork_number,
    :to => @phone_number,
    :body => @msg
  )
  puts message.to

end