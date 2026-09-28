# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.CreateVersionResource do
  @moduledoc "Creates a version resource for a given resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  # sobelow_skip ["DOS.StringToAtom", "RCE.CodeModule"]
  def transform(dsl_state) do
    cond do
      not AshPaperTrail.Resource.Info.version_resource?(dsl_state) ->
        {:ok, dsl_state}

      AshPaperTrail.Resource.Info.temporal_inline?(dsl_state) ->
        create_inline_version_resource(dsl_state)

      true ->
        create_version_resource(dsl_state)
    end
  end

  # In `:temporal_inline` mode every period row is a version, so the version resource is a
  # read-only, non-temporal view over the resource's own table. Its primary key is the
  # resource's primary key plus the period, which is what makes each version a distinct
  # record. Not being temporal, reading it is not narrowed to a point in time.
  defp create_inline_version_resource(dsl_state) do
    version_module = AshPaperTrail.Resource.Info.version_resource(dsl_state)
    module = Transformer.get_persisted(dsl_state, :module)
    belongs_to_actors = AshPaperTrail.Resource.Info.belongs_to_actor(dsl_state)
    version_extensions = AshPaperTrail.Resource.Info.version_extensions(dsl_state)
    primary_key = Ash.Resource.Info.primary_key(dsl_state)
    period = Ash.Resource.Info.temporal_attribute(dsl_state)
    key_attributes = primary_key ++ [period]

    attributes =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.map(fn attribute ->
        attribute
        |> Map.take([
          :name,
          :type,
          :constraints,
          :allow_nil?,
          :public?,
          :sensitive?,
          :description,
          :always_select?
        ])
        |> Map.update!(:constraints, &mirror_constraints(attribute.type, &1))
      end)

    actor_relationships =
      Enum.map(belongs_to_actors, fn actor ->
        %{
          name: actor.name,
          destination: actor.destination,
          domain: actor.domain,
          public?: actor.public?,
          allow_nil?: actor.allow_nil?,
          source_attribute: AshPaperTrail.Resource.Info.actor_source_attribute(dsl_state, actor),
          temporal_period: actor.temporal_period
        }
      end)

    data_layer = version_extensions[:data_layer] || Ash.DataLayer.data_layer(dsl_state)

    data_layer_section =
      case data_layer do
        AshPostgres.DataLayer ->
          quote do
            postgres do
              table(unquote(apply(AshPostgres, :table, [dsl_state])))
              repo(unquote(apply(AshPostgres, :repo, [dsl_state])))
              migrate?(false)
            end
          end

        AshSqlite.DataLayer ->
          quote do
            sqlite do
              table(unquote(apply(AshSqlite.DataLayer.Info, :table, [dsl_state])))
              repo(unquote(apply(AshSqlite.DataLayer.Info, :repo, [dsl_state])))
              migrate?(false)
            end
          end

        Ash.DataLayer.Ets ->
          quote do
            ets do
              private?(unquote(Ash.DataLayer.Ets.Info.private?(dsl_state)))
              table(unquote(Spark.Dsl.Extension.get_opt(dsl_state, [:ets], :table) || module))
            end
          end

        _ ->
          quote do
          end
      end

    multitenancy =
      if Ash.Resource.Info.multitenancy_strategy(dsl_state) do
        quote do
          multitenancy do
            strategy(unquote(Ash.Resource.Info.multitenancy_strategy(dsl_state)))
            attribute(unquote(Ash.Resource.Info.multitenancy_attribute(dsl_state)))
            global?(unquote(Ash.Resource.Info.multitenancy_global?(dsl_state)))

            parse_attribute(
              unquote(Macro.escape(Ash.Resource.Info.multitenancy_parse_attribute(dsl_state)))
            )
          end
        end
      else
        quote do
        end
      end

    version_source =
      case primary_key do
        [key] ->
          quote do
            belongs_to :version_source, unquote(module) do
              public? true
              allow_nil? false
              define_attribute? false
              source_attribute(unquote(key))
              destination_attribute(unquote(key))
              temporal_keys({nil, unquote(period)})
            end
          end

        _ ->
          quote do
            has_one :version_source, unquote(module) do
              public? true
              allow_nil? false
              no_attributes? true
              temporal_keys({nil, unquote(period)})

              filter unquote(
                       Macro.escape(AshPaperTrail.Resource.PrimaryKey.same_key_filter(dsl_state))
                     )
            end
          end
      end

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
        def version_source_resource, do: unquote(module)

        unquote(data_layer_section)
        unquote(multitenancy)

        attributes do
          for attr <- unquote(Macro.escape(attributes)) do
            attribute attr.name, attr.type do
              primary_key?(attr.name in unquote(key_attributes))
              allow_nil?(attr.allow_nil? and attr.name not in unquote(key_attributes))
              writable?(false)
              public?(attr.public?)
              sensitive?(attr.sensitive?)
              constraints(attr.constraints)
              always_select?(attr.always_select?)
              description(attr.description || "")
            end
          end
        end

        actions do
          defaults([:read])
        end

        relationships do
          unquote(version_source)

          for actor <- unquote(Macro.escape(actor_relationships)) do
            belongs_to actor.name, actor.destination do
              domain(actor.domain)
              public?(actor.public?)
              allow_nil?(actor.allow_nil?)
              define_attribute?(false)
              source_attribute(actor.source_attribute)

              if actor.temporal_period do
                temporal_keys({nil, actor.temporal_period})
              end
            end
          end
        end

        unquote(mixin)
      end,
      Macro.Env.location(__ENV__)
    )

    {:ok, dsl_state}
  end

  defp create_version_resource(dsl_state) do
    version_module = AshPaperTrail.Resource.Info.version_resource(dsl_state)
    module = Transformer.get_persisted(dsl_state, :module)

    primary_key_type = AshPaperTrail.Resource.Info.primary_key_type(dsl_state)
    ignore_attributes = AshPaperTrail.Resource.Info.ignore_attributes(dsl_state)
    attributes_as_attributes = AshPaperTrail.Resource.Info.attributes_as_attributes(dsl_state)
    belongs_to_actors = AshPaperTrail.Resource.Info.belongs_to_actor(dsl_state)
    metadata_entities = AshPaperTrail.Resource.Info.metadata(dsl_state)
    reference_source? = AshPaperTrail.Resource.Info.reference_source?(dsl_state)
    store_action_name? = AshPaperTrail.Resource.Info.store_action_name?(dsl_state)
    store_action_inputs? = AshPaperTrail.Resource.Info.store_action_inputs?(dsl_state)
    store_resource_identifier? = AshPaperTrail.Resource.Info.store_resource_identifier?(dsl_state)
    operation_id_field = AshPaperTrail.Resource.Info.operation_id_field(dsl_state)
    version_extensions = AshPaperTrail.Resource.Info.version_extensions(dsl_state)

    public_timestamps? =
      AshPaperTrail.Resource.Info.public_timestamps?(dsl_state)

    resource_identifier =
      if store_resource_identifier? do
        AshPaperTrail.Resource.Info.resource_identifier(dsl_state) ||
          Ash.Resource.Info.short_name(dsl_state)
      end

    dsl_state =
      if resource_identifier do
        Transformer.set_option(
          dsl_state,
          [:paper_trail],
          :resource_identifier,
          resource_identifier
        )
      else
        dsl_state
      end

    attributes =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(&(&1.name in attributes_as_attributes))

    sensitive_changes? =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.reject(&(&1.name in ignore_attributes or &1.name in attributes_as_attributes))
      |> Enum.any?(& &1.sensitive?)

    data_layer = version_extensions[:data_layer] || Ash.DataLayer.data_layer(dsl_state)

    {postgres?, sqlite?, parent_table, repo} =
      cond do
        data_layer == AshPostgres.DataLayer ->
          {true, false, apply(AshPostgres, :table, [dsl_state]),
           apply(AshPostgres, :repo, [dsl_state])}

        data_layer == AshSqlite.DataLayer ->
          {false, true, apply(AshSqlite.DataLayer.Info, :table, [dsl_state]),
           apply(AshSqlite.DataLayer.Info, :repo, [dsl_state])}

        true ->
          {false, false, nil, nil}
      end

    table =
      case {Transformer.get_option(dsl_state, [:paper_trail], :table_name), parent_table} do
        {table, _} when is_binary(table) -> table
        {_, table} when is_binary(table) -> "#{table}_versions"
        _ -> nil
      end

    {ets?, private?} =
      if data_layer == Ash.DataLayer.Ets do
        {true, Ash.DataLayer.Ets.Info.private?(dsl_state)}
      else
        {false, nil}
      end

    multitenant? = not is_nil(Ash.Resource.Info.multitenancy_strategy(dsl_state))

    version_source_mappings = AshPaperTrail.Resource.PrimaryKey.mappings(dsl_state)
    composite_primary_key? = AshPaperTrail.Resource.PrimaryKey.composite?(dsl_state)

    version_source_filter =
      AshPaperTrail.Resource.PrimaryKey.version_source_filter(dsl_state)

    accept =
      [
        :version_action_type,
        if(store_action_name?, do: :version_action_name, else: nil),
        if(store_action_inputs?, do: :version_action_inputs, else: nil),
        if(store_resource_identifier?, do: :version_resource_identifier, else: nil),
        operation_id_field,
        attributes |> Enum.map(& &1.name),
        AshPaperTrail.Resource.PrimaryKey.version_source_attribute_names(dsl_state),
        :changes,
        belongs_to_actors |> Enum.map(&String.to_atom("#{&1.name}_id")),
        metadata_entities |> Enum.map(& &1.name)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> then(fn accept ->
        case multitenant? do
          true ->
            multitenancy_attribute = Ash.Resource.Info.multitenancy_attribute(dsl_state)
            accept |> Enum.reject(&(&1 == multitenancy_attribute))

          false ->
            accept
        end
      end)

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
        def version_source_resource, do: unquote(module)

        if unquote(multitenant?) do
          multitenancy do
            strategy(unquote(Ash.Resource.Info.multitenancy_strategy(dsl_state)))
            attribute(unquote(Ash.Resource.Info.multitenancy_attribute(dsl_state)))
            global?(unquote(Ash.Resource.Info.multitenancy_global?(dsl_state)))

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
                table(unquote(table))
                repo(unquote(repo))

                references do
                  if !unquote(reference_source?) do
                    reference(:version_source, ignore?: true)
                  end

                  for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
                    if actor_relationship.define_attribute? do
                      reference(actor_relationship.name,
                        on_delete: actor_relationship.on_delete,
                        on_update: :update
                      )
                    end
                  end
                end
              end
            end,
            [],
            __ENV__
          )
        end

        if unquote(sqlite?) do
          table = unquote(table)
          repo = unquote(repo)
          reference_source? = unquote(reference_source?)
          belongs_to_actors = unquote(Macro.escape(belongs_to_actors))

          Code.eval_quoted(
            quote do
              sqlite do
                table(unquote(table))
                repo(unquote(repo))

                references do
                  if !unquote(reference_source?) do
                    reference(:version_source, ignore?: true)
                  end

                  for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
                    if actor_relationship.define_attribute? do
                      reference(actor_relationship.name,
                        on_delete: actor_relationship.on_delete,
                        on_update: :update
                      )
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
          case unquote(primary_key_type) do
            :uuid -> uuid_primary_key :id
            :uuid_v7 -> uuid_v7_primary_key :id
            :integer -> integer_primary_key :id
          end

          attribute :version_action_type, :atom do
            constraints(one_of: [:create, :update, :destroy])
            allow_nil?(false)
            public? true
          end

          if unquote(store_action_name?) do
            attribute :version_action_name, :atom do
              constraints unsafe_to_atom?: true
              allow_nil?(false)
              public? true
            end
          end

          if unquote(store_action_inputs?) do
            attribute :version_action_inputs, :map do
              allow_nil?(false)
              public? true
            end
          end

          if unquote(store_resource_identifier?) do
            attribute :version_resource_identifier, :atom do
              allow_nil? false
              public? true
            end
          end

          if unquote(operation_id_field) do
            attribute unquote(operation_id_field), :uuid do
              public? true
            end
          end

          for meta <- unquote(Macro.escape(metadata_entities)) do
            attribute meta.name, meta.type do
              constraints(meta.constraints)
              allow_nil?(meta.allow_nil?)
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

          for {_source_key, version_attr, source_attr} <-
                unquote(Macro.escape(version_source_mappings)) do
            attribute version_attr, source_attr.type do
              constraints(source_attr.constraints)
              public? true
              allow_nil? false
            end
          end

          attribute :changes, :map do
            public? true
            sensitive? unquote(sensitive_changes?)
          end

          create_timestamp :version_inserted_at, public?: unquote(public_timestamps?)
          update_timestamp :version_updated_at, public?: unquote(public_timestamps?)
        end

        actions do
          defaults([
            :read,
            create: unquote(accept),
            update: unquote(accept)
          ])
        end

        relationships do
          if unquote(composite_primary_key?) do
            has_one :version_source, unquote(module) do
              public? true
              allow_nil?(false)
              no_attributes?(true)
              filter unquote(Macro.escape(version_source_filter))
            end
          else
            {_source_key, version_attr, source_attr} =
              unquote(Macro.escape(List.first(version_source_mappings)))

            belongs_to :version_source, unquote(module) do
              public? true
              destination_attribute(source_attr.name)
              allow_nil?(false)
              attribute_writable?(true)
              source_attribute(version_attr)
            end
          end

          for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
            belongs_to actor_relationship.name, actor_relationship.destination do
              domain(actor_relationship.domain)
              define_attribute?(actor_relationship.define_attribute?)
              allow_nil?(actor_relationship.allow_nil?)
              attribute_type(actor_relationship.attribute_type)
              public?(actor_relationship.public?)
              attribute_writable?(true)

              if actor_relationship.temporal_period do
                temporal_keys({nil, actor_relationship.temporal_period})
              end
            end
          end
        end

        if unquote(store_resource_identifier?) do
          resource do
            base_filter version_resource_identifier: unquote(resource_identifier)
          end
        end

        unquote(mixin)
      end,
      Macro.Env.location(__ENV__)
    )

    {:ok, dsl_state}
  end

  # A range's `inner_type` constraint is resolved to a type module on init, but its schema
  # only accepts the short names, so map it back before redeclaring the attribute.
  defp mirror_constraints(Ash.Type.Range, constraints) do
    Keyword.update(constraints, :inner_type, nil, fn type ->
      Enum.find(
        [:date, :integer, :naive_datetime, :datetime],
        type,
        &(Ash.Type.get_type(&1) == type)
      )
    end)
  end

  defp mirror_constraints(_type, constraints), do: constraints

  def after?(_), do: true
end
