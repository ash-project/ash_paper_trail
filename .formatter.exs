spark_locals_without_parens = [
  attributes_as_attributes: 1,
  belongs_to_actor: 3,
  change_tracking_mode: 1,
  ignore_attributes: 1,
  mixin: 1,
  on_actions: 1,
  reference_source?: 1,
  store_action_name?: 1,
  version_extensions: 1,
  store_inputs?: 1
]

[
  import_deps: [:ash],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
