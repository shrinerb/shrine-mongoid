# Shrine::Plugins::Mongoid

Provides [Mongoid] integration for [Shrine].

## Installation

```ruby
gem "shrine-mongoid"
```

## Usage

```rb
Shrine.plugin :mongoid
```
```rb
class Post
  include Mongoid::Document
  include ImageUploader::Attachment.new(:image)

  field :image_data, type: String # or `type: Hash`
end
```

This plugin will add validations and callbacks:

```rb
post = Post.new
post.image = file
post.image.storage_key #=> "cache"
post.save
post.image.storage_key #=> "store"
post.destroy
post.image.exists?     #=> false
```

If for some reason you don't want callbacks and/or validations, you can turn
them off:

```rb
plugin :mongoid, callbacks: false, validations: false
```

## Contributing

You can run the tests with the Rake task:

```
$ bundle exec rake test
```

Also, to run tests against older versions of Mongoid:

```
$ bundle exec appraisal install
$ bundle exec appraisal mongoid-5 rake test
$ bundle exec appraisal mongoid-6 rake test
```

## License

[MIT](LICENSE.txt)

[Mongoid]: https://github.com/mongodb/mongoid
[Shrine]: https://github.com/shrinerb/shrine
