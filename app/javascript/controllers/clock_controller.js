import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 100)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const now = new Date()
    const h = String(now.getHours()).padStart(2, "0")
    const m = String(now.getMinutes()).padStart(2, "0")
    const s = String(now.getSeconds()).padStart(2, "0")
    const f = String(Math.floor(now.getMilliseconds() / 33)).padStart(2, "0")
    this.displayTarget.textContent = `${h}:${m}:${s}:${f}`
  }
}
