require 'inotify'
require 'find'
require 'thread'

puts "DEBUGGING ENABLED" if ENV['DEBUG']
class Ahp
  MIN_TIME_BETWEEN_COMITS = 10
  MAX_TIME_BETWEEN_COMITS = 60
  @@all_ahps={}
  attr_accessor :i,:root_path, :last_child, :last_commit
  def initialize root_path
    self.root_path = root_path
    @DIRS={}
    self.i = Inotify.new
    Find.find(root_path) do |e| 
    	if ['.git','.svn', 'CVS', 'RCS'].include? File.basename(e) or !File.directory? e
    		Find.prune
    	else
    		begin
    			debug "Adding #{e}"
    			add_watch(e)
    		rescue
    			debug "Skipping #{e}: #{$!}"
    		end
    	end
    end
  end
  def run
    @@all_ahps[self.root_path]=self
    AhpIpc.add_stat(self.root_path,{'start' => Time.now.to_i})
    Thread.new do
    	i.each_event do |ev|
        path = nil
        Thread.exclusive do
        if @DIRS[ev.wd] and ev.name
          path = File.join(@DIRS[ev.wd],ev.name) 
        else
          path = @DIRS[ev.wd] || ev.name
        end
        end
        debug ev.mask
        if ev.mask & Inotify::IGNORED != 0
          debug "INGORING!" + [ev.mask,Inotify::IGNORED,ev.mask & Inotify::IGNORED].inspect
        next 
        end
        if self.last_commit.nil? or Time.now.to_i - self.last_commit   >= MIN_TIME_BETWEEN_COMITS
          self.commit!
        end
        if ev.mask & Inotify::CREATE != 0 
          debug "CREATE " + (ev.mask ^ Inotify::CREATE).to_s + " " +  ev.name.inspect
          add_watch path
        elsif ev.mask & Inotify::DELETE != 0 
          debug "DELETE" 
          rm_watch ev.wd 
      	end
    	end
    end
  end
  def commit!
    debug "IN COMMIT THREAD!"
    Thread.exclusive do
      `cd #{self.root_path} && git add -A && git commit -m autocommit`
      self.last_commit = Time.now.to_i  
      self.last_child = $?
      AhpIpc.add_stat(self.root_path,{'last_commit' => self.last_commit})
      end
    end
  def debug str
    return unless ENV['DEBUG']
    puts str
  end
  def add_watch e
    debug "add watch #{e}"
    begin
      File.directory?(e) ? add_dir(e) : add_file(e)
    rescue Exception => e
      debug ["Failed to add watch",e.message,e.class.name,*e.backtrace].join("\n")
    end
  end
  
  def add_file e
    Thread.exclusive do 
    	z=i.add_watch(e, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY )
      @DIRS[z]=e 
    end
  end
  alias :add_dir :add_file 
  def rm_watch e
    debug "rm  watch #{e}"
    if @DIRS.values.include?(e)
      i.rm_watch(e)
    end
  end
end



