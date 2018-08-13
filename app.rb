require 'sinatra'
require 'net/http'
require 'logger'
require 'time'
require 'cgi'
require 'json'

set :bind, '0.0.0.0'

TOGGL_API_KEY = ENV['TOGGL_API_KEY']
TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID']
TELEGRAM_BOT_API_KEY = ENV['TELEGRAM_BOT_API_KEY']

get '/' do
  content_type :json
  today = Time.now.getlocal("+05:30").to_date
  yesterday = today - 1
  start_time = Time.new(yesterday.year, yesterday.month, yesterday.day, 0,0,0, "+05:30").to_time.iso8601
  end_time = Time.new(today.year, today.month, today.day, 0,0,0, "+05:30").to_time.iso8601

  enteries = nil
  enteries = get_toggl_report start_time, end_time
  report_time = "<b>From: </b>#{yesterday} 00:00:00 \n<b>To: </b>#{today} 00:00:00"

  if !enteries.nil? && !enteries.empty?
    send_report_to_telegram enteries, yesterday, today
  else
    send_telegram_message "#{report_time}\n\n<b>Nothing to report!</b>"
  end

  res = {:time => Time.now, :ip => request.ip}
  res.to_json
end

def get_toggl_report start_time, end_time
  uri = URI("https://www.toggl.com/api/v8/time_entries?start_date=#{CGI.escape(start_time)}&end_date=#{CGI.escape(end_time)}")
  req = Net::HTTP::Get.new(uri)
  req.basic_auth TOGGL_API_KEY, 'api_token'
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  puts "get_toggl_report"
  puts res.code
  puts res.body
  
  if res.code == "200"
    JSON.parse(res.body)
  else
    nil
  end
end

def send_report_to_telegram enteries, yesterday, today
  total_duration = enteries.map{|e| e['duration']}.inject(:+)
  tasks_duration = enteries.map{|e| [e['description'], Time.at(e['duration']).utc.strftime("%H hours, %M minutes")]}
  total_duration_in_words = Time.at(total_duration).utc.strftime("%H hours, %M minutes")

  report_time = "<b>From: </b>#{yesterday} 00:00:00 \n<b>To: </b>#{today} 00:00:00"
  formatted_tasks_duration = tasks_duration.map{ |t| "#{t[0]}: #{t[1]}"}.join("\n")
  message = %(#{report_time}
<b>Total Duration:</b> #{total_duration_in_words}
    
<b>Tasks:</b>
#{formatted_tasks_duration}
    )

  send_telegram_message message
end

def send_telegram_message message
  uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_API_KEY}/sendMessage?chat_id=#{TELEGRAM_CHAT_ID}&parse_mode=html&text=#{CGI.escape(message)}")
  req = Net::HTTP::Get.new(uri)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  puts "send_telegram_message"
  puts res.code
  puts res.body
end
