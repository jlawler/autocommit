require 'ahp_pidfile'
require 'yaml'

class AhpIpc
  SCOREBOARD={}
  AH_DIR = File.join(ENV['HOME'],'autohistory')
  def self.pidfile_path
    File.join AH_DIR,'ahp.pid'
  end
  def self.scoreboard_path
    File.join(AH_DIR,'scoreboard')
  end
  def self.control_path
    File.join(AH_DIR,'control')
  end
  def self.pidfile
    @@pidfile||=AhpPidFile.new(pidfile_path)
  end
  def self.daemon_running?
    pidfile.running?
  end
  def self.start_daemon!
    self.pidfile.pid=$$
    update_scoreboard_file
    self.start_loop!
  end
  def self.start_loop!
while ary = AhpIpc.get_command
  cmd,path = *ary
  STDERR.puts "COMMAND = "+cmd
  case cmd.downcase
  when 'shutdown'
    Kernel.exit
  when 'pause'
    unless AhpHash[path]
      puts path + " isn't running"
    else
      puts "fake pause " + path
    end
  when 'stop'
    unless AhpHash[path]
      puts path + " isn't running"
    else
      puts "fake stop " + path
    end
  when 'create'
    unless File.exists?(File.join(path,'.git'))
      `cd #{path} && git init`
    end
    Ahp.new(path).run
  when 'start'
    unless File.exists?(path)
      puts path + " doesn't exist"
      next
    end
    unless File.exists?(File.join(path,'.git'))
      puts "No git dir!"
      next
    end
    Ahp.new(path).run
    puts "fake start " + path

  end 
  puts [cmd,path].inspect
end
end

=begin
    def Pid.running?(pid)
      # Check if process is in existence
      # The simplest way to do this is to send signal '0'
      # (which is a single system call) that doesn't actually
      # send a signal
      begin
        Process.kill(0, pid)
        return true
      rescue Errno::ESRCH
        return false
      rescue ::Exception   # for example on EPERM (process exists but does not belong to us)
        return true
      #rescue Errno::EPERM
      #  return false
      end
    end


  end
=end
#STDERR.puts history_dir.inspect
#STDERR.puts control_path.inspect
  def self.create_files
    Dir.mkdir(history_dir) unless File.exists?(history_dir)
    unless File.exists?(control_path)
      `mkfifo #{control_path}`
    end  
  end
  def self.sanity_check!
    unless File.exists?(control_path)
      raise "Totally screwed!"
    end
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
    cmd_string = input.gets
    cmd_string=~/^([^:]+):(.*)$/
    cmd,path=$1,$2
    return [cmd,path]
  end
  def self.add_stat(path,hsh)
    raise "#{hsh.class.name} #{hsh.inspect} IS NOT A HASH" unless Hash===hsh
    SCOREBOARD[path]||={}
    SCOREBOARD[path].merge!(hsh)
    update_scoreboard_file
  end
def self.debug str
  return unless ENV['DEBUG']
  puts str
end

  def self.update_scoreboard_file
    debug "WRITING SCOREBOARD " + self.scoreboard_path
    File.open(self.scoreboard_path, File::WRONLY|File::TRUNC|File::CREAT){|fh|
      fh.puts YAML::dump(SCOREBOARD)
    }
  end
  def self.read_scoreboard_file
    return {} unless self.daemon_running? 
    return YAML::load(File.read(self.scoreboard_path)) rescue nil
    return {} 
    debug "WRITING SCOREBOARD " + self.scoreboard_path
    File.open(self.scoreboard_path, File::WRONLY|File::TRUNC|File::CREAT){|fh|
      fh.puts YAML::dump(SCOREBOARD)
    }
  end

end


