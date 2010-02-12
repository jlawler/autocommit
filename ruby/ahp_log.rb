
module AhpLog
  
  AH_DIR = File.join(ENV['HOME'],'.autocommit')
  def ah_dir
    AH_DIR
  end
  def config_file_path
    File.join(AH_DIR,'autocommitrc')
  end
  def debug_log_fh
    @@debug_log_fh||=begin
      File.open(self.debug_log_path, File::WRONLY|File::CREAT)
    end
  end
  def error_log_fh
    @@error_log_fh||=begin
      File.open(self.error_log_path, File::WRONLY|File::CREAT)
    end
  end
  module_function :debug_log_fh, :error_log_fh
  def debug *args
    return unless ENV['DEBUG']
    [*args].compact.each do |arg|
      AhpLog.debug_log_fh.puts arg
      STDERR.puts arg rescue nil 
    end
  end
  def error *args
    [*args].compact.each do |arg|
      AhpLog.error_log_fh.puts arg 
      AhpLog.debug_log_fh.puts arg if ENV['DEBUG'] rescue nil
    end
  end
  def debug_log_path
    File.join(AH_DIR,'debug_log')
  end
  def error_log_path
    File.join(AH_DIR,'error_log')
  end
  def pidfile_path
    File.join(AH_DIR,'ahp.pid')
  end
  def scoreboard_path
    File.join(AH_DIR,'scoreboard')
  end
  def control_path
    File.join(AH_DIR,'control')
  end
  module_function :debug_log_path, :error_log_path, :pidfile_path, :scoreboard_path, :control_path, :config_file_path
end
