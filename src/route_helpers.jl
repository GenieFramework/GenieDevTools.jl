module RouteHelpers

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates
using RemoteREPL

import Stipple, Stipple.Pages
import StippleUI
import Tables

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

    new_file = false
    if ! isfile(pth)
      touch(pth)
      new_file = true
    end

    open(pth, "w") do f
      write(f, params(:payload))
    end

    if new_file
      Genie.Watch.watchpath(dirname(pth))
      Genie.Watch.watchpath(pth)
      @async Genie.Watch.watch()
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

    function istable_info(info, field)
      if Tables.istable(field)
        info[:istable] = true
        info[:columns] = Tables.columnnames(field)
      end
    end

    function isdatatable_info(info, field)
      if isa(field, StippleUI.Tables.DataTable)
        info[:isdatatable] = true
        info[:columns] = StippleUI.Tables.columns(field)
        info[:props] = [:data, :columns]
      end
    end

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
          istable_info(info, ff[])
          isdatatable_info(info, ff[])
        else
          info[:declaration] = nothing
          info[:access] = "Public"
          info[:isreactive] = false
          istable_info(info, ff)
          isdatatable_info(info, ff)
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

      jsscripts = [r for r in routes() if endswith(lowercase(r.path), lowercase(Stipple.Elements.root(instance)) * ".js")]
      page_info = Dict(
        :route => Dict(:method => p.route.method, :path => p.route.path),
        :view => p.view |> string,
        :model => Dict( :name => Stipple.Elements.root(instance),
                        :script => ! isempty(jsscripts) ? jsscripts[1].path : nothing,
                        :fields => modelfieldsinfo(instance)),
        :layout => length(p.layout) < Stipple.IF_ITS_THAT_LONG_IT_CANT_BE_A_FILENAME && isfile(p.layout) ? p.layout : nothing,
        :deps => modeldeps(instance),
        :assets => assets(),
        :config => config(),
        :sesstoken => Stipple.sessionid(),
        :gb_components => gb_components(),
        :themes => themes(),
        # :theme_urls => theme_urls()
      )

      push!(result[:pages], page_info)
    end

    result |> json
  end

  nothing
end

function theme_urls()
  [Stipple.Theme.to_path(t) for t in keys(Stipple.Theme.get_themes()) |> collect]
end

function themes()
  Dict(
    :active => Dict(
      :name => Stipple.Theme.get_theme(),
      :asset => Stipple.Theme.to_path(Stipple.Theme.get_theme())
    ),
    :registered => [
      Dict(
          :name => t,
          :asset => Stipple.Theme.to_path(t)
        ) for t in keys(Stipple.Theme.get_themes()) |> collect |> sort!
    ]
  )
end

function config()
  Dict(
    :app_path => abspath(normpath(pwd())) |> realpath,
    :public_path => abspath(normpath(Genie.config.server_document_root))
  )
end

function assets(rootdir = Genie.config.server_document_root; extensions = ["js", "css"])
  result = String[]

  isdir(rootdir) || return result

  push!(result, Genie.Util.walk_dir(rootdir,
                                    only_extensions = extensions,
                                    only_files = true,
                                    exceptions = [],
                                    test_function = (full_path) -> begin
                                      ! startswith(full_path, rootdir * "/css/$(Stipple.THEMES_FOLDER)")
                                    end
                                  )...
      )

  # handle windows paths with backslashes -- replace with forward slashes
  Sys.iswindows() ? [replace(p, "\\" => "/") for p in result] : result
end

function assets_basepath() :: String
  if haskey(ENV, "BASEPATH")
    # the BASEPATH is the GBJL basepath, not the app's
    if haskey(ENV, "GBJL_PATH") && (ENV["GBJL_PATH"] == ( (startswith(ENV["BASEPATH"], "/") ? "" : "/") * ENV["BASEPATH"] ))
      ""
    else
      bp = (startswith(ENV["BASEPATH"], "/") ? "" : "/") * ENV["BASEPATH"]
      endswith(bp, "/") ? bp[1:end-1] : bp
    end
  else
    ""
  end
end

function modeldeps(m::M) where {M<:Stipple.ReactiveModel}
  Stipple.deps(m)

  scripts = String[]
  styles = String[]

  channelname = params(:CHANNEL__, "")
  basepath = assets_basepath()

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
    occursin("gb_component", r.path) && continue # don't include gb_component assets
    r.path in theme_urls() && continue # don't include theme assets

    if endswith(r.path, ".js")
      push!(scripts, basepath * r.path)
    elseif endswith(r.path, ".css")
      push!(styles, basepath * r.path)
    end
  end

  Dict(:scripts => scripts, :styles => styles)
end

function gb_components()
  prefix = "components"
  suffix = "gb_component"
  basepath = assets_basepath()
  components = Dict{String, Vector{String}}()

  for r in routes(reversed = false)
    (occursin(prefix, r.path) && occursin(suffix, r.path)) || continue # only include gb_component assets
    m = match(Regex("/$prefix/(.*)/$suffix/"), r.path)
    m === nothing && continue
    isempty(m.captures) && continue

    component_name = m.captures[1]
    haskey(components, component_name) || (components[component_name] = String[])

    push!(components[component_name], basepath * r.path)
  end

  components
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