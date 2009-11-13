require 'inotify'
require 'find'
require 'thread'

class Ahp
attr_accessor :i
def initialize root_path
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
    if ev.mask & 256 != 0 
      debug "CREATE " + ev.name.inspect
      add_watch path
    elsif ev.mask & Inotify::DELETE != 0 
      debug "DELETE" 
      rm_watch ev.wd 
  	end
	end
end
end
def debug str
  return unless ENV['DEBUG']
  puts str
end
def add_watch e
  debug "add watch #{e}"
  if File.directory? e
    add_file e
  else
    add_dir e
  end
end

def add_file e
  Thread.exclusive do 
  	z=i.add_watch(e, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY )
    @DIRS[z]=e 
  end
end

def add_dir e
  Thread.exclusive do 
  	z=i.add_watch(e, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY  )
    @DIRS[z]=e 
  end
end
def rm_watch e
  debug "rm  watch #{e}"
  if @DIRS.values.include?(e)
    i.rm_watch(e)
  end
end
end




