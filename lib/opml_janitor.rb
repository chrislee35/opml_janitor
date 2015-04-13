require "opml_janitor/version"
require "opml_janitor/outline"
require 'nokogiri'
require 'open-uri'
require 'rss'
require 'timeout'
require 'thread'
require 'pp'

module OpmlJanitor # :nodoc:
  # The Parser class takes in the contents of an OPML XML document and
  # can filter and save the results
  class Parser
    # initialize takes the contents of an OPML XML document and a flag
    # for debug messages (default false)
    def initialize(contents, debug = false)
      @xml = contents
      @opml = Nokogiri::XML.parse(@xml)
      @debug = debug
      @threads = 1
      @timeout = 20
    end
    
    # debug= sets the debug flag
    def debug=(debug)
      @debug = debug
    end
    
    # timeout= sets the timeout for downloading and processing each feed
    # the default is 20 seconds
    def timeout=(timeout)
      @timeout = timeout
    end
    
    ##
    # threads= sets the number of threads for running the validation process
    def threads=(threads)
      @threads = threads
    end
    
    ##
    # from_filehandle allows the OPML XML document to be read from a given
    # filehandle and returns an initialized Parser instance
    def self.from_filehandle(filehandle)
      contents = filehandle.read
      Parser.new(contents)
    end
    
    ##
    # from_file takes in a filename and returns an initialized Parser instance
    def self.from_file(filename)
      from_filehandle(File.open(filename, 'r'))
    end
    
    ##
    # from_url takes in a URL as a string and returns an initialized Parser instance
    def self.from_url(url)
      from_filehandle(open(url).read)
    end
    
    ##
    # validate! takes in one argument, +since+, specifing a Time object. Since is used to check if any posts have been posted since that time, thus detecting "stale" blogs/rss feeds 
    def validate!(since = nil)
      # this threading methodology is highly expensive for simple blocks, but a life-saver for IO-bound blocks
      @work_queue = Queue.new
      data = @opml.css("body").children
      boss = Thread.new do
        filter!(data)
      end
      
      workers = (0...@threads).map do
        @work_queue.push(false) # this will end each thread
        Thread.new do
          begin
            while work = @work_queue.pop()
              val = validate_callback(work[:outline], since)
              spaces = 80 - work[:outline][:xml_url].length
              spaces = 1 if spaces < 1
              puts "#{work[:outline][:xml_url]}#{' ' * spaces}#{val}" if @debug
              unless val == "PASS"
                work[:node].unlink
              end
            end
          rescue ThreadError
          end
        end
      end
      boss.join
      workers.map(&:join)
    end
    
    ##
    # to_xml outputs the current OPML XML structure as a String containing all the XML markup
    def to_xml
      @opml.to_xml
    end

    private

    ##
    # filter! recurses down the OPML body, looking for outline tags, and pushes each
    # leaf node onto a work queue
    def filter!(data)
      data.each do |node|
        if node.name == 'outline'
          outline = Outline.new(node).to_hash
          if node.children.length > 0
            title = outline[:title] || outline[:text]
            filter!(node.children)
          else
            @work_queue.push({ :outline => outline, :node => node})
          end
        end
      end      
    end
    
    ##
    # validate_callback tries to download a feed and verify that it has been updated
    # since the +since+ time
    def validate_callback(feed, since=nil)
      val = "FAIL"
      begin
        Timeout::timeout(@timeout) {
          open(feed[:xml_url]) do |rss|
            feed = RSS::Parser.parse(rss)
            if feed
              last_updated = Time.at(0)
              feed.items.each do |item|
                #p item.class
                updated = nil
                if item.respond_to?(:updated)
                  updated = item.updated.content
                elsif item.respond_to?(:date)
                  updated = item.date
                end
                next unless updated
                if updated and updated > last_updated
                  last_updated = updated
                end
              end
              if since
                #p last_updated
                if last_updated and last_updated > since
                  val = "PASS"
                else
                  val = "STALE"
                end
              else
                val = "PASS"
              end
            else
              val = "NOFEED"
            end
          end
        }
      rescue EOFError => e
        val = "EOFError"
      rescue OpenURI::HTTPError => e
        val = "HTTPError"
      rescue RSS::Error => e
        val = "RSSError"
      rescue Timeout::Error => e
        val = "Timedout"
      rescue SocketError => e
        val = "SocketError"
      rescue RuntimeError => e
        val = "Redirect Loop"
      rescue Errno::ECONNREFUSED => e
        val = "Connection Refused"
      rescue Exception => e
        val = "Unexpected error: #{e}"
      end
      val      
    end
  end
  
end
