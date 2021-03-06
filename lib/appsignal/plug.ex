if Appsignal.plug?() do
  defmodule Appsignal.Plug do
    @moduledoc """
    Plug handler for Phoenix requests
    """

    alias Appsignal.Config

    defmacro __using__(_) do
      quote do
        @transaction Application.get_env(
                       :appsignal,
                       :appsignal_transaction,
                       Appsignal.Transaction
                     )

        def call(conn, opts) do
          transaction =
            @transaction.generate_id()
            |> @transaction.start(:http_request)
            |> Appsignal.Plug.try_set_action(conn)

          conn = Plug.Conn.put_private(conn, :appsignal_transaction, transaction)

          try do
            super(conn, opts)
          catch
            kind, reason -> Appsignal.Plug.handle_error(conn, kind, reason)
          else
            conn -> Appsignal.Plug.finish_with_conn(transaction, conn)
          end
        end
      end
    end

    @transaction Application.get_env(
                   :appsignal,
                   :appsignal_transaction,
                   Appsignal.Transaction
                 )

    def handle_error(_conn, :error, %Plug.Conn.WrapperError{} = wrapper) do
      %{conn: conn, kind: kind, reason: reason, stack: stack} = wrapper
      handle_error(conn, kind, wrapper, reason, stack)
    end

    def handle_error(conn, kind, reason) do
      handle_error(conn, kind, reason, reason, System.stacktrace())
    end

    def handle_error(
          %Plug.Conn{private: %{appsignal_transaction: transaction}} = conn,
          kind,
          reason,
          wrapped_reason,
          stack
        ) do
      exception = Exception.normalize(kind, wrapped_reason, stack)

      case Appsignal.Plug.extract_error_metadata(exception) do
        {reason, message} ->
          transaction
          |> @transaction.set_error(reason, message, stack)
          |> finish_with_conn(conn)

        nil ->
          :ok
      end

      :erlang.raise(kind, reason, stack)
    end

    def handle_error(_conn, kind, reason, _wrapped_reason, stack) do
      :erlang.raise(kind, reason, stack)
    end

    def finish_with_conn(transaction, conn) do
      if @transaction.finish(transaction) == :sample do
        @transaction.set_request_metadata(transaction, conn)
      end

      :ok = @transaction.complete(transaction)
      conn
    end

    def try_set_action(transaction, conn) do
      case Appsignal.Plug.extract_action(conn) do
        nil -> transaction
        action -> @transaction.set_action(transaction, action)
      end
    end

    @doc """
    Returns a tuple with the exception's reason and message unless the error has
    a status code under 500.
    """
    def extract_error_metadata(%{plug_status: status}) when status < 500 do
      nil
    end

    def extract_error_metadata(%Plug.Conn.WrapperError{reason: reason = %{}}) do
      Appsignal.ErrorHandler.extract_reason_and_message(reason, "HTTP request error")
    end

    def extract_error_metadata(reason) do
      Appsignal.ErrorHandler.extract_reason_and_message(reason, "HTTP request error")
    end

    @doc false
    def extract_error_metadata(reason, conn, stack) do
      IO.warn(
        "Appsignal.Plug.extract_error_metadata/3 is deprecated. Use Appsignal.Plug.extract_error_metadata/1 instead."
      )

      {reason, message} = extract_error_metadata(reason)
      {reason, message, stack, conn}
    end

    def extract_action(%Plug.Conn{
          private: %{phoenix_action: action, phoenix_controller: controller}
        }) do
      merge_action_and_controller(action, controller)
    end

    def extract_action(%Plug.Conn{private: %{phoenix_endpoint: _}}), do: nil

    def extract_action(%Plug.Conn{method: _method, request_path: _path}) do
      "unknown"
    end

    def extract_sample_data(
          %Plug.Conn{
            params: params,
            host: host,
            method: method,
            request_path: request_path,
            port: port
          } = conn
        ) do
      %{
        "params" => Appsignal.Utils.MapFilter.filter_values(
          params,
          Appsignal.Utils.MapFilter.get_filter_parameters()
        ),
        "environment" =>
          %{
            "host" => host,
            "method" => method,
            "request_path" => request_path,
            "port" => port,
            "request_uri" => url(conn)
          }
          |> Map.merge(extract_request_headers(conn))
      }
    end

    def extract_request_headers(%Plug.Conn{req_headers: req_headers}) do
      for {key, value} <- req_headers,
          key in (Config.request_headers()) do
        {"req_headers.#{key}", value}
      end
      |> Enum.into(%{})
    end

    def extract_meta_data(%Plug.Conn{method: method, request_path: path} = conn) do
      request_id =
        conn
        |> Plug.Conn.get_resp_header("x-request-id")
        |> List.first()

      %{
        "method" => method,
        "path" => path,
        "request_id" => request_id
      }
    end

    defp merge_action_and_controller(action, controller) when is_atom(controller) do
      merge_action_and_controller(
        action,
        controller |> Atom.to_string() |> String.trim_leading("Elixir.")
      )
    end

    defp merge_action_and_controller(action, controller) do
      "#{controller}##{action}"
    end

    defp url(%Plug.Conn{scheme: scheme, host: host, port: port, request_path: request_path}) do
      "#{scheme}://#{host}:#{port}#{request_path}"
    end
  end
end
