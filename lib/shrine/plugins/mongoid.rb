require "mongoid"

class Shrine
  module Plugins
    module Mongoid
      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Mongoid::Document

          model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            validate do
              #{@name}_attacher.errors.each do |message|
                errors.add(:#{@name}, message)
              end
            end

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

      module AttacherClassMethods
        # Needed by the backgrounding plugin.
        def find_record(record_class, record_id)
          record_class.where(id: record_id).first
        end
      end

      module AttacherMethods
        private

        # Updates the current attachment with the new one, unless the current
        # attachment has changed.
        def swap(uploaded_file)
          return if record.send(:"#{name}_data") != record.reload.send(:"#{name}_data")
          super
        rescue ::Mongoid::Errors::DocumentNotFound
        end

        # We save the record after updating, raising any validation errors.
        def update(uploaded_file)
          super
          record.save!
        end
      end
    end

    register_plugin(:mongoid, Mongoid)
  end
end
