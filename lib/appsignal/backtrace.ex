defmodule Appsignal.Backtrace do
  @doc ~S"""
  Parses the given stacktrace into a backtrace list.
  """
  def from_stacktrace(stacktrace) do
    stacktrace
    |> remove_error_entries
    |> format_stacktrace
  end

  defp remove_error_entries([]), do: []
  defp remove_error_entries([{_, _, arity, _}|tail]) when is_list(arity) do
    remove_error_entries(tail)
  end
  defp remove_error_entries([entry|tail]) do
    [entry|remove_error_entries(tail)]
  end

  defp format_stacktrace(stacktrace) do
    Enum.map(stacktrace, &format_stacktrace_entry/1)
  end

  defp format_stacktrace_entry(entry) when is_binary(entry), do: entry
  defp format_stacktrace_entry(entry) do
    Exception.format_stacktrace_entry(entry)
  end
end
