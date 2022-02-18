module GenieDevTools

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise

const defaultroute = "/_devtools_"

function register_routes(defaultroute = defaultroute)
  route("$defaultroute/errors") do
    Revise.queue_errors |> json
  end

  route("$defaultroute/fs") do
    walkdir(pwd()) |> collect |> json
  end

  routes("$defaultroute/exec/:command", method = [GET, POST]) do
    Core.eval(Main, Meta.parse(params(:command))) |> html
  end

  route("$defaultroute/id") do
    (id => Main.UserApp) |> json
  end

  nothing
end

end
