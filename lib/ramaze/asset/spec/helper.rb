require 'bacon'
require File.expand_path('../bacon/color_output', __FILE__)
require 'ramaze/spec/bacon'

Bacon.extend(Bacon::ColorOutput)
Bacon.summary_on_exit

shared(:asset_manager) do
  behaves_like :rack_test

  after do
    path = __DIR__('../../../../spec/fixtures/public/minified/*')

    Dir.glob(path).each do |file|
      File.unlink(file)
    end
  end
end
