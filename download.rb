#!/usr/local/bin/ruby
Dir.chdir __dir__
require 'bundler/setup'
require 'yaml'
require 'niconico'
require 'tempfile'

SESSION_FILE = "user_session.secret"

# requires ./config.yml
# requires ./videos

abort "usage: #{$0} channel-id" if ARGV.empty?

ch = ARGV[0]

dir = File.join("videos", ch)
Dir.mkdir(dir) unless File.exists?(dir)

config = YAML.load_file('config.yml')
nico = Niconico.new(mail: config["email"], password: config["password"],
                    token: File.exist?(SESSION_FILE) ? File.read(SESSION_FILE).chomp : nil)

nico.login
open(SESSION_FILE, 'w', 0600) do |io|
  io.puts nico.token
end

nico.channel_videos(ch).each do |video|
  id = video.id
  unless Dir[File.join(dir, "#{id}_*")].empty?
    puts " * Skipping #{video.id}: #{video.title}"
    next
  end

  video.get

  unless video.available?
    puts " * Skipping because unavailable: #{video.id}, #{video.title} "
    next
  end

  if video.economy?
    puts " * Skipping due to economy"
  end

  puts "=> Downloading #{video.id}: #{video.title}"
  file = File.join(dir, "#{id}_#{video.title}.#{video.type}")

  cookie_jar = video.video_cookie_jar_file
  begin
    result = system("curl", "-#", "-o", file, "-b", cookie_jar.path, video.video_url)
  ensure
    cookie_jar.close
    cookie_jar.unlink
  end

  unless result
    File.unlink(file) if File.exists?(file)
    puts " ! may be failed :("
  end
end

