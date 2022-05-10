module GenieDevTools

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates
using RemoteREPL

import Stipple, Stipple.Pages

const defaultroute = "/_devtools_"
const _HOOKS = Function[]

include("route_helpers.jl")
import .RouteHelpers as RH

function hook!(f::Function)
  push!(_HOOKS, f)
end

function runhooks()
  for f in _HOOKS
    Base.invokelatest(f)
  end
end

function register_routes(defaultroute = defaultroute) :: Nothing
  RH.errors(defaultroute)
  RH.dir(defaultroute)
  RH.edit(defaultroute)
  RH.save(defaultroute)
  RH.exec(defaultroute)
  RH.id(defaultroute)
  RH.log(defaultroute)
  RH.exit(defaultroute)
  RH.up(defaultroute)
  RH.down(defaultroute)
  RH.pages(defaultroute)
  RH.startrepl(defaultroute)

  nothing
end

end
