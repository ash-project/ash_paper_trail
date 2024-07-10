spark_locals_without_parens = [
  allow_nil?: 1,
  attribute_type: 1,
  attributes_as_attributes: 1,
  belongs_to_actor: 2,
  belongs_to_actor: 3,
  change_tracking_mode: 1,
  define_attribute?: 1,
  domain: 1,
  ignore_attributes: 1,
  include_versions: 1,
  mixin: 1,
  on_actions: 1,
  public?: 1,
  reference_source?: 1,
  relationship_opts: 1,
  store_action_name?: 1,
  version_extensions: 1,
  version_resource: 1
]

[
  import_deps: [:ash],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
