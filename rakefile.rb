gem 'datacatalog-importer', '>= 0.2.0'

require 'rubygems'
require 'yaml'
require 'datacatalog-importer'

require File.dirname(__FILE__) + '/lib/puller'

def setup
  config_file = File.dirname(__FILE__) + '/config.yml'
  config = YAML.load_file(config_file)
  env = ENV['IMPORTER_ENV']
  raise "IMPORTER_ENV undefined" unless env
  raise "IMPORTER_ENV invalid" unless config[env]
  DataCatalog::ImporterFramework::Tasks.new({
    :api_key => config[env]['api_key'],
    :base_uri => config[env]['base_uri'],
    :cache_folder => File.dirname(__FILE__) + '/cache/parsed',
    :name         => "TexasTransparency Data Catalog",
    :uri          => "http://texastransparency.org",
    :puller => Puller,
  })
end

setup