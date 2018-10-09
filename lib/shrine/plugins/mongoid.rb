require "mongoid"

class Shrine
  module Plugins
    module Mongoid
      def self.configure(uploader, opts = {})
        uploader.opts[:mongoid_callbacks] = opts.fetch(:callbacks, uploader.opts.fetch(:mongoid_callbacks, true))
        uploader.opts[:mongoid_validations] = opts.fetch(:validations, uploader.opts.fetch(:mongoid_validations, true))
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Mongoid::Document

          if shrine_class.opts[:mongoid_validations]
            model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              validate do
                #{@name}_attacher.errors.each do |message|
                  errors.add(:#{@name}, message)
                end
              end
            RUBY
          end

          if shrine_class.opts[:mongoid_callbacks]
            model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              before_save do
                #{@name}_attacher.save if #{@name}_attacher.attached?
              end

              after_save do
                #{@name}_attacher.finalize if #{@name}_attacher.attached?
              end

              after_destroy do
                #{@name}_attacher.destroy
              end
            RUBY
          end
        end
      end

      module AttacherClassMethods
        # Needed by the backgrounding plugin.
        def find_record(record_class, record_id)
          record_class.where(id: record_id).first
        end

        def load_record(data)
          return super unless data["parent_record"]

          _record_class, record_id = data["record"]

          parent_class, parent_id, relation_name = data["parent_record"]

          parent_class = Object.const_get(parent_class)
          parent = find_record(parent_class, parent_id)

          record =
            if parent.public_send(relation_name).is_a?(Array)
              find_embedded_record(parent, relation_name, record_id)
            else
              find_single_embedded_record(parent, relation_name, record_id)
            end

          record
        end

        private

        def find_single_embedded_record(parent, relation_name, record_id)
          # NOTE: perhaps it's good to check if record_id matches existing one
          parent.public_send(relation_name) ||
            parent.public_send("build_#{relation_name}") do |instance|
              # so that the id is always included in file deletion logs
              instance.singleton_class.send(:define_method, :id) { record_id }
            end
        end

        def find_embedded_record(parent, relation_name, record_id)
          relation = parent.public_send(relation_name)
          relation.where(id: record_id).first ||
            relation.build do |instance|
              # so that the id is always included in file deletion logs
              instance.singleton_class.send(:define_method, :id) { record_id }
            end
        end
      end

      module AttacherMethods
        private

        # We save the record after updating, raising any validation errors.
        def update(uploaded_file)
          super
          record.save!
        end

        def convert_before_write(value)
          mongoid_hash_field? ? value : super
        end

        def mongoid_hash_field?
          return false unless record.is_a?(::Mongoid::Document)
          return false unless field = record.class.fields[data_attribute.to_s]

          field.type == Hash
        end
      end
    end

    register_plugin(:mongoid, Mongoid)
  end
end
