module Lockistics
  module Meterable
    def self.included(where)
      where.extend ClassMethods
    end

    module ClassMethods
      @@_metered_methods = {}
      @@_meter_all = false

      def meter_wrap(meth_name)
        @@_metered_methods[meth_name][:method] = instance_method(meth_name)
        define_method(meth_name) do |*args, &block|
          Lockistics.meter("#{@@_metered_methods[meth_name][:options][:prefix]}_#{meth_name}") do
            @@_metered_methods[meth_name][:method].bind(self).call *args, &block
          end
        end
      end

      def meter(*args)
        if args.last.kind_of?(Hash)
          options = args.pop
        else
          options = {}
        end
        options = {
          :prefix => self.name.downcase
        }.merge(options)

        if args.first.eql?(:all)
          @@_meter_all = true
          @@_meter_all_options = {:except => []}.merge(options)
        end

        Array(args).each do |meth_name|
          @@_metered_methods[meth_name] = {}
          @@_metered_methods[meth_name][:options] = options
        end
      end

      def method_added(meth_name)
        super
        if @@_metered_methods && @@_metered_methods[meth_name] && @@_metered_methods[meth_name][:method].nil?
          meter_wrap meth_name
        elsif @@_meter_all && !Array(@@_meter_all_options[:except]).include?(meth_name) && @@_metered_methods[meth_name].nil?
          @@_metered_methods[meth_name] = {}
          @@_metered_methods[meth_name][:options] = @@_meter_all_options
          meter_wrap meth_name
        end
      end

    end
  end
end
