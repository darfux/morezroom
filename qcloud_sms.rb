require 'net/http'
require 'securerandom'
require 'digest'
require 'yaml'
require 'json'

class QcloudSMS
class << self
  def gen_sig(time, mobile, rnd)
    base = URI.encode_www_form(appkey: @appkey, random: rnd.to_s, time: time.to_s, mobile: mobile)
    Digest::SHA256.hexdigest base
  end
  def send_to(mobile, params)
    config = YAML.load_file("config.yml")

    rnd = SecureRandom.hex(4).to_i(16)
    @appid = config[:appid]
    @appkey = config[:appkey]
    query = URI.encode_www_form({sdkappid: @appid, random: rnd})
    uri = URI("https://yun.tim.qq.com/v5/tlssmssvr/sendsms?#{query}")
    time = Time.now.to_i
    param = {
        "ext": "mzroom",
        "params": params,
        "sig": gen_sig(time, mobile, rnd),
        "sms_type": 0,
        "tel": {
            "nationcode": "86",
            "mobile": mobile,
        },
        "time": time,
        "tpl_id": 115201
    }

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = param.to_json
    res = Net::HTTP.start(uri.hostname, uri.port, {use_ssl: true}) do |http|
      http.request(req)
    end
    p res.body
  end
end
end

# QcloudSMS.send_to('xxxxxx', ["61136683", "zxpzz_1"])
