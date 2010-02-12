require 'ahp_pidfile'
require 'ahp_log'
require 'yaml'

class AhpIpc
  SCOREBOARD=Hash.new{|h,k|h[k]=Hash.new}
  include AhpLog
  class<<self
    include AhpLog
  end
  def self.pidfile
    @@pidfile||=AhpPidFile.new(pidfile_path)
  end
  def self.daemon_running?
    pidfile.running?
  end
  def self.config
    @@config||=YAML.load(File.read(AhpLog.config_file_path)) if File.exists? AhpLog.config_file_path
    @@config||={}
  end
  def self.start_daemon!
    create_files!
    self.pidfile.pid=$$
    update_scoreboard_file
    self.start_loop!
  end
  def self.start_loop!
    if config and config['autostart']
      [*config['autostart']].compact.each do |path|
        debug "autostarting #{path}"
        if File.exists?(path) and File.exists?(File.join(path,'.git'))
          next Ahp.new(path).run
        end
      end
    end
    while ary = AhpIpc.get_command
      cmd,path = *ary
      case cmd.downcase
      when 'shutdown'
        debug "Received shutdown command, shutting down..."
        Kernel.exit
      when 'create'
        `cd #{path} && git init` unless File.exists?(File.join(path,'.git'))
        Ahp.new(path).run
      when 'start'
        if File.exists?(path) and File.exists?(File.join(path,'.git'))
          next Ahp.new(path).run
        end
        puts path + " doesn't exist or doesn't have a .git dir"
      end 
    end
    STDERR.puts "start_loop is about to exit!  get_command returned " + ary.inspect
  end
  def self.create_files!
    Dir.mkdir(ah_dir) unless File.exists?(ah_dir) rescue nil
    `mkfifo #{control_path}` unless File.exists?(control_path) rescue nil
    raise "Totally screwed!  Can't create the dirs/files I need! #{control_path}" unless File.exists?(control_path)
  end
  def self.write_command cmd,path
    @@output||= open(control_path, "w+") # the r+ means we don't block
    @@output.puts [cmd,path].join(':')
    @@output.flush
  end
  def self.input
    @@input||= open(control_path, "r+") # the r+ means we don't block
  end

  def self.get_command
    while cmd_string = input.gets or true
      if cmd_string=~/^([^:]+):(.*)$/
        cmd,path=$1,$2
        return [cmd,path]
      else
        STDERR.puts "Couldn't parse command "+cmd_string.inspect
      end
    end
  end
  def self.add_stat(path,hsh)
    raise "#{hsh.class.name} #{hsh.inspect} IS NOT A HASH" unless Hash===hsh
    SCOREBOARD[path].merge!(hsh)
    debug SCOREBOARD.inspect
    update_scoreboard_file
  end
  def self.update_scoreboard_file
    debug "WRITING SCOREBOARD " + scoreboard_path
    File.open(scoreboard_path, File::WRONLY|File::TRUNC|File::CREAT){|fh|
      fh.puts YAML::dump(SCOREBOARD)
    }
  end
  def self.read_scoreboard_file
    return {} unless self.daemon_running? 
    return YAML::load(File.read(scoreboard_path)) rescue nil
    return {} 
    debug "WRITING SCOREBOARD " + scoreboard_path
    File.open(scoreboard_path, File::WRONLY|File::TRUNC|File::CREAT){|fh|
      fh.puts YAML::dump(SCOREBOARD)
    }
  end
  #Time.now.to_i - File.stat('/home/jlawler/x').mtime.to_i
end
