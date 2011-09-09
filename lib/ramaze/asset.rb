require 'rubygems'
require 'ramaze'

require __DIR__('../vendor/jsmin')
require __DIR__('../vendor/cssmin')

require __DIR__('asset/version')
require __DIR__('asset/error')
require __DIR__('asset/environment')

require __DIR__('asset/css')
require __DIR__('asset/javascript')

Ramaze::Asset::Environment.register_type(:css, Ramaze::Asset::CSS)
Ramaze::Asset::Environment.register_type(:javascript, Ramaze::Asset::Javascript)
