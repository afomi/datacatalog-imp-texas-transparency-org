require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'
require File.dirname(__FILE__) + '/logger'

class OrganizationPuller < Puller
  
  def initialize
    
    @base_uri          = 'https://ourcpa.cpa.state.tx.us/datadepot/openData.do'
    @index_data        = Output.file '/../cache/raw/organization/index.yml'
    @index_html        = Output.file '/../cache/raw/organization/index.html'
    @details_folder    = Output.dir  '/../cache/raw/organization/detail'
    @pull_log          = Output.file '/../cache/raw/organization/pull_log.yml'
    # ---
    @logger = Logger.new(@pull_log)
      
    puts "Pulling Organizations (Source) Index from " + @base_uri
    org_page        = get_index_page(@base_uri)
    rows            = get_org_rows(org_page)
    puts "Orgs found : #{rows.length}"
    
    shaped_rows     = get_row_metadata(rows)
    U.write_yaml(@index_data, shaped_rows) # writes to /organization/index.yml for easy viewing later
    @index_metadata = shaped_rows.each
    
    puts "Pull Organizations Complete"
  end
  
  def fetch
    sleep(FETCH_DELAY)
    data = @index_metadata.next
  rescue StopIteration
    nil
  end
  
  protected
  
  def get_index_page(uri)
    uri = full_uri(uri)
    U.parse_html_from_file_or_uri(uri, @index_html, :force_fetch => FORCE_FETCH)
  end
  
  def get_org_rows(page)
    rows = page.css("table tbody tr")
    puts "Source Rows Found : #{rows.length}"
    return rows # => array of <tr>'s
  end
  
  # fetch individual fields from each record
  def get_row_metadata(rows)
    shaped_rows = []
    
    rows.each do |row|
      url          = "https://ourcpa.cpa.state.tx.us" + U.single_line_clean(row.css(".dataCellName a")[0]['href'])
      
      # grab the detail page
      detail_page  = get_detail_page(url)
      
      # remove the right column because it has <p>'s
      detail_page.css("#rightCol").remove
      
      # assumes a 1:1 ratio <h3><p> pattern
      # grab to a structured hash
      hash = {}
      h3 = detail_page.css("h3")
      p  = detail_page.css("p")      
      h3.each_with_index {|k,i| hash[U.single_line_clean(k.content.to_s.gsub(":","").downcase)] = U.single_line_clean(p[i].content)}
       
      shaped_rows << {
        :name         => U.single_line_clean(hash["submitting agency"]),   
        # :names        => "",
        :acronym      => "",
        :org_type     => "governmental",
        :description  => "",
        # :parent_id    => "",
        # :slug         => "",
        :url          => U.single_line_clean(hash["submitting agency url"]),
        # :home_url     => "http://www.texastransparency.org",
        :catalog_name => "Texas Transparency",
        :catalog_url  => "http://texastransparency.org/opendata",
        :organization => {:name => "Texas"}
        # :interest     => "",
        # :top_level    => "",
        # :custom       => "",
        # :raw          => "",
        # :user_id      => "",
        }
    end
    
     # unique, because the organizations are all Texas
    shaped_rows.uniq
  end
  
  def get_detail_page(uri)
    filename = @details_folder + "/" +  uri[/key=.*/] + ".html"
    U.parse_html_from_file_or_uri(uri, filename, :force_fetch => FORCE_FETCH) # remove FORCE_FETCH after the data is in the cache
  end
  
end
