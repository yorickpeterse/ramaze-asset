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
      # Sets the extension of the current class in the instance variable
      # @extension.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [#to_s] ext The extension such as ".css" or ".js".
      #
      def self.extension(ext)
        self.instance_variable_set(:@extension, ext)
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
          raise(Ramaze::Asset::Error, 'No public directories were specified')
        end

        if !File.directory?(@options[:cache_path])
          raise(
            Ramaze::Asset::Error,
            "The directory #{@options[:cache_path]} does not exist"
          )
        end

        if extension.nil?
          raise(Ramaze::Asset::Error, 'You need to specify an extension')
        end

        prepare_files

        # When :minify is set :name should also be set.
        if @options[:minify] === true and @options[:name].nil?
          @options[:name] = @files.map { |file| file }.join()
          @options[:name] = Digest::SHA1.new.hexdigest(@options[:name])
        end

        # Add a .min suffix if this hasn't already been done so.
        unless @options[:name] =~ /\.min/
          @options[:name] += '.min'
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
          @options[:name] + extension
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
        end

        Process.waitpid(pid)

        # Make sure the cache file is present
        if !File.exist?(cache_path)
          raise(
            Ramaze::Asset::Error,
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
          files = [('/' + @options[:name]).squeeze('/') + extension]
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
          file += extension if File.extname(file) != extension

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
