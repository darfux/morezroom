require "nokogiri"
require 'open-uri'
require 'pry'
require 'yaml/store'
require 'json'
require 'net/http'
require 'base64'


class ZRoomAPI
class << self
  def m(query_params)
    qp = URI.encode_www_form(query_params)
    "https://#{Base64.decode64('cGhvZW5peC56aXJvb20uY29tL3Y3L3Jvb20vZGV0YWlsLmpzb24=')}?#{qp}"
  end
  def pc(query_params)
    qp = URI.encode_www_form(query_params)
    "http://#{Base64.decode64('d3d3Lnppcm9vbS5jb20vZGV0YWlsL2luZm8=')}?#{qp}"
  end
  def room_page(type, id)
    "http://#{Base64.decode64('d3d3Lnppcm9vbS5jb20veg==')}/#{type}/#{id}.html"
  end
end
end

class ZRoom
class << self
  def parse_room_url(url)
    type, id = url.split(/[\/\.]/)[-3..-2]
    return nil unless ['vr','vh'].include?(type)
    parse_room(id, type)
  end
  def gen_url(room)
    ZRoomAPI.room_page(room[:type], room[:id])
  end
  def parse_room!(id)
    roomdb = YAML::Store.new('zroom.yml')
    room = nil
    roomdb.transaction(true) do
      rooms = roomdb.fetch(:rooms, {})
      room = rooms[id]
    end
    room
  end
  def explain_status(str)
    case str
    when 'tzpzz'
      '退租配置中'
    when 'zxpzz'
      '装修配置中'
    when 'sfz'
      '上房中'
    when 'dzz'
      '出租中'
    when 'ycz'
      '已租'
    else
      str
    end
  end
  def parse_room(id, type='vr')
    return nil if id.nil?
    roomdb = YAML::Store.new('zroom.yml')
    room = parse_room!(id)
    return room unless room.nil?
    doc = Nokogiri::HTML(open(ZRoomAPI.room_page(type, id)))
    hiddoc = doc/"#house_id"
    house_id = hiddoc[0]["value"]
    name = (doc/".room_name"/"h2").text.strip
    # roomates = []
    # (doc/".greatRoommate"/'a').each do |romt|
    #   roomates << romt["href"].match(/([0-9]+)\.html/)[1]
    # end

    room = {
      id: id,
      name: name,
      house_id: house_id,
      type: type,
      last_update: 0,
    }

    roomdb.transaction do
      roomdb[:rooms] = {} if roomdb[:rooms].nil?
      roomdb[:rooms][id] = room
    end

    refresh(room)
    return room
  end

  def room_data(id)
    fname = "data/#{id}.json"
    return nil unless File.exists?(fname)
    JSON.parse(File.read(fname))
  end

  def query(id)
    house_id = parse_room(id)[:house_id]
    query_params = {
      id: id,
      house_id: house_id,
    }
    res = Net::HTTP.get(URI(ZRoomAPI.pc(query_params)))
    JSON.parse(res)
  end


  def refresh(room)
    begin
      data = mquery(room[:id], room[:house_id])
    rescue
      return nil
    end
    return nil if data.nil?

    File.open("data/#{room[:id]}.json", 'w') do |f|
      f.write(data.to_json)
    end

    roomdb = YAML::Store.new('zroom.yml')

    roomdb.transaction do
      roomdb[:rooms][room[:id]][:last_update] = Time.now.to_i
    end
  end


  def mquery(id, house_id=nil)
    house_id = parse_room(id)[:house_id] if house_id.nil?
    query_params = {
      network: 'WIFI',
      app_version: '5.5.3',
      house_id: house_id,
      id: id,
      city_code: '110000',
      imei: '863664000059021',
    }
    uri=URI(ZRoomAPI.m(query_params))

    req = Net::HTTP::Get.new(uri)
    req['Accept'] = "application/json;version=3"
    req['Host'] = uri.host
    req['User-Agent'] = "okhttp/3.9.0"

    res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: true}) { |http| http.request(req) }
    return nil if res.code != "200"

    json = JSON.parse(res.body)

    return nil if json["error_code"]!=0

    json["data"]
  end
end
end
