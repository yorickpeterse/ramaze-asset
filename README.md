# Ramaze::Asset

Ramaze::Asset is an asset manager that can be used with [Ramaze][ramaze]. Out of
the box it's capable of serving Javascript and CSS files but you can very easily
add your own types.

## Requirements

All you need is Ramaze. It doesn't really matter what version you're using but
2011.07.25 or newer is recommended.

## Installation

Install the Gem:

    $ gem install ramaze-asset

Then require it somewhere in app.rb or wherever you like:

    require 'ramaze/asset'

## Usage

Ramaze::Asset uses so called "environments" to manage assets. Each environment
has it's own set of assets. In order to create such an environment you'll need
to initialize Ramaze::Asset::Environment and supply it with a directory to store
your minified files in:

    require 'ramaze/asset'

    env = Ramaze::Asset::Environment.new(:cache_path => __DIR__('public/minified'))

Once an environment has been created you can add files by calling the instance
method ``serve()``:

    env.serve(:javascript, ['js/foobar'], :minify => true, :name => 'foobar')

Building the minified files and generating the HTML can be done as following:

    env.build(:javascript)

    tags = env.build_html(:javascript)

    p tags # => "<script src="minified/foobar.min.js" type="text/javascript">"

When loading files it's important to remember that these files should be
specified relative to one of your public directories. Ramaze::Asset does not
move them into a public directory itself nor does it add any routes. It's your
job to make sure that the assets are located in one of your root directories'
public directories. If ``Ramaze.options.roots`` contains a root directory called
"A" then the assets should be located in ``A/public``. You can customize this by
adding/removing paths to ``Ramaze.options.roots`` and
``Ramaze.options.publics``.

More information can be found in the source of each file, don't worry, they're
documented well enough for most people to be able to understand how to use
Ramaze::Asset.

## License

Ramaze::Asset is licensed under the MIT license. A copy of this license can be
found in the file "LICENSE".

[ramaze]: http://ramaze.net/
