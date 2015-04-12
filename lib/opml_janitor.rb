require "opml_janitor/version"
require "opml_janitor/outline"
require 'nokogiri'
require 'open-uri'
require 'rss'
require 'timeout'
require 'thread'
require 'pp'

module OpmlJanitor
  class Parser
    def initialize(contents, debug = false)
      @xml = contents
      @opml = Nokogiri::XML.parse(@xml)
      @debug = debug
      @timeout = 20
    end
    
    def debug=(debug)
      @debug = debug
    end
    
    def timeout=(timeout)
      @timeout = timeout
    end
    
    def self.from_filehandle(filehandle)
      contents = filehandle.read
      Parser.new(contents)
    end
    
    def self.from_file(filename)
      from_filehandle(File.open(filename, 'r'))
    end
    
    def self.from_url(url)
      from_filehandle(open(url).read)
    end
    
    def filter_dom!(data, &block)
      data.each do |node|
        if node.name == 'outline'
          outline = Outline.new(node).to_hash
          if node.children.length > 0
            title = outline[:title] || outline[:text]
            filter_dom!(node.children)
          else
            print "Testing #{outline[:xml_url]}" if @debug
            spaces = 80 - outline[:xml_url].length
            spaces = 1 if spaces < 1
            print " " * spaces if @debug
            if block.call(outline)
              puts "[PASS]" if @debug
            else
              puts "[FAIL]" if @debug
              node.unlink
            end
          end
        end
      end
    end
    
    def filter_threaded!(data)
      data.each do |node|
        if node.name == 'outline'
          outline = Outline.new(node).to_hash
          if node.children.length > 0
            title = outline[:title] || outline[:text]
            filter_threaded!(node.children)
          else
            @work_queue.push({ :outline => outline, :node => node})
          end
        end
      end      
    end
    
    def validate_callback(feed, since=nil)
      val = false
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
                  val = true
                end
              else
                val = true
              end
            end
          end
        }
      rescue EOFError => e
        #puts e.backtrace if @debug
      rescue OpenURI::HTTPError => e
        #puts e.backtrace if @debug
      rescue RSS::Error => e
        #puts e.backtrace if @debug
      rescue Timeout::Error => e
        #puts e.backtrace if @debug
      rescue SocketError => e
      rescue RuntimeError => e
      rescue Errno::ECONNREFUSED => e
      rescue Exception => e
        puts e
      end
      val      
    end
    
    def validate_threaded!(since = nil)
      # this threading methodology is highly expensive for simple blocks, but a life-saver for IO-bound blocks
      @work_queue = Queue.new
      data = @opml.css("body").children
      filter_threaded!(data)
      
      workers = (0...100).map do
        Thread.new do
          begin
            while work = @work_queue.pop(true)
              val = validate_callback(work[:outline], since)
              spaces = 80 - work[:outline][:xml_url].length
              spaces = 1 if spaces < 1
              puts "#{work[:outline][:xml_url]}#{' ' * spaces}#{(val) ? '[PASS]' : '[FAIL]'}" if @debug
              unless val
                work[:node].unlink
              end
            end
          rescue ThreadError
          end
        end
      end
      workers.map(&:join)
    end
    
    def validate!(since = nil)
      data = @opml.css("body").children
      filter_dom!(data) do |feed|
        validate_callback(feed, since)
      end
    end
    
    def to_xml
      @opml.to_xml
    end
  end
  
end
