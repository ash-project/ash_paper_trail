defmodule AshPaperTrail.Resource.Transformers.CreateVersionResource do
  @moduledoc "Creates a version resource for a given resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  # sobelow_skip ["DOS.StringToAtom", "RCE.CodeModule"]
  def transform(dsl_state) do
    version_module = AshPaperTrail.Resource.Info.version_resource(dsl_state)
    module = Transformer.get_persisted(dsl_state, :module)

    ignore_attributes = AshPaperTrail.Resource.Info.ignore_attributes(dsl_state)
    attributes_as_attributes = AshPaperTrail.Resource.Info.attributes_as_attributes(dsl_state)
    belongs_to_actors = AshPaperTrail.Resource.Info.belongs_to_actor(dsl_state)
    reference_source? = AshPaperTrail.Resource.Info.reference_source?(dsl_state)
    store_action_name? = AshPaperTrail.Resource.Info.store_action_name?(dsl_state)
    version_extensions = AshPaperTrail.Resource.Info.version_extensions(dsl_state)

    attributes =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(&(&1.name in attributes_as_attributes))

    accept =
      [
        :version_action_type,
        if(store_action_name?, do: :version_action_name, else: nil),
        attributes |> Enum.map(& &1.name),
        :version_source_id,
        :changes,
        belongs_to_actors |> Enum.map(&:"#{&1.name}_id")
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    sensitive_changes? =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(&(&1.name in ignore_attributes))
      |> Enum.any?(& &1.sensitive?)

    data_layer = version_extensions[:data_layer] || Ash.DataLayer.data_layer(dsl_state)

    {postgres?, table, repo} =
      if data_layer == AshPostgres.DataLayer do
        {true, apply(AshPostgres, :table, [dsl_state]), apply(AshPostgres, :repo, [dsl_state])}
      else
        {false, nil, nil}
      end

    {ets?, private?} =
      if data_layer == Ash.DataLayer.Ets do
        {true, Ash.DataLayer.Ets.Info.private?(dsl_state)}
      else
        {false, nil}
      end

    multitenant? = not is_nil(Ash.Resource.Info.multitenancy_strategy(dsl_state))

    mixin =
      case AshPaperTrail.Resource.Info.mixin(dsl_state) do
        {m, f, a} ->
          apply(m, f, a)

        nil ->
          quote do
          end

        module when is_atom(module) ->
          quote do
            use unquote(module)
          end
      end

    destination_attribute =
      case Ash.Resource.Info.primary_key(dsl_state) do
        [key] ->
          Ash.Resource.Info.attribute(dsl_state, key)

        keys ->
          raise Spark.Error.DslError,
            module: module,
            path: [:extensions, AshPaperTrail.Resource],
            message: """
            Resources with composite primary keys are not currently supported. Got keys #{inspect(keys)}
            """
      end

    Module.create(
      version_module,
      quote do
        use Ash.Resource,
            unquote(
              version_extensions
              |> Keyword.put(:data_layer, data_layer)
              |> Keyword.put(:domain, Ash.Resource.Info.domain(dsl_state))
              |> Keyword.put(:validate_domain_inclusion?, false)
            )

        def resource_version?, do: true

        if unquote(multitenant?) do
          multitenancy do
            strategy(unquote(Ash.Resource.Info.multitenancy_strategy(dsl_state)))
            attribute(unquote(Ash.Resource.Info.multitenancy_attribute(dsl_state)))

            parse_attribute(
              unquote(Macro.escape(Ash.Resource.Info.multitenancy_parse_attribute(dsl_state)))
            )
          end
        end

        if unquote(postgres?) do
          table = unquote(table)
          repo = unquote(repo)
          reference_source? = unquote(reference_source?)
          belongs_to_actors = unquote(Macro.escape(belongs_to_actors))

          Code.eval_quoted(
            quote do
              postgres do
                table(unquote(table) <> "_versions")
                repo(unquote(repo))

                references do
                  unless unquote(reference_source?) do
                    reference(:version_source, ignore?: true)
                  end

                  for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
                    unless actor_relationship.define_attribute? do
                      reference(actor_relationship.name, on_delete: :nothing, on_update: :update)
                    end
                  end
                end
              end
            end,
            [],
            __ENV__
          )
        end

        if unquote(ets?) do
          private? = unquote(private?)

          Code.eval_quoted(
            quote do
              ets do
                private?(unquote(private?))
              end
            end,
            [],
            __ENV__
          )
        end

        attributes do
          uuid_primary_key(:id)

          attribute :version_action_type, :atom do
            constraints(one_of: [:create, :update, :destroy])
            allow_nil?(false)
            public? true
          end

          if unquote(store_action_name?) do
            attribute :version_action_name, :atom do
              allow_nil?(false)
              public? true
            end
          end

          for attr <- unquote(Macro.escape(attributes)) do
            attribute attr.name, attr.type do
              allow_nil?(attr.allow_nil?)
              generated?(attr.generated?)
              primary_key?(attr.primary_key?)
              public?(attr.public?)
              writable?(true)
              default(attr.default)
              description(attr.description || "")
              sensitive?(attr.sensitive?)
              constraints(attr.constraints)
              always_select?(attr.always_select?)
            end
          end

          attribute :version_source_id, unquote(Macro.escape(destination_attribute.type)) do
            constraints unquote(Macro.escape(destination_attribute.constraints))
            public? true
            allow_nil? false
          end

          attribute :changes, :map do
            public? true
            sensitive? unquote(sensitive_changes?)
          end

          create_timestamp :version_inserted_at
          update_timestamp :version_updated_at
        end

        actions do
          defaults([
            :read,
            create: unquote(accept),
            update: unquote(accept)
          ])
        end

        relationships do
          belongs_to :version_source, unquote(module) do
            public? true
            destination_attribute(unquote(destination_attribute.name))
            allow_nil?(false)
            attribute_writable?(true)
            source_attribute(:version_source_id)
          end

          for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
            belongs_to actor_relationship.name, actor_relationship.destination do
              domain(actor_relationship.domain)
              define_attribute?(actor_relationship.define_attribute?)
              allow_nil?(actor_relationship.allow_nil?)
              attribute_type(actor_relationship.attribute_type)
              public?(actor_relationship.public?)
              attribute_writable?(true)
            end
          end
        end

        unquote(mixin)
      end,
      Macro.Env.location(__ENV__)
    )

    {:ok, dsl_state}
  end

  def after?(_), do: true
end
