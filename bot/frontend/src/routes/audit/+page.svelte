<script lang="ts">
  import { esc, fmt } from '$lib/api';
  import { onMount } from 'svelte';

  interface AuditEntry {
    id: number;
    timestamp: string;
    user_id: string;
    user_name: string;
    action: string;
    details: string;
  }

  let logs = $state<AuditEntry[]>([]);
  let error = $state('');
  let filterAction = $state('all');
  let filterSearch = $state('');
  let filterFrom = $state('');
  let filterTo = $state('');
  let page = $state(0);
  const perPage = 50;
  let loading = $state(false);

  async function load() {
    loading = true;
    try {
      const params = new URLSearchParams({
        limit: String(perPage),
        offset: String(page * perPage),
      });
      if (filterAction !== 'all') params.set('action', filterAction);
      if (filterSearch) params.set('search', filterSearch);
      if (filterFrom) params.set('from', filterFrom);
      if (filterTo) params.set('to', filterTo);

      logs = await fetch(`/api/audit?${params}`).then(r => {
        if (!r.ok) throw new Error('Forbidden');
        return r.json();
      });
      error = '';
    } catch (e) {
      error = 'Access denied — only the owner can view audit logs.';
      logs = [];
    }
    loading = false;
  }

  function applyFilters() { page = 0; load(); }
  function prevPage() { if (page > 0) { page--; load(); } }
  function nextPage() { page++; load(); }

  onMount(load);
</script>

<svelte:head><title>Audit Log — Support</title></svelte:head>

<h2 style="color:#ccc;font-size:15px;margin-bottom:14px">Audit Log</h2>

<div class="filters">
  <select bind:value={filterAction} onchange={applyFilters}>
    <option value="all">All Actions</option>
    <option value="login">Login</option>
    <option value="logout">Logout</option>
    <option value="resolve">Resolve</option>
    <option value="reopen">Reopen</option>
    <option value="admin">Admin</option>
    <option value="unadmin">Unadmin</option>
    <option value="enable">Enable</option>
    <option value="disable">Disable</option>
  </select>
  <input type="text" placeholder="Search..." bind:value={filterSearch} onkeydown={(e) => e.key === 'Enter' && applyFilters()}>
  <input type="date" bind:value={filterFrom} onchange={applyFilters}>
  <span>to</span>
  <input type="date" bind:value={filterTo} onchange={applyFilters}>
  <button onclick={applyFilters} class="filter-btn">Filter</button>
</div>

{#if error}
  <div class="err">{error}</div>
{:else if loading}
  <div class="empty">Loading...</div>
{:else if logs.length === 0}
  <div class="empty">No matching entries.</div>
{:else}
  <div class="panel">
    <table>
      <thead><tr><th>Time</th><th>User</th><th>Action</th><th>Details</th></tr></thead>
      <tbody>
        {#each logs as l}
          <tr>
            <td class="time">{fmt(l.timestamp)}</td>
            <td>{@html esc(l.user_name)}</td>
            <td><span class="action">{l.action}</span></td>
            <td class="details">{l.details}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <div class="pages">
    <button onclick={prevPage} disabled={page === 0}>Previous</button>
    <span>Page {page + 1}</span>
    <button onclick={nextPage} disabled={logs.length < perPage}>Next</button>
  </div>
{/if}

<style>
  .filters { display: flex; gap: 8px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; }
  .filters select, .filters input { background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 6px 10px; border-radius: 4px; font-size: 12px; font-family: inherit; }
  .filters select option { background: #1a1a2e; color: #fff; }
  .filters input[type="date"] { color-scheme: dark; }
  .filters span { color: #888; font-size: 12px; }
  .filter-btn { background: rgba(255,255,255,0.1); color: #fff; border: 1px solid rgba(255,255,255,0.15); padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 12px; }
  .filter-btn:hover { background: rgba(255,255,255,0.18); }
  .panel { background: rgba(255,255,255,0.03); backdrop-filter: blur(4px); border: 1px solid rgba(255,255,255,0.06); border-radius: 6px; padding: 18px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 8px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid rgba(255,255,255,0.06); }
  th { color: #888; font-weight: 600; }
  .time { color: #888; white-space: nowrap; font-size: 12px; }
  .details { color: #888; font-size: 12px; }
  .action { font-size: 12px; font-weight: 600; }
  .empty, .err { color: #555; padding: 24px; text-align: center; font-size: 13px; }
  .pages { display: flex; justify-content: center; align-items: center; gap: 12px; margin-top: 14px; }
  .pages button { padding: 5px 14px; border: 1px solid rgba(255,255,255,0.1); background: rgba(255,255,255,0.04); color: #ccc; border-radius: 3px; cursor: pointer; font-size: 12px; }
  .pages button:hover { background: rgba(255,255,255,0.1); }
  .pages button:disabled { opacity: 0.3; cursor: default; }
  .pages span { font-size: 12px; color: #888; }
</style>
