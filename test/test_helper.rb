require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "mocha/minitest"

require "shrine"
require "shrine/storage/memory"

require "stringio"

class Minitest::Spec
  def uploader(storage_key = :store, &block)
    uploader_class = Class.new(Shrine)
    uploader_class.storages[:cache] = Shrine::Storage::Memory.new
    uploader_class.storages[:store] = Shrine::Storage::Memory.new
    uploader_class.class_eval(&block) if block
    uploader_class.new(storage_key)
  end

  def fakeio(string = "")
    StringIO.new(string)
  end
end
