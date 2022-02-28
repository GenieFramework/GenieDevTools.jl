module GenieDevTools

using Genie
using Genie.Renderers.Json, Genie.Renderers.Html

using Revise
using Dates

import Stipple, Stipple.Pages

const defaultroute = "/_devtools_"
const logfile = "log/$(Genie.config.app_env)-$(Dates.today()).log";

function register_routes(defaultroute = defaultroute)
  route("$defaultroute/errors") do
    (:errors => Revise.queue_errors) |> json
  end

  route("$defaultroute/dir") do
    pth = params(:path, pwd())

    isdir(pth) || return (:error => "$pth is not a dir") |> json

    result = []
    for p in readdir(pth)
      push!(result, (isdir(joinpath(pth, p)) ? :dir => p : :file => p))
    end

    (:dir => result) |> json
  end

  route("$defaultroute/edit") do
    pth = params(:path, pwd())

    isfile(pth) || return (:error => "$pth is not a file") |> json

    io = open(pth, "r")
    content = read(io, String)
    close(io)

    (:content => content) |> json
  end

  route("$defaultroute/save", method = POST) do
    pth = params(:path, pwd())

    isfile(pth) || return (:error => "$pth is not a file") |> json

    isempty(params(:payload, "")) && return (:error => "empty payload") |> json

    (:save => open(pth, "w") do f
      write(f, params(:payload))
    end) |> json
  end

  routes("$defaultroute/exec", method = [GET, POST]) do
    Core.eval(Main, Meta.parse(params(:cmd))) |> html
  end

  route("$defaultroute/id") do
    (:id => Main.UserApp) |> json
  end

  route("$defaultroute/log") do
    isfile(logfile) || return (:error => "no log file found") |> json

    io = open(logfile, "r")
    content = read(io, String)
    close(io)

    (:content => content) |> json
  end

  route("$defaultroute/exit") do
    exit()

    (:status => :OK) |> json
  end

  route("$defaultroute/up") do
    up()

    (:status => :OK) |> json
  end

  route("$defaultroute/down") do
    Genie.AppServer.down!()

    (:status => :OK) |> json
  end

  route("$defaultroute/pages") do
    (:pages => [Dict( :route  => Dict(:method => p.route.method, :path => p.route.path),
                      :view   => p.view |> string,
                      :model  => Dict(:name => p.model,
                                      :fields => [fn for fn in fieldnames(p.model)],
                                      :types  => [ft for ft in fieldtypes(p.model)]),
                      :layout => p.layout |> string) for p in Stipple.Pages.pages()]) |> json
  end

  route("$defaultroute/deps") do
    (:deps =>
      Dict(:scripts =>
        vcat(
          [Base.invokelatest(d[2]) for d in Stipple.DEPS]
        ) |> Base.Iterators.flatten |> collect
        ,
        :styles =>
        filter(vcat([Base.invokelatest(d) for d in Stipple.Layout.THEMES]) |> Base.Iterators.flatten |> collect) do x
          ! isempty(x)
        end
      )
    ) |> json
  end

  nothing
end

end
