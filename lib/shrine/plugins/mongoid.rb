# frozen_string_literal: true

require "mongoid"

class Shrine
  module Plugins
    module Mongoid
      VALID_FINALIZE_OPTS = [nil, :before_save, :after_save].freeze

      def self.load_dependencies(uploader, *)
        uploader.plugin :model
        uploader.plugin :_persistence, plugin: self
      end

      def self.configure(uploader, **opts)
        unless VALID_FINALIZE_OPTS.include?(opts[:finalize])
          fail ArgumentError, "valid finalize options: #{VALID_FINALIZE_OPTS}"
        end

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

          define_method :"#{name}_finalize" do
            send(:"#{name}_attacher").finalize
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

        # Calls Attacher#save and finalizes attachment if so configured.
        # Called before model save.
        def mongoid_before_save
          return unless changed?

          save
          finalize if shrine_class.opts[:mongoid][:finalize] == :before_save
        end

        # Finalizes attachment if so configured.
        # Makes sense when used with the backgrounding plugin.
        # Called after model save.
        def mongoid_after_save
          return unless changed?

          finalize if shrine_class.opts[:mongoid][:finalize] == :after_save
        end

        # Deletes attached files. Called after model destroy.
        def mongoid_after_destroy
          destroy_attached
        end

        # Saves changes to the model instance, skipping validation.
        # Used by the _persistence plugin.
        def mongoid_persist
          record.save(validate: false)
        end

        # Internal only
        def _find_root_parent(record)
          parent = record._parent
          return parent unless parent.embedded?

          _find_root_parent(parent)
        end

        # Internal only
        def _copy_record_instance(record)
          copy    = record.dup
          copy.id = record.id
          copy
        end

        # Yields the reloaded record. Used by the _persistence plugin.
        def mongoid_reload
          unless record.persisted?
            return yield record
          end

          unless record.embedded?
            return yield _copy_record_instance(record).reload
          end

          parent_copy = _copy_record_instance(_find_root_parent(record)).reload
          record_copy = parent_copy._children.find do |child|
            child.class == record.class && child.id == record.id
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
