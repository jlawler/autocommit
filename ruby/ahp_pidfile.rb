class AhpPidFile
  attr_accessor :path
  def initialize path
    self.path=path
  end
  def pid=newpid
    File.open(path, File::WRONLY|File::TRUNC|File::CREAT){|fh|fh.puts newpid}
  end 
  def pid
    pid = File.read(path).split("\n").first.to_i rescue nil
    return pid if Numeric===pid and pid>0
  end
  def running?
    return false unless pid
    # Check if process is in existence
    # The simplest way to do this is to send signal '0'
    # (which is a single system call) that doesn't actually
    # send a signal
    begin
      Process.kill(0, pid)
      return true
    rescue Errno::ESRCH
      return false
    rescue ::Exception  
      return true
    end
  end
end
