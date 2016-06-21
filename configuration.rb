class Configuration
	include UsingYAML

	using_yaml :database, :repository, :environment, :path => Dir.pwd

end