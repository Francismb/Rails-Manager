require 'rubygems'
require 'using_yaml'
require 'fileutils'
require_relative 'configuration'

# The mode(init or update) to run the script in
@mode = ARGV[0]

# The configuration object
config = nil

# Create a new configuration with the supplied parameters
if ARGV[0] == 'init'
	config = Configuration.new

	config.database['address'] = ARGV[1]
	config.database['username'] = ARGV[2]
	config.database['password'] = ARGV[3]
	config.database['name'] = ARGV[4]
	config.database.save

	config.repository['username'] = ARGV[5]
	config.repository['url'] = ARGV[6]
	config.repository.save
end

# Load the configuration if it hasnt been loaded yet
if config == nil
	config = Configuration.new
end

# Remove the old app root
if File.exists?('app-root')
	FileUtils.rm_rf('app-root')
end

# Execute a git clone statement
exec("git clone https://#{config.repository['username']}@github.com/#{config.repository['url']} app-root")