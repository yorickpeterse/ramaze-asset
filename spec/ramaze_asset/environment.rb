require File.expand_path('../../helper', __FILE__)

SpecEnv = Ramaze::Asset::Environment.new(
  :cache_path => __DIR__('../fixtures/public/minified')
)

class SpecEnvironment < Ramaze::Controller
  map '/'

  def index
    SpecEnv.build_html(:javascript)
  end

  def specific_method
    SpecEnv.build_html(:javascript)
  end
end

class SpecEnvironment2 < Ramaze::Controller
  map '/2'

  def index
    SpecEnv.build_html(:javascript)
  end
end

describe('Ramaze::Asset::Environment') do
  behaves_like :asset_manager

  after do
    SpecEnv.reset!
  end

  it('Raise for an invalid cache path') do
    should.raise?(Ramaze::Asset::AssetError) do
      env = Ramaze::Asset::Environment.new(:cache_path => 'foobar')
    end
  end

  it('Raise when no public directories are set') do
    old_publics            = Ramaze.options.publics.dup
    Ramaze.options.publics = []

    should.raise?(Ramaze::Asset::AssetError) do
      env = Ramaze::Asset::Environment.new(
        :cache_path => __DIR__('../fixtures/public')
      )
    end

    Ramaze.options.publics = old_publics
  end

  it('Generate the possible paths') do
    path = __DIR__('../fixtures/public')
    env  = Ramaze::Asset::Environment.new(:cache_path => path)

    env.instance_variable_get(:@file_group_options)[:paths].include?(path) \
      .should === true
  end

  it('Register a new type') do
    Ramaze::Asset::Environment.register_type(:struct, Struct)

    Ramaze::Asset::Environment::Types.key?(:struct).should === true
    Ramaze::Asset::Environment::Types[:struct].should      == Struct

    should.raise?(Ramaze::Asset::AssetError) do
      Ramaze::Asset::Environment.register_type(:struct, Struct)
    end

    Ramaze::Asset::Environment::Types.delete(:struct)
  end

  it('Globally disable minifying of files') do
    env = Ramaze::Asset::Environment.new(
      :cache_path => __DIR__('../fixtures/public/minified'),
      :minify     => false
    )

    env.serve(:javascript, ['js/mootools_core'], :minify => true)
    env.serve(:css, ['css/github'])

    env.files[:javascript][:global][:__all][0].options[:minify].should === false
    env.files[:css][:global][:__all][0].options[:minify].should        === false
  end

  it('Serve a file globally') do
    SpecEnv.serve(:javascript, ['js/mootools_core'], :controller => :global)

    body1 = get('/').body
    body2 = get('/2').body

    body1.empty?.should === false
    body1.should        === body2

    body1.include?('js/mootools_core.js').should === true
  end

  it('Serve a file for a specific controller') do
    SpecEnv.serve(
      :javascript,
      ['/js/mootools_core'],
      :controller => SpecEnvironment
    )

    body1 = get('/').body
    body2 = get('/2').body

    body1.should != body2

    body1.include?('js/mootools_core.js').should === true
    body2.include?('js/mootools_core.js').should === false
  end

  it('Serve a file for a specific method') do
    SpecEnv.serve(
      :javascript,
      ['/js/mootools_core'],
      :controller => SpecEnvironment,
      :methods    => [:specific_method]
    )

    body1 = get('/').body
    body2 = get('/specific_method').body

    body1.should != body2

    body1.include?('/js/mootools_core.js').should === false
    body2.include?('/js/mootools_core.js').should === true
  end
end
