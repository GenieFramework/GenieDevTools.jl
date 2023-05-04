module RouteHelpers

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates
using RemoteREPL

import Stipple, Stipple.Pages

const logfile = "log/$(Genie.config.app_env)-$(Dates.today()).log";

function errors(defaultroute)
  route("$defaultroute/errors") do
    (:errors => Revise.queue_errors) |> json
  end

  nothing
end

function dir(defaultroute)
  route("$defaultroute/dir") do
    pth = params(:path, pwd())

    isdir(pth) || return (:error => "$pth is not a dir") |> json

    result = []
    for p in readdir(pth)
      push!(result, (isdir(joinpath(pth, p)) ? :dir => p : :file => p))
    end

    (:dir => result) |> json
  end

  nothing
end

function edit(defaultroute)
  route("$defaultroute/edit") do
    pth = params(:path, pwd())

    isfile(pth) || return (:error => "$pth is not a file") |> json

    io = open(pth, "r")
    content = read(io, String)
    close(io)

    (:content => content) |> json
  end

  nothing
end

function save(defaultroute)
  route("$defaultroute/save", method=POST) do
    isempty(params(:path, "")) && return (:error => "The `path` parameter is missing") |> json

    pth = params(:path)

    isdir(dirname(pth)) || mkpath(dirname(pth))

    isfile(pth) || touch(pth)

    isempty(params(:payload, "")) && return (:error => "empty payload") |> json

    open(pth, "w") do f
      write(f, params(:payload))
    end

    (:status => :OK) |> json
  end

  nothing
end

function exec(defaultroute)
  routes("$defaultroute/exec", method=[GET, POST]) do
    Core.eval(Main, Meta.parse(params(:cmd))) |> html
  end

  nothing
end

function id(defaultroute)
  route("$defaultroute/id") do
    (:id => Main.UserApp) |> json
  end

  nothing
end

function log(defaultroute)
  route("$defaultroute/log") do
    isfile(logfile) || return (:error => "no log file found") |> json

    io = open(logfile, "r")
    content = read(io, String)
    close(io)

    (:content => content) |> json
  end

  nothing
end

function exit(defaultroute)
  route("$defaultroute/exit") do
    Base.exit()

    (:status => :OK) |> json
  end

  nothing
end

function up(defaultroute)
  route("$defaultroute/up") do
    up()

    (:status => :OK) |> json
  end

  nothing
end

function down(defaultroute)
  route("$defaultroute/down") do
    Genie.Server.down!()

    (:status => :OK) |> json
  end

  nothing
end

const STIPPLE_REACTIVE_ACCESS_MODES = Dict(1 => "Public", 2 => "Private", 4 => "Readonly", 8 => "JSFn")

function pages(defaultroute)
  route("$defaultroute/pages") do
    result = Dict(:pages => [])

    function modelfieldsinfo(model)
      fieldsinfo = []
      for f in fieldnames(typeof(model))
        ff = getfield(model, f)
        info = Dict()
        info[:name] = f
        info[:type] = typeof(ff)
        if info[:type] <: Stipple.Reactive
          info[:declaration] = ff.__source__
          info[:access] = get(STIPPLE_REACTIVE_ACCESS_MODES, ff.r_mode, "Unknown")
          info[:isreactive] = true
        else
          info[:declaration] = nothing
          info[:access] = "Public"
          info[:isreactive] = false
        end

        push!(fieldsinfo, info)
      end

      return fieldsinfo
    end

    for p in Stipple.Pages.pages()
      instance = try
        p.model |> Base.invokelatest
      catch ex
        @debug ex
        p.model
      end

      page_info = Dict(
        :route => Dict(:method => p.route.method, :path => p.route.path),
        :view => p.view |> string,
        :model => Dict( :name => Stipple.Elements.root(p.model),
                        :fields => modelfieldsinfo(instance)),
        :layout => length(p.layout) < Stipple.IF_ITS_THAT_LONG_IT_CANT_BE_A_FILENAME && isfile(p.layout) ? p.layout : nothing,
        :deps => modeldeps(instance),
        :assets => assets(),
        :config => config(),
      )

      push!(result[:pages], page_info)
    end

    result |> json
  end

  nothing
end

function config()
  Dict(
    :app_path => pwd(),
    :public_path => abspath(Genie.config.server_document_root)
  )
end

function assets(rootdir = Genie.config.server_document_root; extensions = ["js", "css"])
  result = String[]

  isdir(rootdir) || return result

  push!(result, Genie.Util.walk_dir(rootdir, only_extensions = extensions, only_files = true, exceptions = [])...)

  result
end

function modeldeps(m::M) where {M<:Stipple.ReactiveModel}
  Stipple.deps(m)

  scripts = String[]
  styles = String[]

  channelname = params(:CHANNEL__, "")

  basepath::String = if haskey(ENV, "BASEPATH")
    # the BASEPATH is the GBJL basepath, not the app's
    if haskey(ENV, "GBJL_PATH") && (ENV["GBJL_PATH"] == ( (startswith(ENV["BASEPATH"], "/") ? "" : "/") * ENV["BASEPATH"] ))
      ""
    else
      (startswith(ENV["BASEPATH"], "/") ? "" : "/") * ENV["BASEPATH"]
    end
  else
    ""
  end

  if ! isempty(channelname)
    push!(scripts, "$basepath/$channelname.js")
    routename = "get_$(channelname)js" |> Symbol

    if ! Genie.Router.isroute(routename)
      Genie.Router.route("/$channelname.js", named = routename) do
        "window.CHANNEL = '$channelname';" |> Genie.Renderers.Js.js
      end
    end
  end

  for r in routes(reversed = false)
    ! isempty(channelname) && endswith(r.path, "$channelname.js") && continue # don't add the channel script again

    if endswith(r.path, ".js")
      push!(scripts, basepath * r.path)
    elseif endswith(r.path, ".css")
      push!(styles, basepath * r.path)
    end
  end

  Dict(:scripts => scripts, :styles => styles)
end

function startrepl(defaultroute)
  route("$defaultroute/startrepl") do
    port = params(:port, )
    port = isa(port, String) ? tryparse(Int, port) : port
    port = isnothing(port) ? rand(50_000:60_000) : port

    @async serve_repl(port)

    Dict(
      :status => :OK,
      :port => port
    ) |> json
  end

  nothing
end

end # module