require 'ramaze'
require __DIR__('lib/ramaze/asset')

# Ramaze::Asset needs a root directory that contains a public directory.
Ramaze.options.roots.push(__DIR__('spec/fixtures'))

# Create the environment and tell it to minify files.
AssetEnv = Ramaze::Asset::Environment.new(
  :cache_path => __DIR__('spec/fixtures/public/minified/'),
  :minify     => true
)

class MainController < Ramaze::Controller
  map '/'

  def index
    output = <<-TXT
    #{AssetEnv.build_html(:javascript)}
    #{AssetEnv.build_html(:css)}

    <script type="text/javascript">
    window.addEvent('domready', function()
    {
        alert("Hello Ramaze::Asset");
    });
    </script>
    TXT

    return output
  end
end

AssetEnv.serve(
  :javascript,
  ['js/mootools_core'],
  :controller => MainController
)

AssetEnv.serve(
  :css,
  ['css/reset', 'css/github'],
  :controller => MainController
)

AssetEnv.build(:javascript)
AssetEnv.build(:css)

Ramaze.start(:root => Ramaze.options.roots)
