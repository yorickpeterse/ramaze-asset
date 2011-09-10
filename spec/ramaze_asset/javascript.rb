require File.expand_path('../../helper', __FILE__)

describe('Ramaze::Asset::Javascript') do
  behaves_like :asset_manager

  before do
    @file   = '/js/mootools_core'
    @file_1 = '/js/mootools_more'
    @cache  = __DIR__('../fixtures/public/minified')
    @public = __DIR__('../fixtures/public')
  end

  it('Build a single file') do
    group = Ramaze::Asset::Javascript.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public]
    )

    group.build_html.should \
      === %Q{<script src="#{@file}.js" type="text/javascript"></script>}

    # Now minify it
    group = Ramaze::Asset::Javascript.new(
      [@file],
      :cache_path => @cache,
      :paths      => [@public],
      :minify     => true,
      :name       => 'mootools'
    )

    group.build

    File.size?(File.join(@cache, 'mootools.min.js')).should != false

    group.build_html.should \
      === '<script src="/minified/mootools.min.js" ' \
        'type="text/javascript"></script>'
  end

  it('Build multiple files') do
    group = Ramaze::Asset::Javascript.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public]
    )

    group.build_html.should \
      === %Q{<script src="#{@file}.js" type="text/javascript"></script>} +
        %Q{<script src="#{@file_1}.js" type="text/javascript"></script>}

    # Now minify it
    group = Ramaze::Asset::Javascript.new(
      [@file, @file_1],
      :cache_path => @cache,
      :paths      => [@public],
      :minify     => true,
      :name       => 'mootools'
    )

    group.build

    File.size?(File.join(@cache, 'mootools.min.js')).should != false

    group.build_html.should \
      === '<script src="/minified/mootools.min.js" ' \
        'type="text/javascript"></script>'
  end
end
