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

function tailapplog(handler::Function, logdirpath::String; frequency::Float64 = 0.5, env::AbstractString = "dev")
  logpath = joinpath(logdirpath, "$env-$(Dates.today()).log")
  if ! isfile(logpath)
    @error "No log file found at $logpath"
    return
  end

  open(logpath) do io
    if ! isreadable(io)
      @error "Log file at $logpath is not readable"
      return
    end

    seekend(io)

    while true
      line = read(io, String)
      if ! isempty(line)
        handler(line)
      end
      sleep(frequency)
    end

    @info "Finished watching log file at $logpath"
    close(io)
  end
end

function logtype(line::String) :: Symbol
  if startswith(line, "┌ ") # start of log line
    if startswith(line, "┌ Debug: ")
      return :debug
    elseif startswith(line, "┌ Warn: ")
      return :warn
    elseif startswith(line, "┌ Error: ")
      return :error
    end
  end

  return :info
end

function parselog(line::AbstractString) :: Union{AbstractString,Nothing}
  prefix = "log:critical:"

  # check for missing packages
  r = r"""ArgumentError.*Package (\w*) not found"""
  m = match(r, line)
  if ! isnothing(m) && length(m.captures) >= 1
    return "$(prefix)package_not_found $(m.captures[1])"
  end

  # catch revise errors
  r = r"""The running code does not match the saved version for the following files:
  (.*)
  (.*)"""
  m = match(r, line)
  if ! isnothing(m) && length(m.captures) >= 2
    return "$(prefix)revise_error $(m.captures[2])"
  end

  # catch parse errors
  r = r"""LoadError: ParseError:
  (.*)# Error @ (.*)
  (.*)
  (.*)
  (.*)"""
  m = match(r, line)
  if ! isnothing(m) && length(m.captures) >= 5
    return "$(prefix)parse_error $(m.captures[2])"
  end

  # catch generic error
  r = r"""┌ Error: (.*)
  (.*)
  (.*)"""
  m = match(r, line)
  if ! isnothing(m) && length(m.captures) >= 3
    return "$(prefix)application $(m.captures[1])"
  end

  return
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
