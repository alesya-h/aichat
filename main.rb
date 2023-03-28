#!/usr/bin/env ruby
require 'openai'
require 'yaml'
require 'colorize'
require "tty-prompt"

@prompt = TTY::Prompt.new

@file = ARGV.first || "default.ai.yaml"
@messages = []
@parameters = {
  "model" => "gpt-4", # required
  "temperature" => 0.7
}

@presets = {
  "default" => "Act as a helpful AI assistant",
  "friend"  => "Pretend to be a human. Don't ever tell you are an AI language model. Act as a friend",
  "code" => "Act as a code generation tool. Only output code. When asked to correct the code, only output parts that need to be updated",
  "assistant" => <<-TXT.chomp
  Act as an assistant. To be able to perform your duties you have access to a stateful debian box with root access.
  It might be useful when you need to keep track of time, search the internet, make computations etc.
  To send commands into interactive bash shell on it use the form `CMD_IN: command goes here`.
  The output will be returned to this chat in the form of `CMD_OUT: output goes here`.
  When you need an output to be returned asynchronously, you can use commands chat_cat and chat_echo.
  `chat_cat` would be called similar to this: `(sleep 60 ; pwd|chat_cat)&`, with output coming as `CHAT_CAT: /home/user` after 60 seconds,
  and `chat_echo` would be called like `chat_echo 42` with output coming as `CHAT_ECHO: 42`.
  To respond to the user use the form `USER_OUT: user will see this`.
TXT
}

OpenAI.configure do |config|
  config.access_token = ENV['OPENAI_API_KEY']
end
@client = OpenAI::Client.new

def preset_message(preset)
  {"role" => "system", "content" => @presets[preset]}
end

if File.exists? @file
  @parameters = YAML.load_file @file
  @messages = @parameters["messages"]
  @parameters.delete("messages")
else
  @messages = [preset_message("assistant")]
end

def context
  @parameters.merge({"messages" => @messages})
end

def persist!
  #s = "[\n  #{@messages.map{|m| m.to_json}.join("\n, ")}\n]"
  s = context.to_yaml
  File.open(@file, "w"){|f| f.write s}
end

def process!
  response = @client.chat(
    parameters: context
  )
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
    user_input = @prompt.ask("User:")
    @messages.push({"role" => "user", "content" => user_input})
  end
  if user_input == "exit"
    continue = false
    break
  end
  process!
  persist!
  print_message @messages.last
end
