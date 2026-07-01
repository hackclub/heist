<script lang="ts">
  import { api, esc } from '$lib/api';
  import { onMount } from 'svelte';

  interface LBEntry { name: string; count: number }
  interface Leaderboard { resolvers: LBEntry[]; creators: LBEntry[] }
  interface DetailStats { avgResponseTime: { avgHours: number } | null; byWeekday: { weekday: number; count: number }[] }

  let lb = $state<Leaderboard>({ resolvers: [], creators: [] });
  let ds = $state<DetailStats>({ avgResponseTime: null, byWeekday: [] });

  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  function renderChart(data: { weekday: number; count: number }[]) {
    const canvas = document.getElementById('chartCanvas') as HTMLCanvasElement | null;
    if (!canvas) return;
    function tryRender() {
      if (typeof (window as any).Chart === 'undefined') {
        const s = document.createElement('script');
        s.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js';
        s.onload = () => doRender();
        document.head.appendChild(s);
        return;
      }
      doRender();
    }
    function doRender() {
      new (window as any).Chart(canvas!.getContext('2d'), {
        type: 'bar',
        data: {
          labels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          datasets: [{
            label: 'Tickets',
            data: [0, 1, 2, 3, 4, 5, 6].map(i => {
              const d = data.find(w => w.weekday === i);
              return d ? d.count : 0;
            }),
            backgroundColor: 'rgba(255,255,255,0.2)',
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { labels: { color: '#888', font: { size: 11 } } } },
          scales: {
            x: { ticks: { color: '#666', font: { size: 10 } }, grid: { color: '#333' } },
            y: { ticks: { color: '#666', font: { size: 10 }, beginAtZero: true, stepSize: 1 }, grid: { color: '#333' } },
          },
        },
      });
    }
    setTimeout(tryRender, 100);
  }

  onMount(async () => {
    try { lb = await api<Leaderboard>('/api/stats/leaderboard'); } catch (e) { /* */ }
    try {
      ds = await api<DetailStats>('/api/stats/detail');
      renderChart(ds.byWeekday);
    } catch (e) { /* */ }
  });
</script>

<svelte:head><title>Stats — Support</title></svelte:head>

<div class="grid">
  <div class="panel">
    <h2>Top Resolvers</h2>
    {#if lb.resolvers.length === 0}
      <div class="empty">No resolutions yet.</div>
    {:else}
      <table>
        <thead><tr><th>#</th><th>Name</th><th>Resolved</th></tr></thead>
        <tbody>
          {#each lb.resolvers as r, i}
            <tr>
              <td>{i + 1}</td>
              <td>{@html esc(r.name)} <span class="bar" style="width:{r.count / lb.resolvers[0].count * 100}px"></span></td>
              <td>{r.count}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
  <div class="panel">
    <h2>Top Creators</h2>
    {#if lb.creators.length === 0}
      <div class="empty">No tickets yet.</div>
    {:else}
      <table>
        <thead><tr><th>#</th><th>Name</th><th>Tickets</th></tr></thead>
        <tbody>
          {#each lb.creators as c, i}
            <tr>
              <td>{i + 1}</td>
              <td>{@html esc(c.name)} <span class="bar" style="width:{c.count / lb.creators[0].count * 100}px"></span></td>
              <td>{c.count}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>

<div class="panel">
  <h2>Tickets by Day of Week</h2>
  <div class="chart-wrap"><canvas id="chartCanvas"></canvas></div>
</div>

<div class="panel">
  <h2>Summary</h2>
  <div class="stat-row"><span>Avg Response Time</span><span class="val">{ds.avgResponseTime ? `${ds.avgResponseTime.avgHours} hours` : 'N/A'}</span></div>
  <div class="stat-row"><span>Total Tickets</span><span class="val">{ds.byWeekday.reduce((a, b) => a + b.count, 0)}</span></div>
  {#if ds.byWeekday.length}
  {@const busiest = ds.byWeekday.reduce((a, b) => b.count > a.count ? b : a, { weekday: 0, count: 0 })}
  <div class="stat-row"><span>Busiest Day</span><span class="val">{dayNames[busiest.weekday]}</span></div>
  {/if}
</div>

<style>
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 22px; margin-bottom: 22px; }
  .panel { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 6px; padding: 18px; margin-bottom: 22px; }
  .panel h2 { font-size: 15px; color: #ccc; margin-bottom: 14px; }
  .chart-wrap { height: 240px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 7px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
  th { color: #888; font-weight: 600; }
  td .bar { display: inline-block; height: 8px; background: rgba(255, 255, 255, 0.3); border-radius: 2px; margin-left: 8px; vertical-align: middle; }
  .stat-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(255, 255, 255, 0.06); font-size: 14px; }
  .stat-row .val { font-weight: 700; }
  .empty { color: #555; padding: 24px; text-align: center; font-size: 13px; }
  @media (max-width: 700px) { .grid { grid-template-columns: 1fr; } }
</style>
