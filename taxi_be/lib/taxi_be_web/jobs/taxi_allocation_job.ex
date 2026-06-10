defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  alias TaxiBeWeb.Endpoint

  @timeout 90_000

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :step1, [])

    {:ok,
     %{
       request: request,
       phase: :allocating,
       timer: nil,
       pending: [],
       contacted: [],
       accepted_driver: nil
     }}
  end

  def handle_info(:step1, state) do
    taxis =
      candidate_taxis()
      |> Enum.take(3)

    forward_ride_request(state.request, taxis)

    timer = Process.send_after(self(), :timeout, @timeout)

    nicknames = Enum.map(taxis, & &1.nickname)

    {:noreply,
     %{
       state
       | pending: nicknames,
         contacted: nicknames,
         timer: timer
     }}
  end

  def handle_info(:timeout, state) do
    notify_allocation_failed(state)
    notify_drivers_cancelled(state.contacted, nil)

    {:stop, :normal, %{state | phase: :not_allocated, timer: nil}}
  end

  def handle_cast({:process_accept, username}, state) do
    if username in state.pending do
      cancel_timer(state.timer)

      customer = state.request["username"]

      Endpoint.broadcast(
        "customer:#{customer}",
        "booking_request",
        %{
          "msg" => "Tu taxi está en camino. Conductor asignado: #{username}. Tiempo estimado de llegada: 10 minutos."
        }
      )

      notify_drivers_cancelled(state.contacted, username)

      {:stop, :normal,
       %{
         state
         | phase: :accepted,
           accepted_driver: username,
           timer: nil
       }}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:process_reject, username}, state) do
    pending = List.delete(state.pending, username)

    if pending == [] do
      cancel_timer(state.timer)
      notify_allocation_failed(state)

      {:stop, :normal, %{state | pending: [], phase: :not_allocated, timer: nil}}
    else
      {:noreply, %{state | pending: pending}}
    end
  end

  def handle_cast({:process_cancel, _username}, state) do
    cancel_timer(state.timer)

    notify_drivers_cancelled(state.contacted, nil)

    customer = state.request["username"]

    Endpoint.broadcast(
      "customer:#{customer}",
      "booking_request",
      %{
        "msg" => "Viaje cancelado sin cargo."
      }
    )

    {:stop, :normal, %{state | phase: :cancelled, timer: nil}}
  end

  defp forward_ride_request(request, taxis) do
    Enum.each(taxis, fn taxi ->
      Endpoint.broadcast(
        "driver:#{taxi.nickname}",
        "booking_request",
        %{
          "msg" => "Viaje de '#{request["pickup_address"]}' a '#{request["dropoff_address"]}'",
          "bookingId" => request["booking_id"]
        }
      )
    end)
  end

  defp notify_allocation_failed(state) do
    customer = state.request["username"]

    Endpoint.broadcast(
      "customer:#{customer}",
      "booking_request",
      %{
        "msg" => "No fue posible encontrar un taxi para tu viaje."
      }
    )
  end

  defp notify_drivers_cancelled(contacted, accepted_driver) do
    contacted
    |> Enum.reject(fn driver -> driver == accepted_driver end)
    |> Enum.each(fn driver ->
      Endpoint.broadcast(
        "driver:#{driver}",
        "booking_cancelled",
        %{
          "msg" => "La solicitud ya no está disponible."
        }
      )
    end)
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
