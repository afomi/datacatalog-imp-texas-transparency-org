gem 'datacatalog-importer', '= 0.1.19'
require 'datacatalog-importer'

class Puller

  class Error < RuntimeError; end
  class ValidationError < Error; end
  class ScrapingError < Error; end

  U = DataCatalog::ImporterFramework::Utility
  I = DataCatalog::ImporterFramework
  
  FETCH_DELAY = 0.3
  FORCE_FETCH = true
  
  protected

  # == Detail Page Related ==

  def get_detail_page_contents(data_from_index_page)
    uri = detail_uri_from_index_metadata(data_from_index_page)
    cached_page = read_cached_detail_page(uri)
    fetched_page = U.fetch(uri)
    if fetched_page != cached_page
      write_cached_page(uri, fetched_page) 
    end
    log(uri, cached_page, fetched_page)
    fetched_page
  end

  def read_cached_detail_page(uri)
    filename = cached_detail_page_filename(uri)
    return nil unless File.exist?(filename)
    IO.read(filename)
  end

  def log(uri, cached, latest)
    uid = uid_from_uri(uri)
    payload = {}
    payload['url']          = uri
    payload['filename']     = cached_detail_page_filename(uri)
    payload['last_updated'] = Time.now if latest != cached
    @logger.update(uid, payload)
    @logger.write
  end

  def write_cached_page(uri, contents)
    filename = cached_detail_page_filename(uri)
    File.open(filename, "w") do |f|
      f.write(contents)
    end
  end

  def cached_detail_page_filename(uri)
    base = "%s.html" % uid_from_uri(uri)
    File.join(@details_folder, base)
  end

  def clean_content(node)
    string = ""
    node.children.select do |n|
      if n.text?
        string << U.single_line_clean(n.content)
      elsif n.name == "br"
        string << "\n"
      end
    end
    U.plain_string(string.gsub(/\n{2,}/, "\n\n").strip)
  end

  def full_uri(path)
    raise "@base_uri blank" if @base_uri.blank?
    U.absolute_url(@base_uri, path)
  end

  # Converts a URI into a Unique ID
  #
  # Must be implemented in a subclass.
  #
  #   For example:
  #   uid_from_uri("http://data.octo.dc.gov/Metadata.aspx?id=137")
  #   => 137
  def uid_from_uri(uri)
    raise NotImplementedError
  end

end
