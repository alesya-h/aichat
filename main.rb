#!/usr/bin/env ruby
require 'openai'
require 'json'
require 'colorize'

OpenAI.configure do |config|
    config.access_token = ENV.fetch('OPENAI_API_KEY')
end

@client = OpenAI::Client.new

@file = ARGV.first || "aichat.json"
@messages = []
if File.exists? @file
  @messages = JSON.parse File.read(@file)
else
  @messages = [{"role" => "system", "content" => "Act as a friend"}]
end

def persist!
  content = "[\n  #{@messages.map{|m| m.to_json}.join("\n, ")}\n]"
  File.open(@file, "w"){|f| f.write content}
end

def process!
  response = @client.chat(
    parameters: {
        model: "gpt-4", # Required.
        messages: @messages, # Required.
        temperature: 0.7,
    })
  @messages.push response.dig("choices", 0, "message")
end

@colors = {
  "user" => :green,
  "assistant" => :yellow,
  "system" => :red
}

def print_message(message)
  puts message["content"].colorize(@colors[message["role"]])
end

@messages.each{|m| print_message m}

continue = true
while continue
  if @messages.last["role"] == "user"
    user_input = @messages.last["content"]
  else
    print "User: "
    user_input = gets.chomp
    @messages.push({role: "user", content: user_input})
  end
  if user_input == "exit"
    continue = false
    break
  end
  process!
  persist!
  print_message @messages.last
end
