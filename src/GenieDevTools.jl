module GenieDevTools

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates
using RemoteREPL

import Stipple, Stipple.Pages

const defaultroute = "/_devtools_"
const logfile = "log/$(Genie.config.app_env)-$(Dates.today()).log";

include("register.jl")

function register_routes(defaultroute = defaultroute)
  register_errors_route(defaultroute)
  register_dir_route(defaultroute)
  register_edit_route(defaultroute)
  register_save_route(defaultroute)
  register_exec_route(defaultroute)
  register_id_route(defaultroute)
  register_log_route(defaultroute)
  register_exit_route(defaultroute)
  register_up_route(defaultroute)
  register_down_route(defaultroute)
  register_pages_route(defaultroute)
  register_assets_route(defaultroute)
  register_startrepl_route(defaultroute)
  nothing
end

end
