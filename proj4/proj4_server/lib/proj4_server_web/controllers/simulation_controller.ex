defmodule Proj4ServerWeb.SimulationController do
    use Proj4ServerWeb, :controller
    
    def index(conn, _params) do
        render(conn, "index.html")
    end
end