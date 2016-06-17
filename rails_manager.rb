require 'rubygems'
require 'using_yaml'
require 'fileutils'
require 'securerandom'
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
elsif ARGV[0] == 'update'
	# Load the configuration that has been saved
	config = Configuration.new
else
	# Abort as we dont know what mode to run in
	Kernel.abort('First parameter needs to be either "init" or "update"')
end

# Remove the old app root
if File.exists?('app-root')
	FileUtils.rm_rf('app-root')
end

# Execute a git clone statement
system("git clone https://#{config.repository['username']}@github.com/#{config.repository['url']} app-root")

# Update the app-root/config/database.yml file
File.open('app-root/config/database.yml', 'w+') do |file|
	file.write("production:\n")
	file.write("	adapter: postgresql\n")
	file.write("	encoding: unicode\n")
	file.write("	pool: 5\n")
	file.write("	host: #{config.database.address}\n")
	file.write("	username: #{config.database.username}\n")
	file.write("	password: #{config.database.password}\n")
	file.write("	database: #{config.database.name}")
end

# Update the app-root/Gemfile file
File.open('app-root/Gemfile', 'a') do |file|
	file.write("group :production do\n")
	file.write("	gem 'pg'\n")
	file.write("	gem 'passenger'\n")
	file.write("end")
end

# Install the gems from the Gemfile
Dir.chdir('app-root') do
	unless File.exists?('Gemfile.lock')
		system('bundle install')
	end
	system('bundle install --deployment')

	# Precompile assets
	system('RAILS_ENV=production bundle exec rake assets:precompile')
end

# Set the rails secret key
ENV['secret_key_base'] = SecureRandom.hex(64)

