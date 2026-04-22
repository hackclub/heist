import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["days", "hours", "minutes", "seconds"]
  static values = { target: String }

  connect() {
    this.targetTime = new Date(this.targetValue).getTime()
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  tick() {
    const now = Date.now()
    const diff = Math.max(0, this.targetTime - now)
    const totalSeconds = Math.floor(diff / 1000)
    const days = Math.floor(totalSeconds / 86400)
    const hours = Math.floor((totalSeconds % 86400) / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    if (this.hasDaysTarget) this.daysTarget.textContent = String(days).padStart(2, "0")
    if (this.hasHoursTarget) this.hoursTarget.textContent = String(hours).padStart(2, "0")
    if (this.hasMinutesTarget) this.minutesTarget.textContent = String(minutes).padStart(2, "0")
    if (this.hasSecondsTarget) this.secondsTarget.textContent = String(seconds).padStart(2, "0")

    if (diff === 0) {
      clearInterval(this.timer)
      this.element.dispatchEvent(new CustomEvent("countdown:complete", { bubbles: true }))
    }
  }
}
