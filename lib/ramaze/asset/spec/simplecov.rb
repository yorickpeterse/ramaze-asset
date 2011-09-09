require 'simplecov'

SimpleCov.configure do
  root         File.expand_path('../../../../../', __FILE__)
  command_name 'bacon'
  project_name 'Ramaze::Asset'

  # Don't actually test the coverage of the tests themselves
  add_filter 'spec'
  add_filter 'vendor'
end

SimpleCov.start
