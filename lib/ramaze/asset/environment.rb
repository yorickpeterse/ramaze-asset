require __DIR__('file_group')
require __DIR__('css')
require __DIR__('javascript')

module Ramaze
  module Asset
    ##
    # The Environment class can be used to create isolated environments of which
    # each serves it's own set of assets and has it's own cache path. Creating a
    # new environment can be done by initializing the class:
    #
    #     env = Ramaze::Asset::Environment.new(:cache_path => '...')
    #
    # It's important to remember that the cache path will *not* be created if it
    # doesn't exist.
    #
    # Once an environment has been created you can tell it to serve files by
    # calling the serve() method:
    #
    #     env.serve(:javascript, ['js/mootools/core'], :minify => true)
    #
    # The first parameter is the type of file to serve. Out of the box
    # Ramaze::Asset serves Javascript (:javascript) and CSS (:css) files. The
    # second parameter is an array of files relative to one of Ramaze's public
    # directories (with or without extension). The last parameter is a hash
    # containing various options.
    #
    # Once you've added a set of files you'll need to minify them (if there are
    # any files to minify) followed by generating the HTML tags. This is done in
    # two separate steps for each type of file you want to build:
    #
    #     # Minify all Javascript files and generate the HTML
    #     env.build(:javascript)
    #     env.build_html(:javascript)
    #
    #     # Do the same for CSS files
    #     env.build(:css)
    #     env.build_html(:css)
    #
    # It's best to handle the minifying of files while booting up your
    # application, this way HTTP requests won't be delayed the first time a set
    # of files is minified. Note that files are only minified the first time OR
    # when their content has changed.
    #
    # ## Registering Types
    #
    # Ramaze::Asset is built in such a way that it's relatively easy to register
    # file types to serve. This can be done by calling
    # Ramaze::Asset::Environment.register_type() as following:
    #
    #     Ramaze::Asset::Environment.register_type(:less, Ramaze::Asset::Less)
    #
    # The first parameter is the type of file and will be using in methods such
    # as Ramaze::Asset::Environment#serve(), the second parameter is a class
    # that extends Ramaze::Asset::FileGroup. This class should define two
    # methods, minify() and html_tag(). For more information on these methods
    # see Ramaze::Asset::FileGroup#minify() and
    # Ramaze::Asset::FileGroup#html_tag().
    #
    # ## Asset Groups
    #
    # Asset groups are a way of grouping assets together and load them all at
    # the same time. This can be useful if you want to supply packages such as
    # Mootools or jQuery without requiring the user to specify the paths to all
    # the individual files.
    #
    # Adding an asset group can be done by calling
    # Ramaze::Asset::Environment#register_asset_group:
    #
    #     env = Ramaze::Asset::Environment.new(...)
    #
    #     env.register_asset_group(:mootools) do |env|
    #       env.serve(:javascript, ['js/mootools/core', 'js/mootools/more'])
    #       env.serve(:css, ['css/foobar'])
    #     end
    #
    # The group's block is yielded onto the environment it was added to, thus
    # the "env" parameter is required.
    #
    # Loading this group can be done by calling
    # Ramaze::Asset::AssetManager#load_asset_group and specifying the name of
    # the group to load:
    #
    #     env.load_asset_group(:mootools)
    #
    # @author Yorick Peterse
    # @since  0.1
    #
    class Environment
      # Hash containing all the file groups for the current environment.
      attr_reader :files

      # Hash containing all the file group types and their classes.
      Types = {}

      ##
      # Registers a new type of file to serve. See Ramaze::Asset::FileGroup for
      # more information about the structure of the class used for the file
      # type.
      #
      # @example
      #  class Foobar < Ramaze::Asset::FileGroup
      #    extension '.foobar'
      #
      #    def minify(input)
      #      return input
      #    end
      #
      #    def html_tag(gestalt, path)
      #      gestalt.p(path)
      #    end
      #  end
      #
      #  Ramaze::Asset::Environment.register_type(:foobar, Foobar)
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [#to_sym] name The name of the type such as :js or :css.
      # @param  [Class] klass The klass to initialize for a file group.
      #
      def self.register_type(name, klass)
        name = name.to_sym

        if Types.key?(name)
          raise(
            Ramaze::Asset::AssetError,
            "The type \"#{name}\" already exists"
          )
        end

        Types[name] = klass
      end

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

        @files              = {}
        @added_files        = {}
        @asset_groups       = {}
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
      # Adds a new asset group to the current environment.
      #
      # @example
      #  env = Ramaze::Asset::AssetManager.new(:cache_path => '...')
      #
      #  env.register_asset_group(:mootools) do |env|
      #    env.serve(
      #      :javascript,
      #      ['js/mootools/core', 'js/mootools/more'],
      #      :minify => true,
      #      :name   => 'mootools'
      #    )
      #  end
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Symbol] name The name of the asset group.
      # @param  [Block] block A block that will be yield on the current
      #  instance. This block defines what assets should be loaded.
      #
      def register_asset_group(name, &block)
        name = name.to_sym unless name.is_a?(Symbol)

        if @asset_groups.key?(name)
          raise(
            Ramaze::Asset::AssetError,
            "The asset group \"#{name}\" already exists"
          )
        end

        @asset_groups[name] = block
      end

      ##
      # Loads the given asset group.
      #
      # @example
      #  env = Ramaze::Asset::AssetManager.new(:cache_path => '...')
      #
      #  env.register_asset_group(:mootools) do |env|
      #    env.serve(...)
      #  end
      #
      #  env.load_asset_group(:mootools)
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Symbol] name The name of the asset group to load.
      # @yield  self
      #
      def load_asset_group(name)
        name = name.to_sym unless name.is_a?(Symbol)

        if !@asset_groups.key?(name)
          raise(
            Ramaze::Asset::AssetError,
            "The asset group \"#{name}\" doesn't exist"
          )
        end

        @asset_groups[name].call(self)
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
      # @param  [#to_sym] type The type of files to serve.
      # @param  [Array] files An array of files to serve from one of the public
      #  directories.
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
      def serve(type, files, options = {})
        type = type.to_sym

        if !Types.key?(type)
          raise(
            Zen::Asset::AssetError,
            "The type \"#{type}\" doesn't exist"
          )
        end

        @files[type]       ||= {:global => {:__all => []}}
        @added_files[type] ||= []

        options, controller, methods = prepare_options(options)
        file_group                   = Types[type].new(files, options)

        store_group(type, file_group, controller, methods)
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

        if @files.nil? or !@files.key?(type)
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

        if @files.nil? or !@files.key?(type)
          raise(
            Ramaze::Asset::AssetError,
            "The type \"#{type}\" doesn't exist"
          )
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

      ##
      # Resets the environment by removing all the loaded files from it.
      #
      # @author Yorick Peterse
      # @since  0.1
      #
      def reset!
        @files.each do |type, controllers|
          @files[type] = {:global => {:__all => []}}
        end

        @added_files.each do |type, files|
          @added_files[type] = []
        end
      end

      private

      ##
      # Assigns the file groups to the correct hash in the @files array. This
      # method ignores files that have already been loaded.
      #
      # @author Yorick Peterse
      # @since  0.1
      # @param  [Symbol] key A key in the @files hash to store the results in.
      # @param  [Ramaze::Asset::Javascript|Ramaze::Asset::CSS] file_group The
      #  file group to store.
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


        if !controller.is_a?(Symbol)
          controller = controller.to_s.to_sym
        end

        if !methods.respond_to?(:each_with_index)
          methods = [methods]
        end

        methods.each_with_index do |method, index|
          methods[index] = method.to_sym
        end

        return [options, controller, methods]
      end
    end # Environment
  end # Asset
end # Ramaze
