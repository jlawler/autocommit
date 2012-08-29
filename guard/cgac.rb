require 'rubygems'
# /* vim: set filetype=ruby: */
require 'daemons'
require 'daemons/pid'
class CgPidfile
  attr_accessor :pid_path
  def initialize(path)
    self.pid_path=path
  end
  def kill!
    Process.kill("KILL",self.pid) if self.pid
  end
  def is_running?
    self.pid and Daemons::Pid.running?(self.pid)
  end
  def pid
    File.exists?(pid_path) and File.read(self.pid_path).chomp.to_i
  end
  def update! this_pid=$$
    File.open(pid_path,File::WRONLY|File::TRUNC|File::CREAT){|fh|
      fh.puts this_pid
    }
  end
end
require 'guard'
require 'guard/guard'
require 'thread'

module ::Guard
  class Cgautocommit < Guard
    def autocommit!
      semaphore.synchronize do 

      `cd ~/gist && git add -A`
      `cd ~/gist && git commit -a -m autocommit`
      `cd ~/gist && git push`
      STDERR.puts "COMMITING"
      end
    end
    def semaphore
      @semaphore ||= Mutex.new
    end
    def push_pull
      semaphore.synchronize do
        `cd ~/gist && git pull`
        `cd ~/gist && git push`
      end
    end
    def start
      Thread.new do 
        loop do 
          push_pull
          sleep 30
        end  
      end 
      #STDERR.puts "START"
    end

    def stop
      #STDERR.puts "STOP"
      pidfile.kill!
    end

    def reload
      stop
      start
    end

    def run_all
      true
    end
    def run_on_addition(paths)
      autocommit!
      true
    end
    def run_on_removal(paths)
      autocommit!
      true
    end

    def run_on_change(paths)
      autocommit!
      true
    end

    def run_on_additions(paths)
      autocommit!
      true
    end
    def run_on_removals(paths)
      autocommit!
      true
    end

    def run_on_changes(paths)
      autocommit!
      true
    end

    private

    def pidfile_path
      options.fetch(:pidfile) {
        File.realpath File.expand_path('tmp.pid', File.dirname(__FILE__))
      }
    end

    def config
eval "
daemonize yes
pidfile #{pidfile_path}
"
    end

    def pidfile
      @pidfile||=CgPidfile.new pidfile_path
    end
  end
end
