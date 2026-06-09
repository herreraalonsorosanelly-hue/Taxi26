defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  alias TaxiBeWeb.Endpoint

  @timeout 60_000

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :contact_next_taxi, [])

    {:ok,
     %{
       request: request,
       taxis: candidate_taxis(),
       current_taxi: nil,
       timer: nil,
       finished: false
     }}
  end

  def handle_info(:contact_next_taxi, %{taxis: []} = state) do
    username = state.request["username"]

    Endpoint.broadcast(
      "customer:#{username}",
      "booking_request",
      %{msg: "No hay taxis disponibles por el momento."}
    )

    {:stop, :normal, %{state | finished: true}}
  end

  def handle_info(:contact_next_taxi, %{taxis: [taxi | remaining_taxis]} = state) do
    request = state.request

    IO.puts("Mandando solicitud a driver:#{taxi.nickname}")

    Endpoint.broadcast(
      "driver:#{taxi.nickname}",
      "booking_request",
      %{
        "msg" => "Viaje de '#{request["pickup_address"]}' a '#{request["dropoff_address"]}'",
        "bookingId" => request["booking_id"]
      }
    )

    timer = Process.send_after(self(), :timeout, @timeout)

    {:noreply,
     %{
       state
       | taxis: remaining_taxis,
         current_taxi: taxi,
         timer: timer
     }}
  end

  def handle_info(:timeout, state) do
    Process.send(self(), :contact_next_taxi, [])
    {:noreply, %{state | current_taxi: nil, timer: nil}}
  end

  def handle_cast({:process_accept, username}, state) do
    if state.current_taxi != nil and state.current_taxi.nickname == username do
      cancel_timer(state.timer)

      customer = state.request["username"]

      Endpoint.broadcast(
        "customer:#{customer}",
        "booking_request",
        %{msg: "Tu taxi está en camino. Conductor asignado: #{username}"}
      )

      {:stop, :normal, %{state | finished: true}}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:process_reject, username}, state) do
    if state.current_taxi != nil and state.current_taxi.nickname == username do
      cancel_timer(state.timer)
      Process.send(self(), :contact_next_taxi, [])

      {:noreply, %{state | current_taxi: nil, timer: nil}}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:process_cancel, _username}, state) do
    cancel_timer(state.timer)

    if state.current_taxi != nil do
      Endpoint.broadcast(
        "driver:#{state.current_taxi.nickname}",
        "booking_cancelled",
        %{msg: "El cliente canceló la solicitud."}
      )
    end

    {:stop, :normal, %{state | finished: true}}
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer) do
    Process.cancel_timer(timer)
    :ok
  end

  defp candidate_taxis do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368},
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737},
      %{nickname: "pippin", latitude: 19.0092933, longitude: -98.2473716}
    ]
  end
end
