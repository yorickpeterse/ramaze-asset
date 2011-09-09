require __DIR__('../../vendor/cssmin')

module Ramaze
  module Asset
    ##
    # File group for CSS files, these files are minified using CSSMin.
    #
    # @author Yorick Peterse
    # @since  0.1
    #
    class CSS < Ramaze::Asset::FileGroup
      extension '.css'

      ##
      # Minifies the output and returns the result as a string.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [String] input The input to minify.
      # @return [String]
      #
      def minify(input)
        return CSSMin.minify(input)
      end

      ##
      # Builds a single <link> tag.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Ramaze::Gestalt] gestalt An instance of Ramaze::Gestalt used to
      #  build the tags.
      # @param  [String] path The relative path to the file for the tag.
      #
      def html_tag(gestalt, path)
        gestalt.link(
          :rel  => 'stylesheet',
          :href => path,
          :type => 'text/css'
        )
      end
    end # CSS
  end # Asset
end # Ramaze
