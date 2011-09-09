require __DIR__('file_group')
require __DIR__('css')
require __DIR__('javascript')

module Ramaze
  module Asset
    ##
    # An asset manager capable of minifying and serving your assets.
    #
    # @author Yorick Peterse
    # @since  0.1
    #
    class Environment
      ##
      # Creates a new instance of the environment and prepares it.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Hash] options A hash containing various options to customize
      #  the environment.
      # @option options :cache_path A directory to use for saving all minified
      #  files. This directory should be a public directory so that the files in
      #  it can be served by either Ramaze or your webserver.
      # @option options :minify When set to false no files will be minified
      #  regardless of their individual settings. Useful while developing the
      #  application. When set to true all files will be minified *unless* a
      #  group turned the option off.
      #
      def initialize(options = {})
        @options = {
          :cache_path => nil,
          :minify     => false
        }.merge(options)

        if !File.directory?(@options[:cache_path])
          raise(
            Ramaze::Asset::AssetError,
            "The cache directory #{@options[:cache_path]} doesn't exist"
          )
        end

        @files = {
          :css        => {:global => {:__all => []}},
          :javascript => {:global => {:__all => []}}
        }

        @added_files = {
          :css        => [],
          :javascript => []
        }

        @file_group_options = {
          :paths      => [],
          :cache_path => @options[:cache_path]
        }

        # Get all the public directories to serve files from.
        Ramaze.options.roots.each do |root|
          Ramaze.options.publics.each do |pub|
            pub = File.join(root, pub)

            if File.directory?(pub)
              @file_group_options[:paths].push(pub)
            end
          end
        end

        if @file_group_options[:paths].empty?
          raise(
            Ramaze::Asset::AssetError,
            'No existing public directories were found'
          )
        end
      end

      ##
      # Adds a set of Javascript files to the environment.
      #
      # @example
      #  env = Ramaze::Asset::Environment.new(__DIR__('public'))
      #  env.javascript(
      #    ['mootools/core', 'mootools/more'],
      #    :controller => :global,
      #    :minify     => true,
      #    :name       => 'mootools'
      #  )
      #
      # @author Yorick Peterse
      # @since  0.1
      # @see    Ramaze::Asset::FileGroup
      # @see    Ramaze::Asset::Javascript
      # @param  [Array] files An array of Javascript files to serve from one of
      #  the public directories.
      # @param  [Hash] options A hash containing various options to customize
      #  the file group.
      # @option options :controller The controller to serve the files for, set
      #  to :global to serve the files for *all* controllers. By default files
      #  are loaded globally.
      # @option options :methods An array of methods that belong to the
      #  controller set in :controller. When setting these methods the files
      #  will only be served when those methods are executed. This option is
      #  completely ignored if :controller is set to :global.
      #
      def javascript(files, options = {})
        options, controller, methods = prepare_options(options)

        file_group = Ramaze::Asset::Javascript.new(files, options)

        store_group(:javascript, file_group, controller, methods)
      end

      ##
      # Adds a set of CSS files to the environment.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Array] files An array of CSS files to add.
      # @param  [Hash] options A hash containing various options to customize
      #  the file group.
      # @see    Ramaze::Asset::FileGroup
      # @see    Ramaze::Asset::CSS
      # @see    Ramaze::Asset::Environment#javascript()
      #
      def css(files, options = {})
        options, controller, methods = prepare_options(options)

        file_group = Ramaze::Asset::CSS.new(files, options)

        store_group(:css, file_group, controller, methods)
      end

      ##
      # Builds all the files for the given type.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [#to_sym] ty]e The type of files to build.
      # @see    Ramaze::Asset::FileGroup#build()
      #
      def build(type)
        type = type.to_sym

        if !@files.key?(type)
          raise(Ramaze::Asset::AssetError, "The type \"#{type}\" doesn't exist")
        end

        @files[type].each do |controller, methods|
          methods.each do |method, groups|
            groups.each do |group|
              group.build
            end
          end
        end
      end

      ##
      # Builds the HTML tags for all the files of the given type.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [#to_sym] type The type of files to build the HTML for.
      # @return [String]
      #
      def build_html(type)
        html = ''
        type = type.to_sym

        if !@files.key?(type)
          raise(Ramaze::Asset::AssetError, "The type \"#{type}\" doesn't exist")
        end

        controller, method = current_action

        # Build all the global tags
        @files[type][:global][:__all].each do |group|
          html += group.build_html
        end

        # Build the ones for the current controller
        if !controller.nil? and @files[type].key?(controller)
          if method.nil?
            method = :__all
          elsif !method.nil? and !@files[type][controller].key?(method)
            method = :__all
          end

          @files[type][controller][method].each do |group|
            html += group.build_html
          end
        end

        return html
      end

      private

      ##
      # Assigns the file groups to the correct hash in the @files array. This
      # method ignores files that have already been loaded.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Symbol] key A key in the @files hash to store the results in.
      # @param  [Ramaze::Asset::Javascript|Ramaze::Asset::CSS] file_group The file
      #  group to store.
      # @param  [Symbol] controller The controller to store the file group in.
      # @param  [Array] methods An array of methods to store the file group in.
      #
      def store_group(key, file_group, controller, methods)
        # Remove all files from the group that have already been loaded.
        file_group.files.each_with_index do |file, index|
          if @added_files.key?(key) and @added_files[key].include?(file)
            file_group.files.delete_at(index)
          end
        end

        return if file_group.files.empty?

        # Store the group
        controller = controller.to_sym unless controller.is_a?(Symbol)

        methods.each_with_index do |m, i|
          methods[i] = m.to_sym unless m.is_a?(Symbol)
        end

        @files[key][controller] ||= {:__all => []}

        # Add the group to each method.
        methods.each do |m|
          @files[key][controller][m] ||= []
          @files[key][controller][m].push(file_group)
        end

        @added_files[key] += file_group.files
      end

      ##
      # Gets the class and method of the current request.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @return [Array] Array containing the controller and method. The first
      #  item is the controller, the second the method.
      #
      def current_action
        begin
          controller = Ramaze::Current.action.node.to_s.to_sym
          method     = Ramaze::Current.action.method.to_s.to_sym
        rescue
          controller = nil
          method     = nil
        end

        # When called in a layout the current action is different than the one
        # we're interested in.
        if !method.nil? and method.empty? and Ramaze::Current.actions[-2]
          method = Ramaze::Current.actions[-2].method.to_s.to_sym
        end

        return [controller, method]
      end

      ##
      # Prepares the options for Ramaze::Asset::Environment#javascript() and
      # Ramaze::Asset::Environment#css().
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Hash] options A hash with options.
      # @return [Array]
      #
      def prepare_options(options)
        if @options[:minify] === true
          if !options.key?(:minify)
            options[:minify] = true
          end
        else
          options[:minify] = false
        end

        controller = options.delete(:controller) || :global
        methods    = options.delete(:methods)    || [:__all]
        options    = options.merge(@file_group_options)

        return [options, controller, methods]
      end
    end # Environment
  end # Asset
end # Ramaze
