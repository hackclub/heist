# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "gsap", to: "https://ga.jspm.io/npm:gsap@3.15.0/index.js"
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/+esm"
pin "chartjs-plugin-zoom", to: "https://cdn.jsdelivr.net/npm/chartjs-plugin-zoom@2.0.1/+esm"
