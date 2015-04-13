unless Kernel.respond_to?(:require_relative)
	module Kernel
		def require_relative(path)
			require File.join(File.dirname(caller[0]), path.to_str)
		end
	end
end

require_relative 'helper'
require 'pp'

class TestOPMLJanitor < Minitest::Test
  def test_opml_parse
    #opmljanitor = OpmlJanitor::Parser.from_file("test/test.opml")
  end
  
  def test_opml_validation
    #opmljanitor = OpmlJanitor::Parser.from_file("test/test2.opml")
    #pp opmljanitor.validate
  end
  
  def test_opml_validation_with_time
    opmljanitor = OpmlJanitor::Parser.from_file("test/test2.opml")
    opmljanitor.validate!(Time.now - (265*24*60*60))
    xml = opmljanitor.to_xml
  end
end