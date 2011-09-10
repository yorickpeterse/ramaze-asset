desc 'Runs all the tests'
task :test => :clean do
  files = Dir.glob(File.expand_path('../../spec/ramaze_asset/*.rb', __FILE__))

  files.each do |file|
    require(file)
  end
end
