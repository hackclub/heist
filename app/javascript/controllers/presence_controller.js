import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.ping()
    this.interval = setInterval(() => this.ping(), 30000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  async ping() {
    try {
      const res = await fetch("/api/v1/presence/ping", { method: "POST", headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content } })
      const { count } = await res.json()
      this.countTarget.textContent = count
    } catch {}
  }
}
