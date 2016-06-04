defmodule Metex.Worker do
  use GenServer

  @appid Application.get_env(:metex, :weather_api_key)
  @process_name Metex.Worker

  #Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: @process_name])
  end

  def get_temperature(location) do
    GenServer.call(@process_name, {:location, location})
  end

  def get_stats do
    GenServer.call(@process_name, :get_stats)
  end

  def reset_stats do
    GenServer.cast(@process_name, :reset_stats)
  end

  def stop do
    GenServer.cast(@process_name, :stop)
  end

  #Server Callbacks
  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast(:stop, stats) do
    {:stop, :normal, stats}
  end

  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, temp} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{temp} ºC", new_stats}

      _ ->
         {:reply, :error, stats}
    end
  end

  def handle_info(msg, stats) do
    IO.puts "Received #{inspect msg}"
    {:noreply, stats}
  end

  def terminate(reason, stats) do
    IO.puts "Server terminated because of #{inspect reason}"
    IO.puts "Stats: #{inspect stats}"
    :ok
  end

  # Helper functions
  defp update_stats(current_stats, location) do
    case Map.has_key?(current_stats, location) do
      true -> Map.update!(current_stats, location, &(&1 + 1))
      false -> Map.put_new(current_stats, location, 1)
    end
  end

  defp temperature_of(location) do
    url_for(location)
    |> HTTPoison.get
    |> parse_response
  end

  defp url_for(location), do: "http://api.openweathermap.org/data/2.5/weather?q=#{location}&APPID=#{@appid}"

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body
    |> compute_temperature
  end

  defp compute_temperature(json) do
    try do
      response = Poison.Parser.parse!(json)
      temp = (response["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok, temp}
    rescue
      _ -> :error
    end
  end

end

