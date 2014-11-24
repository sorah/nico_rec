#!/usr/local/bin/ruby
Dir.chdir __dir__
require 'bundler/setup'
require 'yaml'
require 'niconico'
require 'tempfile'

# requires ./config.yml
# requires ./videos

abort "usage: #{$0} channel-id" if ARGV.empty?

ch = ARGV[0]

dir = File.join("videos", ch)
Dir.mkdir(dir) unless File.exists?(dir)

config = YAML.load_file('config.yml')
nico = Niconico.new(config["email"], config["password"])

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

  unless video.economy?
    puts " * Skipping due to economy"
  end

  puts "=> Downloading #{video.id}: #{video.title}"
  file = File.join(dir, "#{id}_#{video.title}.#{video.type}")

  cookie_jar = Tempfile.new("niconico_cookie_jar_#{video.id}")
  begin
    File.chmod(0600, cookie_jar)

    cred = video.get_video_by_other
    video_url, cookies = cred[:url], cred[:cookie]

    cookie_jar.puts(cookies.map { |cookie|
        [cookie.domain, "TRUE", cookie.path,
         cookie.secure.inspect.upcase, cookie.expires.to_i,
         cookie.name, cookie.value].join("\t")
      }.join("\n"))

    cookie_jar.flush

    result = system("curl", "-#", "-o", file, "-b", cookie_jar.path, video_url)
  ensure
    cookie_jar.close
    cookie_jar.unlink
  end

  unless result
    File.unlink(file) if File.exists?(file)
    puts " ! may be failed :("
  end
end