require File.expand_path('../../helper', __FILE__)

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
end
