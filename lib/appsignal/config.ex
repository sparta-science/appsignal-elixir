defmodule Appsignal.Config do
  alias Appsignal.Nif

  @default_config %{
    active: false,
    debug: false,
    dns_servers: [],
    enable_host_metrics: true,
    endpoint: "https://push.appsignal.com",
    diagnose_endpoint: "https://appsignal.com/diag",
    env: :dev,
    filter_parameters: [],
    filter_session_data: [],
    ignore_actions: [],
    ignore_errors: [],
    ignore_namespaces: [],
    send_params: true,
    skip_session_data: false,
    files_world_accessible: true,
    log: "file",
    ca_file_path: Path.join(:code.priv_dir(:appsignal), "cacert.pem"),
    request_headers: ~w(
      accept accept-charset accept-encoding accept-language cache-control
      connection content-length path-info range request-method request-uri
      server-name server-port server-protocol
    )
  }

  @doc """
  Initializes the AppSignal config. Looks at the config default, the
  Elixir-provided configuration and the various `APPSIGNAL_*`
  OS environment variables. Returns whether or not the configuration is valid.
  """
  @spec initialize() :: :ok | {:error, :invalid_config}
  def initialize() do
    system_config = load_from_system()
    app_config = Application.get_env(:appsignal, :config, []) |> coerce_map
    env_config = load_from_environment()

    config =
      @default_config
      |> Map.merge(system_config)
      |> Map.merge(app_config)
      |> Map.merge(env_config)


    # Config is valid when we have a push api key
    config =
      config
      |> Map.put(:valid, !empty?(config[:push_api_key]))

    Application.put_env(:appsignal, :config, config)

    case config[:valid] do
      true ->
        :ok

      false ->
        {:error, :invalid_config}
    end
  end

  @doc """
  Returns whether the AppSignal agent is configured to start on application
  launch.
  """
  @spec configured_as_active?() :: boolean
  def configured_as_active? do
    Application.fetch_env!(:appsignal, :config).active
  end

  @doc """
  Returns true if the configuration is valid and the AppSignal agent is
  configured to start on application launch.
  """
  @spec active?() :: boolean
  def active? do
    config = Application.fetch_env!(:appsignal, :config)
    config.valid && config.active
  end

  def request_headers do
    Application.fetch_env!(:appsignal, :config)[:request_headers]
  end

  def ca_file_path do
    Application.fetch_env!(:appsignal, :config)[:ca_file_path]
  end

  @env_to_key_mapping %{
    "APPSIGNAL_ACTIVE" => :active,
    "APPSIGNAL_PUSH_API_KEY" => :push_api_key,
    "APPSIGNAL_APP_NAME" => :name,
    "APPSIGNAL_APP_ENV" => :env,
    "APPSIGNAL_CA_FILE_PATH" => :ca_file_path,
    "APPSIGNAL_PUSH_API_ENDPOINT" => :endpoint,
    "APPSIGNAL_FRONTEND_ERROR_CATCHING_PATH" => :frontend_error_catching_path,
    "APPSIGNAL_HOSTNAME" => :hostname,
    "APPSIGNAL_FILTER_PARAMETERS" => :filter_parameters,
    "APPSIGNAL_FILTER_SESSION_DATA" => :filter_session_data,
    "APPSIGNAL_DEBUG" => :debug,
    "APPSIGNAL_DNS_SERVERS" => :dns_servers,
    "APPSIGNAL_LOG" => :log,
    "APPSIGNAL_LOG_PATH" => :log_path,
    "APPSIGNAL_IGNORE_ACTIONS" => :ignore_actions,
    "APPSIGNAL_IGNORE_ERRORS" => :ignore_errors,
    "APPSIGNAL_IGNORE_NAMESPACES" => :ignore_namespaces,
    "APPSIGNAL_HTTP_PROXY" => :http_proxy,
    "APPSIGNAL_RUNNING_IN_CONTAINER" => :running_in_container,
    "APPSIGNAL_WORKING_DIR_PATH" => :working_dir_path,
    "APPSIGNAL_ENABLE_HOST_METRICS" => :enable_host_metrics,
    "APPSIGNAL_SKIP_SESSION_DATA" => :skip_session_data,
    "APPSIGNAL_FILES_WORLD_ACCESSIBLE" => :files_world_accessible,
    "APPSIGNAL_REQUEST_HEADERS" => :request_headers,
    "APP_REVISION" => :revision
  }

  @string_keys ~w(APPSIGNAL_APP_NAME APPSIGNAL_PUSH_API_KEY APPSIGNAL_PUSH_API_ENDPOINT APPSIGNAL_FRONTEND_ERROR_CATCHING_PATH APPSIGNAL_HOSTNAME APPSIGNAL_HTTP_PROXY APPSIGNAL_LOG APPSIGNAL_LOG_PATH APPSIGNAL_WORKING_DIR_PATH APPSIGNAL_CA_FILE_PATH APP_REVISION)
  @bool_keys ~w(APPSIGNAL_ACTIVE APPSIGNAL_DEBUG APPSIGNAL_INSTRUMENT_NET_HTTP APPSIGNAL_ENABLE_FRONTEND_ERROR_CATCHING APPSIGNAL_ENABLE_ALLOCATION_TRACKING APPSIGNAL_ENABLE_GC_INSTRUMENTATION APPSIGNAL_RUNNING_IN_CONTAINER APPSIGNAL_ENABLE_HOST_METRICS APPSIGNAL_SKIP_SESSION_DATA APPSIGNAL_FILES_WORLD_ACCESSIBLE)
  @atom_keys ~w(APPSIGNAL_APP_ENV)
  @string_list_keys ~w(APPSIGNAL_FILTER_PARAMETERS APPSIGNAL_IGNORE_ACTIONS APPSIGNAL_IGNORE_ERRORS APPSIGNAL_IGNORE_NAMESPACES APPSIGNAL_DNS_SERVERS APPSIGNAL_FILTER_SESSION_DATA APPSIGNAL_REQUEST_HEADERS)

  defp load_environment(config, list, converter) do
    list
    |> Enum.reduce(config, fn key, cfg ->
      value = System.get_env(key)

      if !empty?(value) do
        Map.put(cfg, @env_to_key_mapping[key], converter.(value))
      else
        cfg
      end
    end)
  end

  defp load_from_system() do
    config = %{}

    # Make AppSignal active by default if the APPSIGNAL_PUSH_API_KEY
    # environment variable is present.
    # Is overwritten by application config and env config.
    config =
      case System.get_env("APPSIGNAL_PUSH_API_KEY") do
        nil -> config
        _ -> Map.merge(config, %{active: true})
      end

    # Detect Heroku
    case Appsignal.System.heroku?() do
      false -> config
      true -> Map.merge(config, %{running_in_container: true, log: "stdout"})
    end
  end

  defp load_from_environment() do
    %{}
    |> load_environment(@string_keys, & &1)
    |> load_environment(@bool_keys, &true?(&1))
    |> load_environment(@atom_keys, &String.to_atom(&1))
    |> load_environment(@string_list_keys, &String.split(&1, ","))
  end

  defp coerce_map(value) when is_list(value) do
    value |> Enum.into(%{})
  end

  defp coerce_map(%{} = value) do
    value
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?([]), do: true
  defp empty?(_), do: false

  defp true?("true"), do: true
  defp true?(true), do: true
  defp true?(_), do: false

  @language_integration_version Mix.Project.config()[:version]

  @doc """
  Write the currently known AppSignal configuration to the system environment.
  Must be run before starting the AppSignal agent otherwise it won't know the
  correct configuration.

  ## Example

      case {Appsignal.Config.initialize, Appsignal.Config.active?} do
        {:ok, true} ->
          Appsignal.Config.write_to_environment
          Appsignal.Nif.start
        {:ok, false} ->
          # AppSignal not active
        {{:error, :invalid_config}, _} ->
          # AppSignal has invalid config
      end
  """
  def write_to_environment do
    config = Application.get_env(:appsignal, :config)
    write_to_environment(config)
  end

  defp write_to_environment(config) do
    reset_environment_config!()

    Nif.env_put("_APPSIGNAL_ACTIVE", to_string(config[:active]))
    Nif.env_put("_APPSIGNAL_AGENT_PATH", List.to_string(:code.priv_dir(:appsignal)))
    # FIXME - app_path should not be necessary
    Nif.env_put("_APPSIGNAL_APP_PATH", List.to_string(:code.priv_dir(:appsignal)))
    Nif.env_put("_APPSIGNAL_APP_NAME", to_string(config[:name]))
    Nif.env_put("_APPSIGNAL_CA_FILE_PATH", to_string(config[:ca_file_path]))
    Nif.env_put("_APPSIGNAL_DEBUG_LOGGING", to_string(config[:debug]))
    Nif.env_put("_APPSIGNAL_DNS_SERVERS", config[:dns_servers] |> Enum.join(","))
    Nif.env_put("_APPSIGNAL_ENABLE_HOST_METRICS", to_string(config[:enable_host_metrics]))
    Nif.env_put("_APPSIGNAL_ENVIRONMENT", to_string(config[:env]))
    Nif.env_put("_APPSIGNAL_HOSTNAME", to_string(config[:hostname]))
    Nif.env_put("_APPSIGNAL_HTTP_PROXY", to_string(config[:http_proxy]))
    Nif.env_put("_APPSIGNAL_IGNORE_ACTIONS", config[:ignore_actions] |> Enum.join(","))
    Nif.env_put("_APPSIGNAL_IGNORE_ERRORS", config[:ignore_errors] |> Enum.join(","))
    Nif.env_put("_APPSIGNAL_IGNORE_NAMESPACES", config[:ignore_namespaces] |> Enum.join(","))

    Nif.env_put(
      "_APPSIGNAL_LANGUAGE_INTEGRATION_VERSION",
      "elixir-" <> @language_integration_version
    )

    Nif.env_put("_APPSIGNAL_LOG", config[:log])
    Nif.env_put("_APPSIGNAL_LOG_FILE_PATH", to_string(config[:log_path]))
    Nif.env_put("_APPSIGNAL_PUSH_API_ENDPOINT", config[:endpoint] || "")
    Nif.env_put("_APPSIGNAL_PUSH_API_KEY", config[:push_api_key] || "")
    Nif.env_put("_APPSIGNAL_RUNNING_IN_CONTAINER", to_string(config[:running_in_container]))
    Nif.env_put("_APPSIGNAL_SEND_PARAMS", to_string(config[:send_params]))
    Nif.env_put("_APPSIGNAL_WORKING_DIR_PATH", to_string(config[:working_dir_path]))

    Nif.env_put(
      "_APPSIGNAL_FILES_WORLD_ACCESSIBLE",
      to_string(config[:files_world_accessible])
    )

    Nif.env_put("_APP_REVISION", to_string(config[:revision]))
  end

  @doc """
  Reset the config written to the environment by `write_to_environment/1`.
  This makes sure no existing config gets reused and the configuration for the
  agent gets set again.
  """
  def reset_environment_config! do
    Nif.env_clear()
  end

  def get_system_env do
    System.get_env()
    |> Enum.filter(fn
      {"APPSIGNAL_" <> _, _} -> true
      _ -> false
    end)
    |> Enum.into(%{})
  end

  # When you use Appsignal.Config you get a handy config macro which
  # can be used to read the application config.
  defmacro __using__(_) do
    quote do
      defmacro config do
        quote do
          Application.get_env(:appsignal, :config, [])
        end
      end
    end
  end
end
