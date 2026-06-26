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

  let tickets = $state<Ticket[]>([]);
  let error = $state('');

  onMount(async () => {
    try { tickets = await api<Ticket[]>('/api/tickets/mine'); } catch (e) { error = 'Failed to load.'; }
  });

  function age(created: string): string {
    const diff = Date.now() - new Date(created).getTime();
    const days = Math.floor(diff / 86400000);
    const hours = Math.floor((diff % 86400000) / 3600000);
    if (days >= 1) return `${days}d ${hours}h`;
    return `${hours}h`;
  }
</script>

<svelte:head><title>My Tickets — Support</title></svelte:head>

<h2 style="color:#ccc;font-size:15px;margin-bottom:14px">My Tickets</h2>

{#if error}
  <div class="empty">{error}</div>
{:else if tickets.length === 0}
  <div class="empty">No tickets assigned to you. When someone assigns you a ticket, it'll show here.</div>
{:else}
  <div class="panel">
    <table>
      <thead><tr><th>#</th><th>User</th><th>Age</th><th>Status</th></tr></thead>
      <tbody>
        {#each tickets as t}
          <tr class="t-row" onclick={() => goto(`/ticket/${t.ticket_number}`)} onkeydown={(e) => e.key === 'Enter' && goto(`/ticket/${t.ticket_number}`)} role="link" tabindex="0">
            <td>#{t.ticket_number}</td>
            <td>{@html esc(t.user_name || t.user_id)}</td>
            <td>{age(t.created_at)}</td>
            <td><span class="badge {t.status}">{t.status}</span></td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<style>
  .panel { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 8px; padding: 22px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 10px 14px; text-align: left; font-size: 13px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
  th { color: #888; font-weight: 600; }
  .t-row { cursor: pointer; transition: background .15s; }
  .t-row:hover { background: rgba(255, 255, 255, 0.04); }
  .badge { padding: 2px 8px; border-radius: 3px; font-size: 12px; font-weight: 600; }
  .badge.open { background: rgba(255, 255, 255, 0.1); }
  .badge.resolved { background: rgba(255, 255, 255, 0.04); color: #888; }
  .empty { color: #555; padding: 32px; text-align: center; font-size: 14px; }
</style>
