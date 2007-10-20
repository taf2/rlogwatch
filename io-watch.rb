# This is a ruby implementation of tail -f
# hopefully it may be useful to people wanting to watch log files
# but may have other interesting uses as well...

require "fcntl"

fd = open("test.log", "r")
fd.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
watchfiles = [fd]

read_buffer = ""
line_buffer = ""

while( 1 )

  input_ready = select(watchfiles,[],[],1)[0]
  input_ready.each do |f|
 
    begin
      read_buffer << f.sysread(16)
      lines = read_buffer.split(/\n/)
      #puts "'#{lines.size}' => #{read_buffer.inspect}"
      if lines.size == 1
        if read_buffer.match(/\n$/)
          puts "line => #{read_buffer.inspect}"
          read_buffer = ""
        end
      else
        read_buffer = lines.pop unless lines.empty?
        lines.each do|line|
          puts "line => #{line.inspect}"
        end
        if read_buffer.match(/\n$/)
          puts "line => #{read_buffer.inspect}"
          read_buffer = ""
        end
      end
    rescue EOFError => e
      sleep 1
      #read_for -= 1
    end

  end

end

