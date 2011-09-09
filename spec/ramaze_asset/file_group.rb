require File.expand_path('../../helper', __FILE__)

class SpecFileGroup < Ramaze::Asset::FileGroup
  extension '.js'

  def minify(input)
    return input
  end

  def html_tag(gestalt, path)
    gestalt.p(path)
  end
end

class SpecFileGroup2 < Ramaze::Asset::FileGroup
  extension '.js'
end

describe('Ramaze::Asset::FileGroup') do
  behaves_like :asset_manager

  before do
    @file   = '/js/mootools_core'
    @file_1 = '/js/mootools_more'
    @cache  = __DIR__('../fixtures/public/minified')
    @public = __DIR__('../fixtures/public')
  end

  it('Initialize with invalid data') do
    should.raise?(Ramaze::Asset::AssetError) do
      Ramaze::Asset::FileGroup.new([])
    end

    should.raise?(Ramaze::Asset::AssetError) do
      Ramaze::Asset::FileGroup.new([@file], :cache_path => __DIR__('foobar'))
    end

    # No extension specified
    should.raise?(Ramaze::Asset::AssetError) do
      Ramaze::Asset::FileGroup.new([@file], :cache_path => @public)
    end
  end

  it('Generate a name for the minified file') do
    name  = Digest::SHA1.new.hexdigest(@file + '.js') + '.min.js'
    group = SpecFileGroup.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public],
      :minify     => true
    )

    group.options[:name].should === name
    group.extension.should      === '.js'
  end

  it('Build a single file') do
    group = SpecFileGroup.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public]
    )

    group.build_html.should =~ /<p>#{@file}\.js<\/p>/

    # Minify it this time.
    group = SpecFileGroup.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public],
      :name       => 'spec',
      :minify     => true
    )

    group.build

    content  = File.read(File.join(@public, @file + '.js'))
    minified = File.read(File.join(@cache, 'spec.min.js'))

    File.size?(File.join(@cache, 'spec.min.js')).should != false
    minified.include?(content).should                   === true

    group.build_html.should =~ /<p>\/spec\.min\.js<\/p>/
  end

  it('Build multiple files') do
    group  = SpecFileGroup.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public]
    )

    html = group.build_html

    html.should =~ /<p>#{@file}\.js<\/p>/
    html.should =~ /<p>#{@file_1}\.js<\/p>/

    # Minify it this time.
    group = SpecFileGroup.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public],
      :name       => 'spec',
      :minify     => true
    )

    group.build

    content   = File.read(File.join(@public, @file   + '.js'))
    content_1 = File.read(File.join(@public, @file_1 + '.js'))
    minified  = File.read(File.join(@cache, 'spec.min.js'))

    File.size?(File.join(@cache, 'spec.min.js')).should != false

    minified.include?(content).should   === true
    minified.include?(content_1).should === true

    html = group.build_html

    html.should =~ /<p>\/spec\.min\.js<\/p>/
  end
end
