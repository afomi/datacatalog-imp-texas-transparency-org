class Puller

  U = DataCatalog::ImporterFramework::Utility
  I = DataCatalog::ImporterFramework
  
  FETCH_DELAY = 0.3
  FORCE_FETCH = true
  
  def initialize(handler)
    @handler = handler
    
    # SPECIFY WHERE SOURCE AND ORGS ARE FOUND
    @source_index_uri            = 'https://ourcpa.cpa.state.tx.us/datadepot/openData.do'
    @source_index_filename       = File.basename(@source_index_uri)
    
    # unnecessary for this importer
    # @org_index_uri               = 'http://example.com'
    # @org_index_filename          = File.basename(@org_index_uri)
    
    # SETUP CACHE DIRECTORIES
    @cache_folder                = File.dirname(__FILE__) + "/../cache/"
    
    @cache_source_raw_index      = @cache_folder + "raw/source/"
    @cache_source_raw_details    = @cache_folder + "raw/source/details/"
    @cache_source_index_data     = @cache_folder + "raw/source/index.yml"
      
    @cache_org_index             = @cache_folder + "raw/org/index/"
    @cache_org_details           = @cache_folder + "raw/org/details/"
    
    # ENSURE THE CACHE DIRECTORIES EXIST
    FileUtils.mkdir_p @cache_folder
    FileUtils.mkdir_p @cache_source_raw_index
    FileUtils.mkdir_p @cache_source_raw_details
    FileUtils.mkdir_p @cache_org_index
    FileUtils.mkdir_p @cache_org_details
  end
  
  def run
     @common = {
      :catalog_name => "texastransparency.org",
      :catalog_url  => "http://texastransparency.org",
    }
    
    process_data
  end
  
  # -- Methods specific to this importer --
  
  def process_data
    source_index_page = get_source_index_page(@source_index_uri)
    rows = get_source_rows(source_index_page)
    
    # grabs org @ source data from detail pages
    shaped_rows = get_data(rows)
    puts "Pull Sources Complete"
    
    # processes org & source data into .yml's for rake push & pull
    loop_sources(shaped_rows)
    loop_orgs(shaped_rows)
  end
  
  def get_source_index_page(uri)
    puts "Pulling Source Index from " + uri
    U.parse_html_from_file_or_uri(uri, @cache_source_raw_index + "index.html", :force_fetch => FORCE_FETCH)
  end

  # There is a collection of tr's in the index document's table that contains metadata
  # about each data source. This method parses the document and returns an array
  # of the rows we are interested in.
  def get_source_rows(page)
    rows = page.css("table tbody tr")
    puts "Source Rows Found : #{rows.length}"
    return rows # => array of <tr>'s
  end

  # Parse each row found in the index file
  def get_data(rows)
    all_data = []
    
    rows.each do |row|
      url = "https://ourcpa.cpa.state.tx.us" + U.single_line_clean(row.css(".dataCellName a")[0]['href'])
      
      # grab the detail page for more information on the source & orgs
      # because there is no page dedicated to org data
      detail_page  = get_detail_page(url)

      # remove the right column
      # because it has <p>'s
      detail_page.css("#rightCol").remove
      
      # grab page data to a structured hash
      # assumes a 1:1 ratio <h3><p> pattern
      hash = {}
      h3 = detail_page.css("h3")
      p  = detail_page.css("p")      
      h3.each_with_index {|k,i| hash[U.single_line_clean(k.content.to_s.gsub(":","").downcase)] = U.single_line_clean(p[i].content)}
      
      # Grab data from the page
      scraped_data = {
        :title             => U.single_line_clean(row.css(".dataCellName")[0].content),
        :documentation_url => "https://ourcpa.cpa.state.tx.us" + row.css(".dataCellDataLayout a")[0]['href'],
        :url               => url,
        :name              => hash['submitting agency'],
        :description       => U.multi_line_clean(row.css('.dataCellMetaData span')[0].content)
      }
      
      hash.merge!(scraped_data)
      hash.merge!(@common)
      
      all_data << hash
    end

    all_data
  end
  
  def get_detail_page(uri)
    filename =  @cache_source_raw_details +  uri[/key=.*/] + ".html"
    U.parse_html_from_file_or_uri(uri, filename, :force_fetch => FORCE_FETCH)
  end
  
  
  protected
  
  def loop_sources(data)

    data.each do |row|
      @source_metadata = {
        :title             => row[:title],
        :description       => row[:description],
        :source_type       => "dataset",
        :documentation_url => row[:documentation_url],
        :url               => row[:url],
        :released          => row[:original_release_date],
        :organization      => {
          :name => row[:name],
          },
        :frequency         => row['update frequency'].downcase,
        :downloads         => [
          {
            :url    => row[:url],
            :format => row['file type'],
            :size   => row['file size'],
          }
        ],
        :custom            => {},
        :license           => "public domain",
        :license_url       => "",
        #:period_end        => "",
        #:period_start      => "",
        :raw               => {}
      }
    
      @source_metadata.merge!(@common)
      @handler.source(@source_metadata)
    end

  end
  
  def loop_orgs(data)
    shaped_rows = []
    
    data.each do |row|
      hash = {
            :name         => row[:name],
            :acronym      => "",
            :org_type     => "governmental",
            :description  => "",
            :url          => row['submitting agency url'],
            :organization => {:name => "Texas"},
            # :names        => "",
            # :custom       => "",
            # :raw          => "",
      }
      hash.merge!(@common)
      
      shaped_rows << hash
    end
    
    # process uniques (all organizations are Texas)
    shaped_rows.uniq.each do |org|
      @handler.organization(org)
    end
  end
end
