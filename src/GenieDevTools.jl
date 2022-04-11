module GenieDevTools

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates
using RemoteREPL

import Stipple, Stipple.Pages

const defaultroute = "/_devtools_"
const logfile = "log/$(Genie.config.app_env)-$(Dates.today()).log";

include("route_helpers.jl")
import .RouteHelpers as RH

function register_routes(defaultroute = defaultroute)
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
  RH.assets(defaultroute)
  RH.startrepl(defaultroute)
  nothing
end

end
