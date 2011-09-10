desc 'Removes all minified files'
task :clean do
  Dir.glob(__DIR__('../spec/fixtures/public/minified/*')).each do |file|
    File.unlink(file)
  end
end
