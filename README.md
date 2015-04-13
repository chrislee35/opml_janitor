# OpmlJanitor

Tool to clean up broken and stale RSS feeds from an OPML file.
It parses the XML, and for each feed, it downloads the RSS/Atom/etc., validates that the feed has been active within the given time frame, and writes the result to a new OPML XML document containing only the good feeds.

## Installation

Add this line to your application's Gemfile:

    gem 'opml_janitor'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install opml_janitor

## Usage

	require 'opml_janitor'
	
	opml_janitor = OpmlJanitor::Parser.from_filehandle("example.opml")
	opml_janitor.debug = true
	opml_janitor.threads = 20
	opml_janitor.validate!(Time.now - (30*24*60*60))
	result = opml_janitor.to_xml
	

Or you could use the bundled tool

	$ opml_janitor -h
	Usage: opml_janitor [-hv] [-t <# threads>] [-s <date>] [-i <input file>] [-o <output file>]
	  -h    displays this help text
	  -v    turns on debugging messages (encouraged)
	  -t #  set the number of threads (default 1) (highly encouraged)
	  -i    specify a file for input (default is standard input)
	  -o    specify a file for output (default is standard output)
	  

Example: 

	$ opml_janitor -i subscriptions.xml -o sub.xml -s "2015-01-01" -v -t 20

* Reads subscriptions from subscriptions.xml
* Writes results to sub.xml
* Must have posts newer than 2015-01-01 00:00:00 (local time zone)
* Verbose messages
* 20 threads

## Related

Related work: <a href='https://github.com/feedbin/opml_saw'>opml_saw</a>

## Contributing

1. Fork it ( https://github.com/chrislee35/opml_janitor/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
