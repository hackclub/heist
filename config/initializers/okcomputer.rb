if ENV["FERRET_URL"].present?
  OkComputer::Registry.register "ferret", OkComputer::HttpCheck.new(ENV.fetch("FERRET_URL"))
end
