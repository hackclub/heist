<script lang="ts">
  import { api, esc, fmt } from '$lib/api';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';

  interface Ticket {
    ticket_number: number;
    thread_ts: string;
    user_id: string;
    user_name?: string;
    status: string;
    created_at: string;
    claimed_by: string | null;
  }
  interface Stats { total: number; open: number; resolved: number }
  interface TeamMember { user_id: string; name: string; added_by: string; added_at: string }

  let stats = $state<Stats>({ total: 0, open: 0, resolved: 0 });
  let tickets = $state<Ticket[]>([]);
  let oldestOpen = $state<Ticket[]>([]);
  let myTickets = $state<Ticket[]>([]);
  let team = $state<TeamMember[]>([]);
  let page = $state(0);
  const perPage = 15;
  let totalTickets = $state(0);

  async function load() {
    try { stats = await api<Stats>('/api/stats'); totalTickets = stats.total; } catch (e) { /* */ }
    try { tickets = await api<Ticket[]>(`/api/tickets?limit=${perPage}&offset=${page * perPage}`); } catch (e) { tickets = []; }
    try { oldestOpen = await api<Ticket[]>('/api/tickets/oldest'); } catch (e) { /* */ }
    try { myTickets = await api<Ticket[]>('/api/tickets/mine'); } catch (e) { /* */ }
    try { team = await api<TeamMember[]>('/api/support/team'); } catch (e) { /* */ }
  }

  async function resolve(ts: string) { await fetch(`/api/tickets/${ts}/resolve`, { method: 'POST' }); load(); }
  async function reopen(ts: string) { await fetch(`/api/tickets/${ts}/reopen`, { method: 'POST' }); load(); }
  function goPage(p: number) { page = p; load(); }

  function age(created: string): string {
    const diff = Date.now() - new Date(created).getTime();
    const days = Math.floor(diff / 86400000);
    const hours = Math.floor((diff % 86400000) / 3600000);
    if (days >= 1) return `${days}d ${hours}h`;
    return `${hours}h`;
  }

  const oldestAge = $derived(oldestOpen.length > 0 ? age(oldestOpen[0].created_at) : 'N/A');
  const myCount = $derived(myTickets.filter(t => t.status === 'open').length);

  onMount(() => { load(); const i = setInterval(load, 30000); return () => clearInterval(i); });
</script>

<svelte:head><title>Support Dashboard</title></svelte:head>

<div class="cards">
  <div class="card"><div class="n">{stats.total}</div><div class="l">Total</div></div>
  <div class="card"><div class="n">{stats.open}</div><div class="l">Open</div></div>
  <div class="card"><div class="n">{stats.resolved}</div><div class="l">Resolved</div></div>
  <a href="/mine" class="card" style="text-decoration:none;color:inherit">
    <div class="n">{myCount}</div>
    <div class="l">Assigned to Me</div>
  </a>
  <div class="card">
    <div class="n">{oldestAge}</div>
    <div class="l">Oldest Open</div>
  </div>
</div>

<div class="panel">
  <h2>Recent Tickets <a href="/mine" style="color:#888;font-size:12px;margin-left:8px">My Tickets →</a></h2>
  {#if tickets.length === 0}
    <div class="empty">No tickets yet.</div>
  {:else}
    <table>
      <thead><tr><th>#</th><th>User</th><th>Status</th><th>Created</th><th></th></tr></thead>
      <tbody>
        {#each tickets as t}
          <tr class="t-row" onclick={() => goto(`/ticket/${t.ticket_number}`)} onkeydown={(e) => e.key === 'Enter' && goto(`/ticket/${t.ticket_number}`)} role="link" tabindex="0">
            <td>#{t.ticket_number}</td>
            <td>{@html esc(t.user_name || t.user_id)}</td>
            <td><span class="badge {t.status}">{t.status}</span></td>
            <td>{fmt(t.created_at)}</td>
            <td>
              {#if t.status === 'open'}
                <button class="btn resolve" onclick={(e) => { e.stopPropagation(); resolve(t.thread_ts); }}>Resolve</button>
              {:else}
                <button class="btn reopen" onclick={(e) => { e.stopPropagation(); reopen(t.thread_ts); }}>Reopen</button>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}

  {#if totalTickets > perPage}
    <div class="pages">
      {#each Array(Math.ceil(totalTickets / perPage)) as _, i}
        <button class:active={i === page} onclick={() => goPage(i)}>{i + 1}</button>
      {/each}
    </div>
  {/if}
</div>

<div class="panel">
  <h2>Support Team</h2>
  {#if team.length === 0}
    <div class="empty">No support team members yet.</div>
  {:else}
    <table>
      <thead><tr><th>Name</th><th>User ID</th><th>Added</th></tr></thead>
      <tbody>
        {#each team as m}
          <tr><td>{@html esc(m.name)}</td><td>{m.user_id}</td><td>{fmt(m.added_at)}</td></tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .cards { display: grid; grid-template-columns: repeat(5, 1fr); gap: 14px; margin-bottom: 26px; }
  .card { background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.08); padding: 18px 12px; border-radius: 8px; text-align: center; }
  .card .n { font-size: 26px; font-weight: 700; }
  .card .l { font-size: 11px; color: #888; margin-top: 4px; }
  .panel { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 8px; padding: 22px; margin-bottom: 26px; }
  .panel h2 { font-size: 15px; color: #ccc; margin-bottom: 16px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 10px 14px; text-align: left; font-size: 13px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
  th { color: #888; font-weight: 600; }
  .t-row { cursor: pointer; transition: background .15s; }
  .t-row:hover { background: rgba(255, 255, 255, 0.04); }
  .badge { padding: 2px 8px; border-radius: 3px; font-size: 12px; font-weight: 600; }
  .badge.open { background: rgba(255, 255, 255, 0.1); }
  .badge.resolved { background: rgba(255, 255, 255, 0.04); color: #888; }
  .btn { padding: 4px 12px; border-radius: 3px; border: none; cursor: pointer; font-size: 12px; font-weight: 600; }
  .btn.resolve { background: rgba(255, 255, 255, 0.08); color: #ccc; border: 1px solid rgba(255, 255, 255, 0.15); }
  .btn.resolve:hover { background: rgba(255, 255, 255, 0.15); color: #fff; }
  .btn.reopen { background: rgba(255, 255, 255, 0.12); color: #fff; }
  .btn.reopen:hover { background: rgba(255, 255, 255, 0.2); }
  .pages { display: flex; justify-content: center; gap: 6px; margin-top: 16px; }
  .pages button { padding: 5px 12px; border: 1px solid rgba(255, 255, 255, 0.1); background: rgba(255, 255, 255, 0.04); color: #ccc; border-radius: 3px; cursor: pointer; font-size: 12px; }
  .pages button.active { background: rgba(255, 255, 255, 0.15); border-color: rgba(255, 255, 255, 0.2); color: #fff; }
  .empty { color: #555; padding: 28px; text-align: center; font-size: 13px; }
  @media (max-width: 700px) { .cards { grid-template-columns: repeat(3, 1fr); } }
</style>
