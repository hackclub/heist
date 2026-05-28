import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step"]

  connect() {
    this.current = 0
    this.show()
  }

  next() {
    if (this.current < this.stepTargets.length - 1) {
      this.current += 1
      this.show()
    }
  }

  prev() {
    if (this.current > 0) {
      this.current -= 1
      this.show()
    }
  }

  show() {
    this.stepTargets.forEach((step, i) => {
      step.hidden = i !== this.current
    })
  }
}
