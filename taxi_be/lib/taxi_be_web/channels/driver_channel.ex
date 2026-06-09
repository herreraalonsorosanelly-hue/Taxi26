defmodule TaxiBeWeb.DriverChannel do
  use TaxiBeWeb, :channel

  intercept ["booking_request", "booking_cancelled"]

  def join("driver:" <> username, _payload, socket) do
    IO.puts("JOINED driver:#{username}")
    {:ok, socket}
  end

  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end
end
