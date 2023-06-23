defmodule Apical.Plugs.Cookie do
  alias Apical.Parser.Query
  alias Apical.Plugs.Parameter
  alias Apical.Exceptions.ParameterError

  @behaviour Parameter
  @behaviour Plug

  @impl Plug
  def init(opts) do
    Parameter.init([__MODULE__ | opts])
  end

  @impl Plug
  def call(conn, operations = %{parser_context: parser_context}) do
    cookie_params =
      with {_, value} <- List.keyfind(conn.req_headers, "cookie", 0) do
        case Query.parse(value, parser_context) do
          {:ok, result} ->
            result

          {:ok, result, _} ->
            result

          {:error, :odd_object, key, value} ->
            raise ParameterError,
              operation_id: conn.private.operation_id,
              in: :cookie,
              reason:
                "form object parameter `#{value}` for parameter `#{key}` has an odd number of entries"

          {:error, :custom, key, payload} ->
            style_name =
              parser_context
              |> Map.fetch!(key)
              |> Map.fetch!(:style_name)

            raise ParameterError,
                  ParameterError.custom_fields_from(
                    conn.private.operation_id,
                    :cookie,
                    style_name,
                    key,
                    payload
                  )
        end
      else
        nil -> %{}
      end

    # TODO: make this recursive
    operations
    |> Map.get(:required, [])
    |> Enum.each(fn
      required_cookie when is_map_key(cookie_params, required_cookie) ->
        :ok

      missing_cookie ->
        raise ParameterError,
          operation_id: conn.private.operation_id,
          in: :cookie,
          reason: "required cookie `#{missing_cookie}` not present"
    end)

    conn
    |> Map.update!(:params, &Map.merge(&1, cookie_params))
    |> Parameter.warn_deprecated(cookie_params, :cookie, operations)
    |> Parameter.validate(cookie_params, :cookie, operations)
  end

  @impl Apical.Plugs.Parameter
  def name, do: :cookie

  @impl Apical.Plugs.Parameter
  def default_style, do: "form"

  @impl Apical.Plugs.Parameter
  def style_allowed?(style), do: style === "form"
end
