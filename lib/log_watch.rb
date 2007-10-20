
# excellent reference:
# http://www.artima.com/forums/flat.jsp?forum=123&thread=171613

require "fcntl"
require 'timeout'
require "uri"
require 'rubygems'
require 'fastthread'
require 'mongrel/handlers'

module Mongrel
  module Const
    COMET_FORMAT = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n".freeze
  end
  class HttpResponse
    def comet(type,  status=200)
      write(Const::COMET_FORMAT % [status, HTTP_STATUS_CODES[status], type])
      write("\r\n")
      return HttpComet.new(self)
    end
    def flush
      @socket.flush
    end
  end
end

class HttpComet
  def initialize(response)
    @response = response
  end

  def write(data)
    size = data.size
    @response.write(sprintf("%x;\r\n", size))
    @response.write(data)
    @response.write("\r\n")
    #@response.flush
  end

  def close
    @response.write("0;\r\n")
  end
end


class LogWatch < Mongrel::HttpHandler
  MAX_LOG_READ = 1024.freeze

  # this tells mongrel to call request_begins
  def request_notify; true ; end
 
  def request_begins(params)
    @start = Time.now
    @params = {}
    params["QUERY_STRING"].split(/&/).each do|key_value|
      k, v = key_value.split(/=/)
      @params[k] = v
    end
    @xml_http_request = params["HTTP_XML_HTTP_REQUEST"]
    @log_file = @params["file"]
    @seek_pos = @params["offset"].to_i || 0
  end
 
  def request_progress(params, clen, total)
  end
 
  def process(request, response)
    comet = nil

    begin
      Timeout::timeout(5) do

        comet = response.comet("text/html")
        read_log( comet )

      end
    rescue Timeout::Error => e
      puts e.backtrace
    end

    comet.close
 
    puts "\nCompleted => #{Time.now - @start} seconds with status #{@status}"
 
  end

  def read_log( comet )

    puts "opening '#{@log_file}'..."
    fd = open(@log_file, "r")
    return unless fd
    fd.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
    puts "seek_pos => #{@seek_pos.inspect} requested"
    fd.sysseek( @seek_pos, File::SEEK_SET ) if @seek_pos > 0
    watchfiles = [fd]

    read_buffer = ""

    while( 1 )

      input_ready = select(watchfiles,[],[],1)[0]
      input_ready.each do |f|
        begin
          messages = []
          read_buffer << f.sysread(MAX_LOG_READ)
          lines = read_buffer.split(/\n/)
          #puts "'#{lines.size}' => #{read_buffer.inspect}, #{count}"
          if lines.size == 1
            if read_buffer.match(/\n$/)
              messages << read_buffer
              read_buffer = ""
            end
          else
            read_buffer = lines.pop unless lines.empty?
            lines.each do|line|
              messages << line
            end
            if read_buffer.match(/\n$/)
              messages << read_buffer
              read_buffer = ""
            end
          end
          send_chunk( comet, messages )
        rescue EOFError => e
          sleep 1
        end
      end
    end

  rescue IOError 
    sleep 1
    retry
  rescue => e
    puts e.class
  ensure
    puts "finished"
    fd.close

  end

  def send_chunk( comet, messages )
    buffer = %Q(<script type='text/javascript'>)
    messages.each do|input|
      @seek_pos += input.size
      buffer << %Q(window.parent.logMessage\("#{URI.escape(input.strip)}"\);)
    end
    puts "seek_pos => #{@seek_pos.inspect} computed"
    buffer << %Q(window.parent.markOffset\(#{@seek_pos}\);)
    buffer << %Q(</script>)
    comet.write( buffer )
  end

end
