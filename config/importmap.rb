# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "gsap", to: "https://ga.jspm.io/npm:gsap@3.15.0/index.js"
pin "chart.js" # @4.5.1
pin "chartjs-plugin-zoom" # @2.2.0
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "chart.js/helpers", to: "chart.js--helpers.js" # @4.5.1
pin "hammerjs" # @2.0.8
