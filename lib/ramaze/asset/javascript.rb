require __DIR__('../../vendor/jsmin')

module Ramaze
  module Asset
    ##
    # File group for Javascript files. These Javascript files are minified using
    # JSMin.
    #
    # @author Yorick Peterse
    # @since  0.1
    #
    class Javascript < Ramaze::Asset::FileGroup
      extension '.js'

      ##
      # Minifies the output and returns the result as a string.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [String] input The input to minify.
      # @return [String]
      #
      def minify(input)
        return JSMin.minify(input)
      end

      ##
      # Builds a <script> tag for a single Javascript file.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Ramaze::Gestalt] gestalt An instance of Ramaze::Gestalt used to
      #  build the tags.
      # @param  [String] path The relative path to the file for the tag.
      #
      def html_tag(gestalt, path)
        gestalt.script(:scr => path, :type => 'text/javascript')
      end
    end # Javascript
  end # Asset
end # Ramaze
