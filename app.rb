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
DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/my_database')

class VerifiedUser
  include DataMapper::Resource

  property :id, Serial
  property :code, String, :length => 10
  property :name, String
  property :phone_number, String, :length => 30
  property :verified, Boolean, :default => false
  property :send_mms, Enum[ 'yes', 'no' ], :default => 'no'

  has n, :messages

end

class Message
  include DataMapper::Resource

  property :id, Serial
  property :body, Text
  property :time, DateTime
  property :name, String

  belongs_to :verified_user

end
DataMapper.finalize
DataMapper.auto_upgrade!

before do
  @twilio_number = ENV['TWILIO_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

def sendMessage(from, to, body)
  message = @client.account.messages.create(
    :from => from,
    :to => to,
    :body => body
  )
  puts message.to
end

# Register a subscriber through the web and send verification code
route :get, :post, '/register' do
  @phone_number = Sanitize.clean(params[:phone_number])
  if @phone_number.empty?
    redirect to("/?error=1")
  end

  begin
    if @error == false
      user = VerifiedUser.create(
        :name => params[:name],
        :phone_number => @phone_number,
        :send_mms => params[:send_mms]
      )

      if user.verified == true
        @phone_number = url_encode(@phone_number)
        redirect to("/verify?phone_number=#{@phone_number}&verified=1")
      end
      totp = ROTP::TOTP.new("drawtheowl")
      code = totp.now
      user.code = code
      user.save

      sendMessage(@twilio_number, @phone_number, "Your verification code is #{code}")
    end
    erb :register
  rescue
    redirect to("/?error=2")
  end
end