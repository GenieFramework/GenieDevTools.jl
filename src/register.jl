function register_errors_route(defaultroute)
  route("$defaultroute/errors") do
    (:errors => Revise.queue_errors) |> json
  end
  nothing
end

function register_dir_route(defaultroute)
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

function register_edit_route(defaultroute)
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

function register_save_route(defaultroute)
  route("$defaultroute/save", method=POST) do
    pth = params(:path, pwd())

    isfile(pth) || return (:error => "$pth is not a file") |> json

    isempty(params(:payload, "")) && return (:error => "empty payload") |> json

    (:save => open(pth, "w") do f
      write(f, params(:payload))
    end)

    (:status => :OK) |> json
  end
  nothing
end

function register_exec_route(defaultroute)
  routes("$defaultroute/exec", method=[GET, POST]) do
    Core.eval(Main, Meta.parse(params(:cmd))) |> html
  end
  nothing
end

function register_id_route(defaultroute)
  route("$defaultroute/id") do
    (:id => Main.UserApp) |> json
  end
  nothing
end

function register_log_route(defaultroute)
  route("$defaultroute/log") do
    isfile(logfile) || return (:error => "no log file found") |> json

    io = open(logfile, "r")
    content = read(io, String)
    close(io)

    (:content => content) |> json
  end
  nothing
end

function register_exit_route(defaultroute)
  route("$defaultroute/exit") do
    exit()

    (:status => :OK) |> json
  end
  nothing
end

function register_up_route(defaultroute)
  route("$defaultroute/up") do
    up()

    (:status => :OK) |> json
  end
  nothing
end

function register_down_route(defaultroute)
  route("$defaultroute/down") do
    Genie.AppServer.down!()

    (:status => :OK) |> json
  end
  nothing
end

function register_pages_route(defaultroute)
  route("$defaultroute/pages") do
    (:pages => [Dict(:route => Dict(:method => p.route.method, :path => p.route.path),
      :view => p.view |> string,
      :model => Dict(:name => p.model,
        :fields => [fn for fn in fieldnames(p.model)],
        :types => [ft for ft in fieldtypes(p.model)]),
      :layout => p.layout |> string) for p in Stipple.Pages.pages()]) |> json
  end
  nothing
end

function register_assets_route(defaultroute)
  route("$defaultroute/assets") do
    scripts = String[]
    styles = String[]

    for r in routes()
      if endswith(r.path, ".js")
        push!(scripts, r.path)
      elseif endswith(r.path, ".css")
        push!(styles, r.path)
      end
    end

    (:deps => Dict(:scripts => scripts, :styles => styles)) |> json
  end
  nothing
end

function register_startrepl_route(defaultroute)
  route("$defaultroute/startrepl") do
    port = rand(10000:60000)
    @async serve_repl(port)

    Dict(
      :status => :OK,
      :port => port
    ) |> json
  end
  nothing
end