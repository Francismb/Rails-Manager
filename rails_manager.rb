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

	config.environment['variables'] = ARGV[7]
	config.environment['secret_key_base'] = SecureRandom.hex(64)
	config.environment.save
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
	file.write("    adapter: postgresql\n")
	file.write("    encoding: unicode\n")
	file.write("    pool: 5\n")
	file.write("    host: #{config.database.address}\n")
	file.write("    username: #{config.database.username}\n")
	file.write("    password: #{config.database.password}\n")
	file.write("    database: #{config.database.name}")
end

# Update the app-root/Gemfile file
File.open('app-root/Gemfile', 'a') do |file|
	file.write("\n\ngem 'figaro'\n\n")
	file.write("group :production do\n")
	file.write("	gem 'pg'\n")
	file.write("	gem 'puma'\n")
	file.write("end")
end

# Install the gems from the Gemfile and set environmental variables
Dir.chdir('app-root') do
	# Rails requires a normal bundle install quite often
	system('bundle install --without development test')

	# Install gems in deployment mode
	system('bundle install --deployment')

	# Initialize figaro
	system('bundle exec figaro install')

	# Add environmental variables to figaro
	File.open('config/application.yml', 'a') do |file|
		# Set the secret_key_base
		file.write("SECRET_KEY_BASE: \"#{config.environment['secret_key_base']}\"\n")

		# Iterate and set extra environmental variables
		config.environment['variables'].split(',').each do |variable_declaration|
			variable = variable_declaration.split('=')
			if variable.length == 2
				file.write("#{variable[0]}: \"#{variable[1]}\"\n")
			end
		end
	end
end

# Precompile assets and prepare the database
Dir.chdir('app-root') do
	# Precompile assets
	system('RAILS_ENV=production bundle exec rake assets:precompile')

	# Migrate the database
	system('RAILS_ENV=production bundle exec rake db:migrate')
end