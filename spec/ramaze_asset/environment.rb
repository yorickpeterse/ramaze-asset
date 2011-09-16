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

      env.serve(:javascript, ['js/mootools_core'])
    end

    Ramaze.options.publics = old_publics
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

  it('Add an asset group and load it') do
    SpecEnv.register_asset_group(:spec) do |env, number|
      env.serve(:css, ['css/github', 'css/reset'])

      number.should === 10
    end

    SpecEnv.files[:css].nil?.should === true

    should.not.raise?(Ramaze::Asset::AssetError) do
      SpecEnv.load_asset_group(:spec, 10)
    end

    files = SpecEnv.files[:css][:global][:__all][0].files

    files.include?('/css/github.css').should === true
    files.include?('/css/reset.css').should  === true
  end

  it('Load multiple files for the same controller') do
    SpecEnv.serve(
      :javascript,
      ['js/mootools_core'],
      :controller => SpecEnvironment
    )

    SpecEnv.serve(
      :javascript,
      ['js/mootools_more'],
      :controller => SpecEnvironment
    )

    SpecEnv.serve(
      :javascript,
      ['js/mootools_core'],
      :controller => SpecEnvironment2
    )

    SpecEnv.files[:javascript].keys.include?(:SpecEnvironment).should  === true
    SpecEnv.files[:javascript].keys.include?(:SpecEnvironment2).should === true

    SpecEnv.files[:javascript][:SpecEnvironment][:__all].length.should  === 2
    SpecEnv.files[:javascript][:SpecEnvironment2][:__all].length.should === 1

    body1 = get('/').body
    body2 = get('/2').body

    body1.should != body2

    body1.include?('js/mootools_core').should === true
    body1.include?('js/mootools_more').should === true
    body2.include?('js/mootools_core').should === true
    body2.include?('js/mootools_more').should === false
  end

  it('Files should only be loaded once for the same controller') do
    3.times do
      SpecEnv.serve(
        :javascript,
        ['js/mootools_core'],
        :controller => SpecEnvironment
      )
    end

    SpecEnv.files[:javascript][:SpecEnvironment][:__all].length.should === 1
  end
end
