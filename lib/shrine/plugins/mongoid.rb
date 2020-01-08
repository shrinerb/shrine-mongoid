# frozen_string_literal: true

require "mongoid"

class Shrine
  module Plugins
    module Mongoid
      def self.load_dependencies(uploader, *)
        uploader.plugin :model
        uploader.plugin :_persistence, plugin: self
      end

      def self.configure(uploader, **opts)
        uploader.opts[:mongoid] ||= { validations: true, callbacks: true }
        uploader.opts[:mongoid].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Mongoid::Document

          name = @name

          if shrine_class.opts[:mongoid][:validations]
            # add validation plugin integration
            model.validate do
              send(:"#{name}_attacher").send(:mongoid_validate)
            end
          end

          if shrine_class.opts[:mongoid][:callbacks]
            model.before_save do
              send(:"#{name}_attacher").send(:mongoid_before_save)
            end

            model.after_save do
              send(:"#{name}_attacher").send(:mongoid_after_save)
            end

            model.after_destroy do
              send(:"#{name}_attacher").send(:mongoid_after_destroy)
            end
          end

          define_method :reload do |*args|
            result = super(*args)
            instance_variable_set(:"@#{name}_attacher", nil)
            result
          end
        end
      end

      # The _persistence plugin uses #mongoid_persist, #mongoid_reload and
      # #mongoid? to implement the following methods:
      #
      #   * Attacher#persist
      #   * Attacher#atomic_persist
      #   * Attacher#atomic_promote
      module AttacherMethods
        private

        def mongoid_validate
          return unless respond_to?(:errors)

          errors.each do |message|
            record.errors.add(name, message)
          end
        end

        # Calls Attacher#save. Called before model save.
        def mongoid_before_save
          return unless changed?

          save
        end

        # Finalizes attachment and persists changes. Called after model save.
        def mongoid_after_save
          return unless changed?

          finalize
          persist
        end

        # Deletes attached files. Called after model destroy.
        def mongoid_after_destroy
          destroy_attached
        end

        # Saves changes to the model instance, raising exception on validation
        # errors. Used by the _persistence plugin.
        def mongoid_persist
          record.save(validate: false)
        end

        # Yields the reloaded record. Used by the _persistence plugin.
        def mongoid_reload
          if record.embedded?
            parent_copy    = record._parent.dup
            parent_copy.id = record._parent.id
            parent_copy.reload
            record_copy = parent_copy._children.find do |child|
              child.id == record.id && child.class == record.class
            end
          else
            record_copy    = record.dup
            record_copy.id = record.id
            record_copy.reload
          end

          yield record_copy
        end

        # Returns true if the data attribute represents a Hash field. Used by
        # the _persistence plugin to determine whether serialization should be
        # skipped.
        def mongoid_hash_attribute?
          field = record.class.fields[attribute.to_s]
          field && field.type == Hash
        end

        # Returns whether the record is a Mongoid document. Used by the
        # _persistence plugin.
        def mongoid?
          record.is_a?(::Mongoid::Document)
        end
      end
    end

    register_plugin(:mongoid, Mongoid)
  end
end
