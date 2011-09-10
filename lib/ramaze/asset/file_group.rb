require 'fileutils'
require 'digest/sha1'
require 'ramaze/gestalt'

module Ramaze
  module Asset
    ##
    # Ramaze::Asset::FileGroup is used to group a set of files of the same type,
    # such as Javascript files, together. The HTML for these files can be
    # generated as well as a minified version of all the files.
    #
    # ## Creating File Groups
    #
    # Ramaze::Asset comes with two file groups that are capable of processing
    # Javascript and CSS files. If you need to have a file group for
    # Coffeescript, Less or other files is quite easy to add these yourself.
    # First you must create a class that extends Ramaze::Asset::FileGroup:
    #
    #     class Less < Ramaze::Asset::FileGroup
    #
    #     end
    #
    # It's important that you define the correct file extensions for your file
    # group. Without this Ramaze::Asset will not be able to find the files for
    # you (unless they have an extension specified) and the minified file will
    # end up not having an extension. Setting an extension can be done by
    # calling the class method ``extension()``. This method has two parameters,
    # the first one is the extension of the source file, the second the
    # extension for the minified file. In case of Less this would result in the
    # following:
    #
    #     class Less < Ramaze::Asset::FileGroup
    #       extension '.less', '.css'
    #     end
    #
    # The next step is to define your own minify() and html_tag() methods. If
    # you don't define these methods they'll raise an error and most likely
    # break things.
    #
    #     class Less < Ramaze::Asset::FileGroup
    #       extension '.less', '.css'
    #
    #       def minify(input)
    #
    #       end
    #
    #       def html_tag(gestalt, path)
    #
    #       end
    #     end
    #
    # The minify() method should return a string containing the minified data.
    # The html_tag() method uses an instance of Ramaze::Gestalt to build a
    # single tag for a given (relative) path.
    #
    # A full example of Less looks like the following:
    #
    #     require 'tempfile'
    #
    #     class Less < Ramaze::Asset::FileGroup
    #       extension '.less', '.css'
    #
    #       # +input+ contains the raw Less data. The command line tool only
    #       # accepts files so this data has to be written to a temp file.
    #       def minify(input)
    #         file = Tempfile.new('less')
    #         file.write(input)
    #         file.rewind
    #
    #         minified = `lessc #{file.path} -x`
    #
    #         file.close(true)
    #
    #         return minified
    #       end
    #
    #       def html_tag(gestalt, path)
    #         gestalt.link(
    #           :rel  => 'stylesheet',
    #           :href => path,
    #           :type => 'text/css'
    #         )
    #       end
    #     end
    #
    # Note that it's important to remember that when dealing with files that
    # have to be compiled, such as Less and Coffeescript files, setting :minify
    # to false will not work. Without setting this option to true the minify()
    # method will never be called and thus the raw Less/Coffeescript file would
    # be served.
    #
    # @author Yorick Peterse
    # @since  0.1
    #
    class FileGroup
      # Array containing all the files that belong to this group, including
      # their files extensions.
      attr_accessor :files

      # Hash containing all the options for the file group.
      attr_reader :options

      ##
      # Sets the file extensions for the current class. These extensions should
      # start with a dot.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [#to_s] source_ext The extension of the source file such as
      #  ".css" or ".js".
      # @param  [#to_s] minified_ext The extension to use for the minified file.
      #  Useful when the resulting extension is different than the source
      #  extension (such as with Less or Coffeescript).
      #
      def self.extension(source_ext, minified_ext = nil)
        if minified_ext.nil?
          minified_ext = '.min' + source_ext
        end

        if source_ext[0] != '.' or minified_ext[0] != '.'
          raise(
            Ramaze::Asset::AssetError,
            'Extensions should start with a dot'
          )
        end

        self.instance_variable_set(
          :@extension,
          {:source => source_ext, :minified => minified_ext}
        )
      end

      ##
      # Creates a new instance of the file group and prepares it.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Array] files An array of files for this group.
      # @param  [Hash] options A hash containing various options to customize
      #  this file group.
      # @option options :minify When set to true all the files in the group will
      #  be minified.
      # @option options :name A name to use for the minified file. By default
      #  this is set to a hash of all the file names.
      # @option options :paths An array of file paths to look for the files.
      # @option options :cache_path The path to a directory where the minified
      #  files should be saved.
      #
      def initialize(files, options = {})
        @minified = false
        @files    = files
        @options  = {
          :minify     => false,
          :name       => nil,
          :paths      => [],
          :cache_path => []
        }.merge(options)

        if @options[:paths].empty?
          raise(
            Ramaze::Asset::AssetError,
            'No public directories were specified'
          )
        end

        if !File.directory?(@options[:cache_path])
          raise(
            Ramaze::Asset::AssetError,
            "The directory #{@options[:cache_path]} does not exist"
          )
        end

        if extension.nil?
          raise(
            Ramaze::Asset::AssetError,
            'You need to specify an extension'
          )
        end

        prepare_files

        # When :minify is set :name should also be set.
        if @options[:minify] === true and @options[:name].nil?
          @options[:name] = @files.map { |file| file }.join()
          @options[:name] = Digest::SHA1.new.hexdigest(@options[:name])
        end

        if !@options[:name].nil?
          @options[:name] += extension[:minified]
        end
      end

      ##
      # Returns the extension of the current file group.
      #
      # @author Yorick Peterse
      # @since  0.1.
      # @return [String]
      #
      def extension
        return self.class.instance_variable_get(:@extension)
      end

      ##
      # When the :minify option is set to true this method will merge all files,
      # minify them and cache them in the :cache_path directory.
      #
      # @author Yorick Peterse
      # @since  0.1
      #
      def build
        return if @options[:minify] != true

        cache_path = File.join(
          @options[:cache_path],
          @options[:name]
        )

        # Minify the file in a sub process so that memory leaks (or just general
        # increases of memory usage) don't affect the master process.
        pid = Process.fork do
          processed  = []
          file_paths = []
          minified   = ''
          write      = true

          # Try to find the paths to the files.
          @options[:paths].each do |directory|
            @files.each do |file|
              path = File.join(directory, file)

              # Only add the file to the list if it hasn't already been added.
              if File.exist?(path) and !processed.include?(file)
                file_paths.push(path)
                processed.push(file)
              end
            end
          end

          file_paths.each do |file|
            minified += minify(File.read(file, File.size(file)))
          end

          # Check if the file already exists. If this is the cache a hash of
          # both files is generated and compared. If it's different the file has
          # to be re-created.
          if File.exist?(cache_path)
            old_hash = Digest::SHA1.new.hexdigest(minified)
            new_hash = Digest::SHA1.new.hexdigest(
              File.read(cache_path, File.size(cache_path))
            )

            if old_hash === new_hash
              write = false
            end
          end

          if write === true
            File.open(cache_path, 'w') do |handle|
              handle.write(minified)
              handle.close
            end
          end

          # Don't call any at_exit() hooks, they're not needed in this process.
          Kernel.exit!
        end

        Process.waitpid(pid)

        # Make sure the cache file is present
        if !File.size?(cache_path)
          raise(
            Ramaze::Asset::AssetError,
            "The cache file #{cache_path} could not be created"
          )
        end

        @minified = true
      end

      ##
      # Builds the HTML tags for all the current files.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @return [String]
      #
      def build_html
        if @options[:minify] === true and @minified === true
          files = [('/' + @options[:name]).squeeze('/')]
        else
          files = @files
        end

        g = Ramaze::Gestalt.new

        files.each { |file| html_tag(g, file) }

        return g.to_s
      end

      ##
      # Minifies a single file.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [String] input The string to minify.
      # @raise  NotImplementedError Raised when the sub class didn't implement
      #  this method.
      #
      def minify(input)
        raise(
          NotImplementedError,
          'You need to define your own minify() instance method'
        )
      end

      ##
      # Builds the HTML tag for a single file using Ramaze::Gestalt.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Ramaze::Gestalt] gestalt An instance of Ramaze::Gestalt that's
      #  used to build all the tags.
      # @param  [String] path The relative path to the file.
      # @raise  NotImplementedError Raised when the sub class didn't implement
      #  this method.
      #
      def html_tag(gestalt, path)
        raise(
          NotImplementedError,
          'You need to define your own build_html instance method'
        )
      end

      private

      ##
      # Loops through all the files and adds the required extensions to them and
      # makes sure they're relative to the root rather than the current working
      # directory.
      #
      # @author Yorick Peterse
      # @since  0.1
      #
      def prepare_files
        @files.each_with_index do |file, index|
          file += extension[:source] if File.extname(file) != extension[:source]

          if file[0] != '/'
            file = '/' + file
          end

          file = file.squeeze('/')

          @files[index] = file
        end
      end
    end # FileGroup
  end # Asset
end # Ramaze
