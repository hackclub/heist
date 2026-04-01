OkComputer::Registry.register "ferret", OkComputer::HttpCheck.new(ENV.fetch("FERRET_URL"))
