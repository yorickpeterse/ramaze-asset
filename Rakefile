require File.expand_path('../lib/ramaze_asset', __FILE__)

module RamazeAsset
  Gemspec = Gem::Specification::load(File.expand_path('../ramaze_asset.gemspec', __FILE__))
end

task_dir = File.expand_path('../lib/ramaze_asset/task', __FILE__)

Dir.glob("#{task_dir}/*.rake").each do |f|
  import(f)
end
