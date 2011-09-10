require File.expand_path('../../helper', __FILE__)

describe('Ramaze::Asset::CSS') do
  behaves_like :asset_manager

  before do
    @file   = '/css/github'
    @file_1 = '/css/reset'
    @cache  = __DIR__('../fixtures/public/minified')
    @public = __DIR__('../fixtures/public')
  end

  it('Build a single file') do
    group = Ramaze::Asset::CSS.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public]
    )

    group.build_html.should \
      === %Q{<link rel="stylesheet" href="#{@file}.css" type="text/css" />}

    # Now minify it
    group = Ramaze::Asset::CSS.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public],
      :minify     => true,
      :name       => 'github'
    )

    group.build

    File.size?(File.join(@cache, 'github.min.css')).should != false

    group.build_html.should \
      === '<link rel="stylesheet" href="/minified/github.min.css" ' \
        'type="text/css" />'
  end

  it('Build multiple files') do
    group = Ramaze::Asset::CSS.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public]
    )

    group.build_html.should \
      === %Q{<link rel="stylesheet" href="#{@file}.css" type="text/css" />} +
        %Q{<link rel="stylesheet" href="#{@file_1}.css" type="text/css" />}

    # Now minify it
    group = Ramaze::Asset::CSS.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public],
      :minify     => true,
      :name       => 'github'
    )

    group.build

    File.size?(File.join(@cache, 'github.min.css')).should != false

    group.build_html.should \
      === '<link rel="stylesheet" href="/minified/github.min.css" ' \
        'type="text/css" />'
  end
end
