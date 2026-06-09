defmodule TaxiBeWeb.CustomerChannel do
  use TaxiBeWeb, :channel

  intercept ["booking_request"]

  def join("customer:" <> username, _payload, socket) do
    IO.puts("JOINED customer:#{username}")
    {:ok, socket}
  end

  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end
end
