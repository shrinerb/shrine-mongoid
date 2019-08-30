require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"
require "mocha/minitest"

require "shrine"
require "shrine/storage/memory"
require "mongoid"

require "stringio"

Mongoid.load!("test/mongoid.yml", :test)

class Minitest::Test
  def fakeio(content = "file")
    StringIO.new(content)
  end
end

class RubySerializer
  def self.dump(data)
    data.to_s
  end

  def self.load(data)
    eval(data)
  end
end
