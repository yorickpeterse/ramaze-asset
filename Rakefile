module Ramaze
  module Asset
    Gemspec = Gem::Specification::load(
      File.expand_path('../ramaze-asset.gemspec', __FILE__)
    )
  end
end

task_dir = File.expand_path('../task', __FILE__)

Dir.glob("#{task_dir}/*.rake").each do |f|
  import(f)
end
