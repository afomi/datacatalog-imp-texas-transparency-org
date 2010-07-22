require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'
require File.dirname(__FILE__) + '/logger'

gem 'kronos', '>= 0.1.6'
require 'kronos'

gem 'unindentable', '>= 0.0.3'
require 'unindentable'

class SourcePuller < Puller
  include Unindentable

  # -- Common Importer Methods --

  def initialize
    @base_uri       = 'https://ourcpa.cpa.state.tx.us/datadepot/openData.do'    
    @index_data     = Output.file '/../cache/raw/source/index.yml'
    @index_folder   = Output.dir  '/../cache/raw/source/index'
    @index_html     = Output.file '/../cache/raw/source/index.html'
    @details_folder = Output.dir  '/../cache/raw/source/detail'
    @pull_log       = Output.file '/../cache/raw/source/pull_log.yml'
    @info_log       = Output.file '/../cache/raw/source/info_log.txt'
    # ---
    @logger         = Logger.new(@pull_log)
    @info           = File.new(@info_log, "w")
    
    puts "Pulling Source Index from " + @base_uri
    source_page     = get_index_page(@base_uri)
    rows            = get_source_rows(source_page)
    shaped_rows     = get_row_metadata(rows)
    
    U.write_yaml(@index_data, shaped_rows) # writes to /sources/index.yml for easy viewing later
    @index_metadata = shaped_rows.each
    puts "Pull Sources Complete"
  end
  
  def fetch
    sleep(FETCH_DELAY)
    data = @index_metadata.next
  rescue StopIteration
    return nil
  end
  
  # -- Methods specific to this importer --
  
  def get_index_page(uri)
    uri = full_uri(uri)
    U.parse_html_from_file_or_uri(uri, @index_html, :force_fetch => FORCE_FETCH)
  end
  
  # protected

  # There is a collection of tr's in the index document's table that contains metadata
  # about each data source. This method parses the document and returns an array
  # of the rows we are interested in.
  def get_source_rows(page)
    rows = page.css("table tbody tr")
    puts "Source Rows Found : #{rows.length}"
    return rows # => array of <tr>'s
  end

  # Parse each row found in the index file
  def get_row_metadata(rows)
    shaped_rows = []
    
    rows.each do |row|
      url          = "https://ourcpa.cpa.state.tx.us" + U.single_line_clean(row.css(".dataCellName a")[0]['href'])
      description  = U.multi_line_clean(row.css(".dataCellMetaData span")[0].content)
      
      # grab the detail page for more information on the source
      # and organization data
      # because there is no page dedicated to org data
      detail_page  = get_detail_page(url)
      
      # remove the right column
      # because it has <p>'s
      detail_page.css("#rightCol").remove
      
      # assumes a 1:1 ratio <h3><p> pattern
      # grab to a structured hash
      hash = {}
      h3 = detail_page.css("h3")
      p  = detail_page.css("p")      
      h3.each_with_index {|k,i| hash[U.single_line_clean(k.content.to_s.gsub(":","").downcase)] = U.single_line_clean(p[i].content)}

      shaped_rows << {
            :title             => U.single_line_clean(row.css(".dataCellName")[0].content),
            :description       => U.multi_line_clean(row.css("td")[0].css("span")[0].content),
            :source_type       => "dataset",
            :documentation_url => "https://ourcpa.cpa.state.tx.us" + row.css(".dataCellDataLayout a")[0]['href'],
            :url               => url,
            :catalog_name      => "TexasTransparency.org",
            :catalog_url       => @base_uri,
            # :released          => hash["original release date"],
            :organization      => hash["submitting agency"],
            :frequency         => hash["update frequency"].downcase,
            :downloads         => [{
              :url    => U.single_line_clean("https://ourcpa.cpa.state.tx.us" + row.css("a")[0]['href']),
              :format => hash["file type"],
              }],
            :custom            => {},
            :license           => "public domain",
            :license_url       => "",
            :organization      => {
              :name              => U.single_line_clean(hash["submitting agency"]),
              },
            #:period_end        => "",
            #:period_start      => "",
            :raw               => {}
          }
    end
    
    shaped_rows
  end
  
  def get_detail_page(uri)
    filename = @details_folder + "/" +  uri[/key=.*/] + ".html"
    U.parse_html_from_file_or_uri(uri, filename, :force_fetch => FORCE_FETCH)
  end

end
