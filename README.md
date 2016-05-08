# Shrine::Mongoid

Provides [Mongoid] integration for [Shrine].

## Installation

```ruby
gem "shrine-mongoid"
gem "shrine", github: "janko-m/shrine" # backgrounding support
```

## Usage

```rb
Shrine.plugin :mongoid
```
```rb
class Post
  include Mongoid::Document
  include ImageUploader[:image]

  field :image_data, type: String
end
```
```rb
post = Post.new
post.image = file
post.image.storage_key #=> "cache"
post.save
post.image.storage_key #=> "store"
post.destroy
post.image.exists?     #=> false
```

## Contributing

You can run the tests with the Rake task:

```
$ bundle exec rake test
```

## License

[MIT](LICENSE.txt)

[Mongoid]: https://github.com/mongodb/mongoid
[Shrine]: https://github.com/janko-m/shrine
