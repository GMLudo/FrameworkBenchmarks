# frozen_string_literal: true
require 'bundler'
require 'time'

MAX_PK = 10_000
QUERIES_MIN = 1
QUERIES_MAX = 500
SEQUEL_NO_ASSOCIATIONS = true

SERVER_STRING =
  if defined?(PhusionPassenger)
    [
      PhusionPassenger::SharedConstants::SERVER_TOKEN_NAME,
      PhusionPassenger::VERSION_STRING
    ].join('/').freeze
  elsif defined?(Puma)
    Puma::Const::PUMA_SERVER_STRING
  elsif defined?(Unicorn)
    Unicorn::HttpParser::DEFAULTS['SERVER_SOFTWARE']
  end

Bundler.require(:default) # Load core modules

def connect(dbtype)
  Bundler.require(dbtype) # Load database-specific modules

  adapters = {
    :mysql=>{ :jruby=>'jdbc:mysql', :mri=>'mysql2' },
    :postgresql=>{ :jruby=>'jdbc:postgresql', :mri=>'postgres' }
  }

  opts = {}

  # Determine threading/thread pool size and timeout
  if defined?(JRUBY_VERSION)
    opts[:max_connections] = Integer(ENV.fetch('MAX_CONCURRENCY'))
    opts[:pool_timeout] = 10
  elsif defined?(Puma)
    opts[:max_connections] = Puma.cli_config.options.fetch(:max_threads)
    opts[:pool_timeout] = 10
  else
    Sequel.single_threaded = true
  end

  Sequel.connect \
    '%{adapter}://%{host}/%{database}?user=%{user}&password=%{password}' % {
      :adapter=>adapters.fetch(dbtype).fetch(defined?(JRUBY_VERSION) ? :jruby : :mri),
      :host=>ENV.fetch('DBHOST', '127.0.0.1'),
      :database=>'hello_world',
      :user=>'benchmarkdbuser',
      :password=>'benchmarkdbpass'
    }, opts
end

DB = connect(ENV.fetch('DBTYPE').to_sym).tap do |db|
  db.extension(:freeze_datasets)
  db.optimize_model_load if db.respond_to?(:optimize_model_load)
  db.freeze
end

# Define ORM models
class World < Sequel::Model(:World)
  def_column_alias(:randomnumber, :randomNumber) if DB.database_type == :mysql
end

class Fortune < Sequel::Model(:Fortune)
  # Allow setting id to zero (0) per benchmark requirements
  unrestrict_primary_key
end

Sequel::Model.freeze
