# AshPaperTrail

AshPaperTrail is still in its experimental phase. It creates and manages a versions resource for a given resource.

## Setup

First, add the following to your registry:

```elixir
use Ash.Registry,
  extensions: [
    AshPaperTrail.Registry
  ]
```

This will include the version resources in your registry automatically

Then, add the `AshPaperTrail.Resource` extension to any resource you would like to version.

## Destroy Actions

If you are using `AshPostgres`, and you want to support destroy actions, you need to do one of two things:

1. use something like `AshArchival` in conjunction with this resource to ensure that destroy actions are `soft?` and do not actually result in row deletion

2. configure `AshPaperTrail` not to create references, via:

```elixir
paper_trail do
  reference_source? false
end
```

## Attributes

By default, attribute values are stored in the `changes` attribute. This is to protect you over time as your resources change. However, if there are attributes that you are confident will not change,
you can create attributes for them on the version resource, like so:

```elixir
paper_trail do
  attributes_as_attributes [:foo, :bar]
end
```

This will make your version resource have `foo` and `bar` attributes (they will still show up in `changes`), i.e 
```elixir
%ThingVersion{foo: "foo", bar: "bar", changes: %{"foo" => "foo", "bar" => "bar"}}
```

## Enriching the Versions resource

If you want to do something like exposing your versions resource over your graphql, you can use the `mixin` and `version_extensions` options.

For example:

```elixir
paper_trail do
  mixin MyApp.MyResource.PaperTrailMixin
  version_extensions extensions: [AshGraphql.Resource]
end
```

And then you can define a module like so:

```elixir
defmodule MyApp.MyResource.PaperTrailMixin do

  defmacro __using__(_) do
    quote do
      graphql do
        type :my_resource_version

        queries do
          list :list_versions, action: :read
        end
      end
    end
  end
end
```