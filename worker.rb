require 'ruby-pinyin'
require 'yaml/store'
require_relative 'zroom'
require_relative 'qcloud_sms'
require 'logger'

logger = Logger.new("log/worker.log")
# logger = Logger.new(STDOUT)
logger.level = Logger::INFO


db = YAML::Store.new('sitedb.yml')
config = YAML.load_file("config.yml")

loop do
  begin
    logger.info "RUNING room update"
    rooms = nil
    db.transaction(true) do
      rooms = db.fetch(:rooms, {})
    end

    notify_queue = []
    counter = 0
    rooms.each do |id, _v|
      next unless _v[:notify]
      room = ZRoom.parse_room(id)
      old_data = ZRoom.room_data(id)
      ret = ZRoom.refresh(room)
      if ret.nil?
        next
      end
      counter += 1
      data = ZRoom.room_data(id)
      name = data['name'].split("·")[-1]
      puts "#{name}_#{id}"
      py = PinYin.abbr(name)[0..5]
      p0 = "[#{id}]#{py}"
      reserve_changed = old_data['is_reserve'] != data['is_reserve']
      status_changed = old_data['status'] != data['status']

      if reserve_changed || status_changed
        p1 = "#{data['status']}(#{data['is_reserve']})"
        notify_queue << {id: id, msg: [p0, p1]}
        break
      end
      sleep 1+rand*2
    end

    notify_queue.each do |data|
      logger.info "Send msg #{data[:msg]}"
      ret = QcloudSMS.send_to(config[:phone], data[:msg])
      logger.info "RET: #{ret}"
      ret = JSON.parse(ret)
      if ret["result"] == 0
        logger.info "SUCCESS, change room#{data[:id]} notify"
        db.transaction do
          db[:rooms][data[:id]][:notify] = false
        end
      end
      break
    end
    logger.info "Updated #{counter} rooms"
  rescue Interrupt => e
    logger.info "Interrupted #{e.message}"
    break
  rescue Exception => e
    logger.warn e.message
  end
  hour = Time.now.hour
  if hour >= 8 && hour <= 23
    sleep 66
  else
    sleep 3600
  end
end
