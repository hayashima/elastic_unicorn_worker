require 'aws-sdk'

class Mail
  def send(send_addresses, message)
    client = Aws::SES::Client.new(region: 'us-east-1')
    client.send_email({
    source: "admin@bondgate.jp",
    destination: {
      to_addresses: send_addresses,
    },
    message: {
      subject: {
        data: 'UnicornのWorker数伸縮失敗',
      },
      body: {
        text: {
          data: message,
        },
        html: {
          data: message,
        },
      },
    }})
  end
end
