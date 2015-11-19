require 'yaml'
require 'sys/proctable'
require './mail'

class ElasticUnicornWorker
  TIMEOUT = 10

  def initialize
    @settings = YAML.load_file("pid.yml")
    @log_file = "logs/elastic_unicorn_worker#{Time.now.strftime("%Y%m%d%H%M%S")}.log"
  end

  def down_to_child_process(pid, n)
    return if child_process_count(pid) == 1
    down_worker(pid)
    started_at = Time.now
    while child_process_count(pid) > n
      log_write("pid=#{pid} down to #{n}...")
      sleep 1
      raise 'Timeout.' if Time.now > started_at + TIMEOUT
      next
    end
    log_write("pid=#{pid} down to #{n} complete.")
  end

  def up_to_child_process(pid, n)
    up_worker(pid)
    started_at = Time.now
    while child_process_count(pid) < n
      log_write("pid=#{pid} up to #{n}...")
      sleep 1
      raise 'Timeout.' if Time.now > started_at + TIMEOUT
      next
    end
    log_write("pid=#{pid} up to #{n} complete.")
  end

  def execute
    @settings['unicorn'].each do |unicorn|
      log_write("#{unicorn['name']} started.")
      open(unicorn['pid'], 'r') do |f|
        workers = unicorn['workers']
        pid = f.read.to_i
        (child_process_count(pid) - 1).downto(1) do |n|
          down_to_child_process(pid, n)
        end
        2.upto(workers) do |n|
          up_to_child_process(pid, n)
        end
      end
      log_write("#{unicorn['name']} completed.")
    end
  end

  def child_process_count(pid)
    Sys::ProcTable.ps.select{ |pe| pe.ppid == pid }.size
  end

  def down_worker(pid)
    Process.kill('TTOU', pid)
  end

  def up_worker(pid)
    Process.kill('TTIN', pid)
  end

  def log_write(str)
    open(@log_file, 'a') do |f|
      f.write(Time.now.strftime("%Y-%m-%d %H:%M:%S"))
      f.write(' ')
      f.write(str)
      f.write("\n")
    end
  end

  def send_mail(messages)
    send_addresses = @settings['mail']
    return if send_addresses.nil?
    mail = Mail.new
    mail.send(send_addresses, current_log + messages)
  end

  def current_log
    open(@log_file, 'r').read
  end
end

obj = ElasticUnicornWorker.new
begin
  obj.execute
rescue => e
  obj.log_write(e.message)
  obj.send_mail(e.message)
end
