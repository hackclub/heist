import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"
import zoomPlugin from "chartjs-plugin-zoom"

Chart.register(...registerables, zoomPlugin)

const COLOR_ACTUAL = "#C0F477"
const COLOR_PACE = "rgba(255, 229, 114, 0.7)"
const COLOR_PROJ_AHEAD = "#C0F477"
const COLOR_PROJ_BEHIND = "#FF6B6B"
const COLOR_AXIS = "rgba(218, 251, 172, 0.45)"
const COLOR_GRID = "rgba(218, 251, 172, 0.08)"
const FONT_FAMILY = "ModeSeven, monospace"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    actual: Array,
    goal: Number,
    totalDays: Number,
    expectedHours: Number,
    projectionHours: Number,
    todayIndex: Number,
  }

  connect() {
    if (!this.hasCanvasTarget) return
    const ctx = this.canvasTarget.getContext("2d")
    const labels = this.labelsValue
    const totalPoints = labels.length

    const paceLine = labels.map((_, i) =>
      this.totalDaysValue > 0 ? (this.goalValue * i) / this.totalDaysValue : 0
    )

    const actual = labels.map((_, i) => {
      const v = this.actualValue[i]
      return (v === undefined || v === null) ? null : v
    })

    const projection = labels.map(() => null)
    const lastActualIdx = this.todayIndexValue
    const lastActualValue = actual[lastActualIdx]
    if (
      this.projectionHoursValue !== null &&
      this.projectionHoursValue !== undefined &&
      lastActualValue !== null &&
      lastActualIdx >= 0 &&
      lastActualIdx < totalPoints
    ) {
      projection[lastActualIdx] = lastActualValue
      projection[totalPoints - 1] = this.projectionHoursValue
    }

    const projColor =
      this.projectionHoursValue >= this.goalValue ? COLOR_PROJ_AHEAD : COLOR_PROJ_BEHIND

    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Pace",
            data: paceLine,
            borderColor: COLOR_PACE,
            backgroundColor: "transparent",
            borderDash: [4, 4],
            borderWidth: 1.5,
            pointRadius: 0,
            tension: 0,
            order: 3,
          },
          {
            label: "Projection",
            data: projection,
            borderColor: projColor,
            backgroundColor: "transparent",
            borderDash: [3, 4],
            borderWidth: 1.5,
            pointRadius: 0,
            tension: 0,
            spanGaps: true,
            order: 2,
          },
          {
            label: "Actual",
            data: actual,
            borderColor: COLOR_ACTUAL,
            backgroundColor: "rgba(192, 244, 119, 0.10)",
            borderWidth: 2.5,
            pointRadius: (ctx) => (ctx.dataIndex === lastActualIdx ? 4 : 0),
            pointBackgroundColor: COLOR_ACTUAL,
            pointBorderColor: "#0a1309",
            pointBorderWidth: 1.5,
            tension: 0.15,
            fill: true,
            spanGaps: false,
            order: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        scales: {
          x: {
            ticks: {
              color: COLOR_AXIS,
              font: { family: FONT_FAMILY, size: 10 },
              maxRotation: 0,
              autoSkip: true,
              maxTicksLimit: 8,
            },
            grid: { color: COLOR_GRID, drawTicks: false },
            border: { color: COLOR_GRID },
          },
          y: {
            beginAtZero: true,
            suggestedMax: this.goalValue,
            ticks: {
              color: COLOR_AXIS,
              font: { family: FONT_FAMILY, size: 10 },
              callback: (v) => `${v}h`,
            },
            grid: { color: COLOR_GRID, drawTicks: false },
            border: { color: COLOR_GRID },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(10, 19, 9, 0.95)",
            borderColor: "#DAFBAC",
            borderWidth: 1,
            titleColor: "#FFE572",
            titleFont: { family: FONT_FAMILY, size: 11 },
            bodyColor: "#DAFBAC",
            bodyFont: { family: FONT_FAMILY, size: 11 },
            padding: 10,
            callbacks: {
              title: (items) => items[0]?.label || "",
              label: (item) => {
                if (item.parsed.y === null || item.parsed.y === undefined) return null
                const v = Math.round(item.parsed.y * 10) / 10
                return `${item.dataset.label}: ${v}h`
              },
            },
          },
          zoom: {
            pan: { enabled: true, mode: "x", modifierKey: null },
            zoom: {
              wheel: { enabled: true },
              pinch: { enabled: true },
              drag: { enabled: false },
              mode: "x",
            },
            limits: {
              x: { min: 0, max: totalPoints - 1, minRange: 2 },
            },
          },
        },
      },
    })
  }

  resetZoom() {
    this.chart?.resetZoom()
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
