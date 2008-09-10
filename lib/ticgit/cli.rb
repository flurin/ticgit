require 'ticgit'
require 'thor'

module TicGit
  class CLI < Thor
    attr_reader :tic
    
    def initialize(opts = {}, *args)
      @tic = TicGit.open('.', :keep_state => true)
      $stdout.sync = true # so that Net::SSH prompts show up
    rescue NoRepoFound
      puts "No repo found"
      exit
    end
    
    # tic milestone
    # tic milestone migration1 (list tickets)
    # tic milestone -n migration1 3/4/08 (new milestone)
    # tic milestone -a {1} (add ticket to milestone)
    # tic milestone -d migration1 (delete)
    desc "milestone [<name>]", %(Add a new milestone to this project)
    method_options :new => :optional, :add => :optional, :delete => :optional
    def milestone(name = nil)
      raise NotImplementedError
    end

    desc "recent [<ticket-id>]", %(Recent ticgit activity)
    def recent(ticket_id = nil)
      tic.ticket_recent(ticket_id).each do |commit|
        puts commit.sha[0, 7] + "  " + commit.date.strftime("%m/%d %H:%M") + "\t" + commit.message
      end
    end
    
    desc "tag [<ticket-id>] [<tag1,tag2...>]", %(Add or remove ticket tags)
    method_options %w(--remove -d) => :boolean
    def tag(*args)
      puts 'remove' if options[:remove]
      
      tid = args.size > 1 && args.shift
      tags = args.first
      
      if tags
        tic.ticket_tag(tags, tid, options)
      else  
        puts 'You need to at least specify one tag to add'
      end
    end
    
    desc "comment [<ticket-id>]", %(Comment on a ticket)
    method_options :message => :optional, :file => :optional
    def comment(ticket_id = nil)
      if options[:file]
        raise ArgumentError, "Only 1 of -f/--file and -m/--message can be specified" if options[:message]
        file = options[:file]
        raise ArgumentError, "File #{file} doesn't exist" unless File.file?(file)
        raise ArgumentError, "File #{file} must be <= 2048 bytes" unless File.size(file) <= 2048
        tic.ticket_comment(File.read(file), ticket_id)
      elsif m = options[:message]
        tic.ticket_comment(m, ticket_id)
      else
        if message = get_editor_message
          tic.ticket_comment(message.join(''), ticket_id)
        end
      end
    end

    desc "checkout <ticket-id>", %(Checkout a ticket)
    def checkout(ticket_id)
      tic.ticket_checkout(ticket_id)
    end
    
    desc "state [<ticket-id>] <state>", %(Change state of a ticket)
    def state(id_or_state, state = nil)
      if state.nil?
        state = id_or_state
        ticket_id = nil
      else
        ticket_id = id_or_state
      end
      
      if valid_state(state)
        tic.ticket_change(state, ticket_id)
      else
        puts 'Invalid State - please choose from : ' + tic.tic_states.join(", ")
      end
    end
    
    # Assigns a ticket to someone
    #
    # Usage:
    # ti assign             (assign checked out ticket to current user)
    # ti assign {1}         (assign ticket to current user)
    # ti assign -c {1}      (assign ticket to current user and checkout the ticket)
    # ti assign -u {name}   (assign ticket to specified user)
    desc "assign [<ticket-id>]", %(Assign ticket to user)
    method_options :user => :optional, :checkout => :optional
    def assign(ticket_id = nil)
      tic.ticket_checkout(options[:checkout]) if options[:checkout]
      tic.ticket_assign(options[:user], ticket_id)
    end

    # "-o ORDER", "--order ORDER", "Field to order by - one of : assigned,state,date"
    # "-t TAG", "--tag TAG", "List only tickets with specific tag"
    # "-s STATE", "--state STATE", "List only tickets in a specific state"
    # "-a ASSIGNED", "--assigned ASSIGNED", "List only tickets assigned to someone"
    # "-S SAVENAME", "--saveas SAVENAME", "Save this list as a saved name"
    # "-l", "--list", "Show the saved queries"
    desc "list [<saved-query>]", %(Show existing tickets)
    method_options :order => :optional, :tag => :optional, :state => :optional,
                   :assigned => :optional, :list => :optional, %w(--save-as -S) => :optional
                   
    def list(saved_query = nil)
      opts = options.dup
      opts[:saved] = saved_query if saved_query
      
      if tickets = tic.ticket_list(opts)
        output_ticket_list(tickets)
      end
    end
    
    ## SHOW TICKETS ##
    
    desc 'show <ticket-id>', %(Show a single ticket)
    def show(ticket_id = nil)
      if t = @tic.ticket_show(ticket_id)
        ticket_show(t)
      end
    end
    
    desc 'new', %(Create a new ticket)
    method_options :title => :optional
    def new
      if title = options[:title]
        ticket_show(@tic.ticket_new(title, options))
      else
        # interactive
        message_file = Tempfile.new('ticgit_message').path
        File.open(message_file, 'w') do |f|
          f.puts "\n# ---"
          f.puts "tags:"
          f.puts "# first line will be the title of the tic, the rest will be the first comment"
          f.puts "# if you would like to add initial tags, put them on the 'tags:' line, comma delim"
        end
        
        if message = get_editor_message(message_file)
          title = message.shift
          if title && title.chomp.length > 0
            title = title.chomp
            if message.last[0, 5] == 'tags:'
              tags = message.pop
              tags = tags.gsub('tags:', '')
              tags = tags.split(',').map { |t| t.strip }
            end
            if message.size > 0
              comment = message.join("")
            end
            ticket_show(@tic.ticket_new(title, :comment => comment, :tags => tags))
          else
            puts "You need to at least enter a title"
          end
        else
          puts "It seems you wrote nothing"
        end
      end
    end
    
    protected
    
    def valid_state(state)
      tic.tic_states.include?(state)
    end
    
    def ticket_show(t)
      days_ago = ((Time.now - t.opened) / (60 * 60 * 24)).round.to_s
      puts
      puts just('Title', 10) + ': ' + t.title
      puts just('TicId', 10) + ': ' + t.ticket_id
      puts
      puts just('Assigned', 10) + ': ' + t.assigned.to_s 
      puts just('Opened', 10) + ': ' + t.opened.to_s + ' (' + days_ago + ' days)'
      puts just('State', 10) + ': ' + t.state.upcase
      if !t.tags.empty?
        puts just('Tags', 10) + ': ' + t.tags.join(', ')
      end
      puts
      if !t.comments.empty?
        puts 'Comments (' + t.comments.size.to_s + '):'
        t.comments.reverse.each do |c|
          puts '  * Added ' + c.added.strftime("%m/%d %H:%M") + ' by ' + c.user
          
          wrapped = c.comment.split("\n").collect do |line|
            line.length > 80 ? line.gsub(/(.{1,80})(\s+|$)/, "\\1\n").strip : line
          end * "\n"
          
          wrapped = wrapped.split("\n").map { |line| "\t" + line }
          if wrapped.size > 6
            puts wrapped[0, 6].join("\n")
            puts "\t** more... **"
          else
            puts wrapped.join("\n")
          end
          puts
        end
      end
    end
    
    def get_editor_message(message_file = nil)
      message_file = Tempfile.new('ticgit_message').path if !message_file
      
      editor = ENV["EDITOR"] || 'vim'
      system("#{editor} #{message_file}");
      message = File.readlines(message_file)
      message = message.select { |line| line[0, 1] != '#' } # removing comments   
      if message.empty?
        return false
      else
        return message
      end   
    end
    
    def just(value, size, side = 'l')
      value = value.to_s
      if value.size > size
        value = value[0, size]
      end
      if side == 'r'
        return value.rjust(size)
      else
        return value.ljust(size)
      end
    end
    
    def output_ticket_list(tickets)
      counter = 0
    
      puts
      puts [' ', just('#', 4, 'r'), 
            just('TicId', 6),
            just('Title', 25), 
            just('State', 5),
            just('Date', 5),
            just('Assgn', 8),
            just('Tags', 20) ].join(" ")
          
      a = []
      80.times { a << '-'}
      puts a.join('')

      tickets.each do |t|
        counter += 1
        tic.current_ticket == t.ticket_name ? add = '*' : add = ' '
        puts [add, just(counter, 4, 'r'), 
              t.ticket_id[0,6], 
              just(t.title, 25), 
              just(t.state, 5),
              t.opened.strftime("%m/%d"), 
              just(t.assigned_name, 8),
              just(t.tags.join(','), 20) ].join(" ")
      end
      puts
    end
    
  end
end