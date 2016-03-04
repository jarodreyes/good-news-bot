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
require "json"
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
  has n, :tacos

end

class Message
  include DataMapper::Resource

  property :id, Serial
  property :body, Text

  belongs_to :anon_user

end

class Taco
  include DataMapper::Resource

  property :id, Serial
  property :flavor, Text

  belongs_to :anon_user

end
DataMapper.finalize
DataMapper.auto_upgrade!

before do
  @cowork_number = ENV['COWORK_NUMBER']
  @tacos_number = ENV['TACOS_NUMBER']
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

$FUT = ["http://jardiohead.s3.amazonaws.com/fut.mp3", "http://jardiohead.s3.amazonaws.com/fut1.mp3", "http://jardiohead.s3.amazonaws.com/fut2.mp3", "http://jardiohead.s3.amazonaws.com/fut3.mp3", "http://jardiohead.s3.amazonaws.com/fut4.mp3", "http://jardiohead.s3.amazonaws.com/fut5.mp3"]
$FAM = ["http://jardiohead.s3.amazonaws.com/fg1.mp3", "http://jardiohead.s3.amazonaws.com/fg3.mp3", "http://jardiohead.s3.amazonaws.com/fg2.mp3"]
$MONT = ["http://jardiohead.s3.amazonaws.com/mp1.mp3", "http://jardiohead.s3.amazonaws.com/mp3.mp3", "http://jardiohead.s3.amazonaws.com/mp2.mp3", "http://jardiohead.s3.amazonaws.com/mp4.mp3"]
$BREAK = ["http://jardiohead.s3.amazonaws.com/bc1.mp3", "http://jardiohead.s3.amazonaws.com/bc2.mp3"]
$SPACE = ["http://jardiohead.s3.amazonaws.com/sb1.mp3", "http://jardiohead.s3.amazonaws.com/sb5.mp3", "http://jardiohead.s3.amazonaws.com/sb6.mp3"]

post "/greg" do
  # Get phone_number from the incoming GET request from Twilio
  @phone_number = Sanitize.clean(params[:From])
  @greeting = "Thank you for calling Greg Veckga's emergency funny reference hotline! Happy Birthday Greg!"
  @instructions = "To hear a reference from Futurama, Press 1. For Monty Python, Press 2. For Breakfast Club, Press 3. For Space Balls, Press 4. To hear Family Guy, Press 5. To here these options again stay on the line."
  # Respond with some TwiML to kick-off the survey
  response = Twilio::TwiML::Response.new do |r|
    r.Gather :numDigits => '1', :action => '/greg_reference', :method => 'get' do |g|
      g.Say @greeting, voice: 'alice', language: 'en-US'
      g.Say @instructions, voice: 'alice', language: 'en-US'
    end
    r.Redirect
  end
  response.text
end

get "/greg_reference" do
  input = params[:Digits]
  case input

  # Futurama
  when '1'
    @audio = $FUT[rand(4)]
    puts @audio
  # Monty Python
  when '2'
    @audio = $MONT[rand(3)]
  when '3'
    @audio = $BREAK[rand(0..1)]
  when '4'
    @audio = $SPACE[rand(2)]
  when '5'
    @audio = $FAM[rand(2)]
  else
    @audio = "https://ia902205.us.archive.org/27/items/ReneVenturosoRickrollVenturoso/RickRoll.mp3"
  end
  response = Twilio::TwiML::Response.new do |r|
    r.Play @audio
    r.Say "Thank you for calling Greg Veckga's emergency funny hotline."
    r.Redirect '/greg'
  end
  response.text
end
get "/messages" do
  @messages = Message.all
  haml :messages
end

get "/api/tacos.json" do
  @tacos = Taco.all
  @tacos.to_json
end

# Register a subscriber through the web and send verification code
route :get, :post, '/bizcard' do
  @phone_number = Sanitize.clean(params[:From])
  @outgoing_number = params[:Body]

  @message = 'Jarod Reyes: Documentation at Twilio.com

Telephone: (206)650-5813
Email: jreyes@twilio.com
Twitter: https://twitter.com/jreyesdesign

This SMS business card was built in 10 lines of code using Twilio. View the code on Github: http://bit.ly/1P0mjOk.
It was nice meeting you at #Agile2015!
  '
  Twilio::TwiML::Response.new do |r|
    r.Message :to => @outgoing_number do |m|
      m.Body @message
      m.Media "http://jardiohead.s3.amazonaws.com/profile.jpg"
      m.Media "/img/jarod.vcf"
    end
  end.text
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

  @msg = "Hi! I am the Twilio-powered candy machine. Please let me know what would you like to have in the candy machine next month?"
  message = @client.account.messages.create(
    :from => @cowork_number,
    :to => @phone_number,
    :body => @msg
  )
  puts message.to
  @msg2 = "This number was made intelligent using Twilio. See the code at: bit.ly/3rdCandy"
  message = @client.account.messages.create(
    :from => @cowork_number,
    :to => @phone_number,
    :body => @msg2
  )
  puts message.to

end

$TACOS = ['chicken', 'pork', 'fish', 'vegetarian', 'veggie']
MAX_TACOS = 3

# 3rdSpace Taco Tuesday webhook
# Phone Number: 6692382267
# Register a subscriber through the web and send verification code
route :get, :post, '/tacos' do
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body].downcase
  puts "******************* ERROR: #{@error} **********************"
  puts "******************* BODY: #{@body} **********************"

  @options = "Please type: 'chicken', 'pork', 'fish' or 'vegetarian'"

  if @error == false
    user = AnonUser.first_or_create(:phone_number => @phone_number)
    if not @body.nil?
      number_choice = @body.is_a? Integer

      # Is this a taco order?
      if $TACOS.include? @body or number_choice

        if number_choice
          @body = $TACOS[@body]
        end
        # Check and see how many tacos the person requested.
        if user.tacos.length < 3
          user.tacos.create(:flavor => @body)
          user.save
          num_tacos = user.tacos.length

          if user.tacos.length == 3
            @output = "Awesome I got your full order. Look forward to seeing you at Taco Tuesday. Save the date: 12:00pm on April 7th!"
          else
            @output = "One #{@body} coming right up. You have ordered #{num_tacos} taco(s). To order more #{@options}"
          end
        else
          order = []
          user.tacos.each do |taco|
            order << taco.flavor
          end
          tacos = order * ", "
          @output = "Looks like you have already ordered 3 tacos. Your current order is #{tacos}. Would you like to start over? If so type 'reset'."
        end 
        
      else

        # Since this isn't a taco order it must be something else.
        case @body

        # delete taco order and start over.
        when 'reset'
          user.tacos.all.destroy
          @output = "Okay you're order has been reset. Let's start over! What kind of tacos would you like? #{@options}"

        # Welcome the 3rdspacer
        when 'hello'
          @output = "Hello 3rd Spacer! Taco Tuesday is happening at 12:00pm on April 7th! Free tacos for all! To order (up to 3) tacos, respond to this number. #{@options}"
          @msg2 = "This number was made intelligent using Twilio. See the code at: bit.ly/3rdTacos"
          message = @client.account.messages.create(
            :from => @tacos_number,
            :to => @phone_number,
            :body => @msg2
          )
          puts message.to
        else
          @output = "Sorry, not sure what kind of taco that is. #{@options}"
        end
      end
    else
      @output = "Hello 3rd Spacer! Taco Tuesday is happening at 12:00pm on April 7th! Free tacos for all! To order (up to 3) tacos, respond to this number. #{@options}"
      @msg2 = "This number was made intelligent using Twilio. See the code at: bit.ly/3rdTacos"
      message = @client.account.messages.create(
        :from => @tacos_number,
        :to => @phone_number,
        :body => @msg2
      )
      puts message.to
    end
  end

  Twilio::TwiML::Response.new do |r|
    r.Message @output
  end.text
end