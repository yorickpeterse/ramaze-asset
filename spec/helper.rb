if ENV.key?('COVERAGE') and ENV['COVERAGE'] === 'true'
  require File.expand_path('../../lib/ramaze/asset/spec/simplecov', __FILE__)
end

require File.expand_path('../../lib/ramaze/asset', __FILE__)
require __DIR__('../lib/ramaze/asset/spec/helper')
