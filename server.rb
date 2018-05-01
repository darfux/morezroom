require 'sinatra'
require 'sinatra/cookies'
require 'yaml/store'
require_relative 'zroom'

# set :bind, '0.0.0.0'

enable :sessions
set :sessions, :expire_after => 604800

before do
   @db = YAML::Store.new('sitedb.yml')
   pass if %w[auth].include? request.path_info.split('/')[1]
   @auth = session[:auth]
   if @auth.nil?
     redirect '/auth'
   end
end

get '/auth' do
  config = YAML.load_file("config.yml")
  if params["pwd"] == config[:pwd]
    session[:auth] = true
    redirect '/'
  end
end

get '/' do
  @rooms = []
  rooms = nil
  @db.transaction(true) do
    rooms = @db.fetch(:rooms, {})
  end
  rooms.each do |id, v|
    room = ZRoom.parse_room!(id)
    next if room.nil?
    room[:data] = ZRoom.room_data(id)
    room[:url] = ZRoom.gen_url(room)
    room[:notify] = v[:notify]==true
    # room[:empty_count] = ZRoom.empty_count(room[:data])
    @rooms << room
  end
  erb :index
end

get '/new_room' do
  erb :new_room
end

post '/new_room' do
  url = params["url"]
  ZRoom.parse_room_url(url)
  type, id = url.split(/[\.\/]/)[-3..-2]
  @db.transaction do
    @db[:rooms] ||= {}
    @db[:rooms][id] = {notify: true}
  end
  redirect '/'
end

get '/change_notify/:id' do
  id = params["id"]
  @db.transaction do
    notify = @db[:rooms][id][:notify]
    @db[:rooms][id][:notify] = !notify
  end
  redirect '/'
end

get '/delete/:id' do
  id = params['id']
  @db.transaction do
    @db[:rooms] ||= {}
    @db[:rooms].delete id
  end
  redirect '/'
end

get '/frank-says' do
  'Put this in your pipe & smoke it!'
end
