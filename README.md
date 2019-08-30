# Shrine::Plugins::Mongoid

Provides [Mongoid] integration for [Shrine].

## Installation

```ruby
gem "shrine-mongoid", "~> 1.0"
```

## Usage

```rb
Shrine.plugin :mongoid
```
```rb
class ImageUploader < Shrine
end
```
```rb
class Photo
  include Mongoid::Document
  include ImageUploader::Attachment(:image)

  field :image_data, type: String # or `type: Hash`
end
```

The `Shrine::Attachment` module will add [model] methods, as well as
[callbacks](#callbacks) and [validations](#validations) to tie attachment
process to the record lifecycle:

```rb
photo = Photo.new

photo.image = file # cache attachment

photo.image      #=> #<Shrine::UploadedFile @id="bc2e13.jpg" @storage_key=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

photo.save # persist, promote attachment, then persist again

photo.image      #=> #<Shrine::UploadedFile @id="397eca.jpg" @storage_key=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'

photo.destroy # delete attachment

photo.image.exists? #=> false
```

### Callbacks

#### After Save

After a record is saved, `Attacher#finalize` is called, which promotes cached
file to permanent storage and deletes previous file if any.

```rb
photo = Photo.new

photo.image = file
photo.image.storage_key #=> :cache

photo.save
photo.image.storage_key #=> :store
```

#### After Destroy

After a record is destroyed, `Attacher#destroy_attached` method is called,
which deletes stored attached file if any.

```rb
photo = Photo.find(photo_id)
photo.image #=> #<Shrine::UploadedFile>
photo.image.exists? #=> true

photo.destroy
photo.image.exists? #=> false
```

#### Skipping Callbacks

If you don't want the attachment module to add any callbacks to your model, you
can set `:callbacks` to `false`:

```rb
plugin :mongoid, callbacks: false
```

### Validations

If you're using the [`validation`][validation] plugin, the attachment module
will automatically merge attacher errors with model errors.

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10 * 1024 * 1024
  end
end
```
```rb
photo = Photo.new
photo.image = file
photo.valid?
photo.errors #=> { image: ["size must not be greater than 10.0 MB"] }
```

#### Attachment Presence

If you want to validate presence of the attachment, you can use ActiveModel's
presence validator:

```rb
class Photo
  include Mongoid::Document
  include ImageUploader::Attachment(:image)

  validates_presence_of :image
end
```

#### Skipping Validations

If don't want the attachment module to merge file validations errors into
model errors, you can set `:validations` to `false`:

```rb
plugin :mongoid, validations: false
```

## Attacher

You can also use `Shrine::Attacher` directly (with or without the
`Shrine::Attachment` module):

```rb
class Photo
  include Mongoid::Document

  field :image_data, type: String # or `type: Hash`
end
```
```rb
photo    = Photo.new
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.assign(file) # cache

attacher.file    #=> #<Shrine::UploadedFile @id="bc2e13.jpg" @storage_key=:cache ...>
photo.image_data #=> '{"id":"bc2e13.jpg","storage":"cache","metadata":{...}}'

photo.save        # persist
attacher.finalize # promote
photo.save        # persist

attacher.file    #=> #<Shrine::UploadedFile @id="397eca.jpg" @storage_key=:store ...>
photo.image_data #=> '{"id":"397eca.jpg","storage":"store","metadata":{...}}'
```

### Pesistence

The following persistence methods are added to `Shrine::Attacher`:

| Method                    | Description                                                            |
| :-----                    | :----------                                                            |
| `Attacher#atomic_promote` | calls `Attacher#promote` and persists if the attachment hasn't changed |
| `Attacher#atomic_persist` | saves changes if the attachment hasn't changed                         |
| `Attacher#persist`        | saves any changes to the underlying record                             |

See [persistence] docs for more details.

## Contributing

You can run the tests with the Rake task:

```
$ bundle exec rake test
```

## License

[MIT](LICENSE.txt)

[Mongoid]: https://github.com/mongodb/mongoid
[Shrine]: https://github.com/shrinerb/shrine
[model]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/model.md#readme
[validation]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/validation.md#readme
[persistence]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/persistence.md#readme
