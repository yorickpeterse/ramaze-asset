require File.expand_path('../helper', __FILE__)

describe('Ramaze::Asset::Environment') do
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
        :cache_path => __DIR__('fixtures/public')
      )
    end

    Ramaze.options.publics = old_publics
  end
end
