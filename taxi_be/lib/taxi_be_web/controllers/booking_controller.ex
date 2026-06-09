defmodule TaxiBeWeb.BookingController do
  use TaxiBeWeb, :controller

  alias TaxiBeWeb.TaxiAllocationJob

  def create(conn, req) do
    booking_id = UUID.uuid1()
    process_name = String.to_atom(booking_id)

    TaxiAllocationJob.start_link(
      Map.put(req, "booking_id", booking_id),
      process_name
    )

    conn
    |> put_resp_header("location", "/api/bookings/" <> booking_id)
    |> put_status(:created)
    |> json(%{
      msg: "Estamos buscando un conductor para tu viaje.",
      booking_id: booking_id
    })
  end

  def update(conn, %{"action" => "accept", "username" => username, "id" => id}) do
    GenServer.cast(String.to_atom(id), {:process_accept, username})

    json(conn, %{msg: "Aceptación recibida"})
  end

  def update(conn, %{"action" => "reject", "username" => username, "id" => id}) do
    GenServer.cast(String.to_atom(id), {:process_reject, username})

    json(conn, %{msg: "Rechazo recibido"})
  end

  def update(conn, %{"action" => "cancel", "username" => username, "id" => id}) do
    GenServer.cast(String.to_atom(id), {:process_cancel, username})

    json(conn, %{msg: "Cancelación recibida"})
  end
end
