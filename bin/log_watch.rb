#!/usr/bin/env ruby
# From mongrel

SERVER_ROOT=File.expand_path("#{File.dirname(__FILE__)}/../")
$: << "#{SERVER_ROOT}/lib"
require "log_watch"
require 'rubygems'
require 'mongrel'
require 'mongrel/handlers'

module Mongrel

  class Start < GemPlugin::Plugin "/commands"
		include Mongrel::Command::Base

    def configure
			options [
					["-d", "--daemonize", "Run daemonized in the background", :@daemon, false],
					['-p', '--port PORT', "Which port to bind to", :@port, 4000],
					['-a', '--address ADDR', "Address to bind to", :@address, "0.0.0.0"],
					['-l', '--log FILE', "Where to write log messages", :@log_file, "log/logwatch.log"],
					['-P', '--pid FILE', "Where to write the PID", :@pid_file, "log/logwatch.pid"],
					['-c', '--chdir PATH', "Change to dir before starting (will be expanded)", :@cwd, Dir.pwd],
					['-B', '--debug', "Enable debugging mode", :@debug, false],
					['-C', '--config PATH', "Use a config file", :@config_file, nil],
					['', '--user USER', "User to run as", :@user, nil],
					['', '--group GROUP', "Group to run as", :@group, nil],
					['', '--prefix PATH', "URL prefix for cache server", :@prefix, nil]
			]
		end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

      # Change there to start, then we'll have to come back after daemonize
      Dir.chdir(@cwd)

      valid?(@prefix[0].chr == "/" && @prefix[-1].chr != "/", "Prefix must begin with / and not end in /") if @prefix
      valid_dir? File.dirname(@log_file), "Path to log file not valid: #@log_file"
      valid_dir? File.dirname(@pid_file), "Path to pid file not valid: #@pid_file"
      valid_exists? @mime_map, "MIME mapping file does not exist: #@mime_map" if @mime_map
      valid_exists? @config_file, "Config file not there: #@config_file" if @config_file
      valid_user? @user if @user
      valid_group? @group if @group

      return @valid
    end

    def run
      # Config file settings will override command line settings
      settings = { :host => @address,  :port => @port, :cwd => @cwd,
        :log_file => @log_file, :pid_file => @pid_file, :environment => @environment,
        :daemon => @daemon, :debug => @debug, :includes => ["logwatch"], :config_script => @config_script,
        :num_processors => @num_procs, :timeout => @timeout,
        :user => @user, :group => @group, :prefix => @prefix, :config_file => @config_file
      }

      if @config_file
        settings.merge! YAML.load_file(@config_file)
        STDERR.puts "** Loading settings from #{@config_file} (they override command line)." unless settings[:daemon]
      end

			config = Mongrel::Configurator.new(settings) do
        if defaults[:daemon]
          if File.exist? defaults[:pid_file]
            log "!!! PID file #{defaults[:pid_file]} already exists.  Mongrel could be running already.  Check your #{defaults[:log_file]} for errors."
            log "!!! Exiting with error.  You must stop mongrel and clear the .pid before I'll attempt a start."
            exit 1
          end

          daemonize
          log "Daemonized, any open files are closed.  Look at #{defaults[:pid_file]} and #{defaults[:log_file]} for info."
          log "Settings loaded from #{@config_file} (they override command line)." if @config_file
        end

        log "Starting Mongrel listening at #{defaults[:host]}:#{defaults[:port]}"

				listener do
					uri "/", :handler => DirHandler.new("#{SERVER_ROOT}/public")
					uri "/log", :handler => LogWatch.new()
				end
      end

      config.run
      config.log "Mongrel available at #{settings[:host]}:#{settings[:port]}"

      if config.defaults[:daemon]
        config.write_pid_file
      else
        config.log "Use CTRL-C to stop." 
      end

      config.join

      if config.needs_restart
        if RUBY_PLATFORM !~ /mswin/
          cmd = "ruby #{__FILE__} start #{original_args.join(' ')}"
          config.log "Restarting with arguments:  #{cmd}"
          config.stop
          config.remove_pid_file

          if config.defaults[:daemon]
            system cmd
          else
            STDERR.puts "Can't restart unless in daemon mode."
            exit 1
          end
        else
          config.log "Win32 does not support restarts. Exiting."
        end
      end
    end

	end

  def Mongrel::send_signal(signal, pid_file)
    pid = open(pid_file).read.to_i
    print "Sending #{signal} to Mongrel at PID #{pid}..."
    begin
      Process.kill(signal, pid)
    rescue Errno::ESRCH
      puts "Process does not exist.  Not running."
    end

    puts "Done."
  end

  class Stop < GemPlugin::Plugin "/commands"
    include Mongrel::Command::Base

    def configure 
      options [ 
        ['-c', '--chdir PATH', "Change to dir before starting (will be expanded).", :@cwd, "."],
        ['-f', '--force', "Force the shutdown (kill -9).", :@force, false],
        ['-w', '--wait SECONDS', "Wait SECONDS before forcing shutdown", :@wait, "0"], 
        ['-P', '--pid FILE', "Where the PID file is located.", :@pid_file, "log/logwatch.pid"]
      ]
    end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

      Dir.chdir @cwd

      valid_exists? @pid_file, "PID file #@pid_file does not exist.  Not running?"
      return @valid
    end

    def run
      if @force
        @wait.to_i.times do |waiting|
          exit(0) if not File.exist? @pid_file
          sleep 1
        end

        Mongrel::send_signal("KILL", @pid_file) if File.exist? @pid_file
      else
        Mongrel::send_signal("TERM", @pid_file)
      end
    end
  end

  class Restart < GemPlugin::Plugin "/commands"
    include Mongrel::Command::Base

    def configure 
      options [ 
        ['-c', '--chdir PATH', "Change to dir before starting (will be expanded)", :@cwd, '.'],
        ['-s', '--soft', "Do a soft restart rather than a process exit restart", :@soft, false],
        ['-P', '--pid FILE', "Where the PID file is located", :@pid_file, "log/logwatch.pid"]
      ]
    end

    def validate
      @cwd = File.expand_path(@cwd)
      valid_dir? @cwd, "Invalid path to change to during daemon mode: #@cwd"

      Dir.chdir @cwd

      valid_exists? @pid_file, "PID file #@pid_file does not exist.  Not running?"
      return @valid
    end

    def run
      if @soft
        Mongrel::send_signal("HUP", @pid_file)
      else
        Mongrel::send_signal("USR2", @pid_file)
      end
    end
  end
end

# usage: add --path /path/to/your/app
#        add --path /path/to/your/app --default
class Add < GemPlugin::Plugin "/commands"
  include Mongrel::Command::Base

  def configure 
    options [ 
      ['-p', '--path PATH', "Add a new rails application routes", :@cwd, "."],
      ['-d', '--default', "Mark the rails application at PATH as the default, use in combintation with --path", :@force, false],
    ]
  end

  def validate
    @cwd = File.expand_path(@cwd)
    valid_dir? @cwd, "Rails project folder does not exist, '#{@cwd}'"

    valid_exists? "#{@cwd}/config/routes.rb", "Missing routes.rb are you sure the path '#{@cwd}' is valid and is a real Rails project?"
    valid_dir? "#{@cwd}/app/controllers", "No controller found in project folder => '#{@cwd}'"

    return @valid
  end
 
  def run
    system( %Q(ruby #{File.expand_path("#{File.dirname(__FILE__)}/print_routes.rb")} #{@cwd}) )
  end

end

if not Mongrel::Command::Registry.instance.run ARGV
  exit 1
end
