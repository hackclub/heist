<script lang="ts">
  import { api, esc, fmt } from '$lib/api';
  import { onMount } from 'svelte';
  import { page } from '$app/stores';

  interface Ticket {
    ticket_number: number;
    thread_ts: string;
    user_id: string;
    user_name?: string;
    status: string;
    created_at: string;
    resolved_at: string | null;
    resolved_by: string | null;
  }

  interface Message {
    ts: string;
    user: string;
    text: string;
    isBot: boolean;
  }

  let ticket = $state<Ticket | null>(null);
  let messages = $state<Message[]>([]);
  let notes = $state<{ id: number; author_name: string; note: string; created_at: string }[]>([]);
  let msgsLoading = $state(true);
  let msgText = $state('');
  let anon = $state(false);
  let sending = $state(false);
  let noteText = $state('');
  let noteSending = $state(false);
  let team = $state<{ user_id: string; name: string }[]>([]);
  let assignId = $state('');

  onMount(async () => {
    const num = $page.params.number;
    try { ticket = await api<Ticket>(`/api/tickets/number/${num}`); } catch (e) { /* */ }
    if (ticket) {
      api<Message[]>(`/api/tickets/${ticket.thread_ts}/messages`).then(msgs => {
        messages = msgs;
        msgsLoading = false;
        setTimeout(() => {
          const el = document.getElementById('msgList');
          if (el) el.scrollTop = el.scrollHeight;
        }, 50);
      }).catch(() => { msgsLoading = false; });
      api<typeof notes>(`/api/tickets/${ticket.thread_ts}/notes`).then(n => notes = n).catch(() => {});
    }
    try { team = await api<{ user_id: string; name: string }[]>('/api/support/team'); } catch (e) { /* */ }
  });

  async function toggleStatus() {
    if (!ticket) return;
    const endpoint = ticket.status === 'open' ? 'resolve' : 'reopen';
    await fetch(`/api/tickets/${ticket.thread_ts}/${endpoint}`, { method: 'POST' });
    window.location.reload();
  }

  async function send() {
    if (!msgText.trim() || !ticket || sending) return;
    sending = true;
    try {
      await fetch(`/api/tickets/${ticket.thread_ts}/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: msgText.trim(), anonymous: anon }),
      });
      msgText = '';
      // Reload messages
      try { messages = await api<Message[]>(`/api/tickets/${ticket.thread_ts}/messages`); } catch (e) { /* */ }
    } catch (e) { /* */ }
    sending = false;
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
  }

  async function assign() {
    if (!assignId || !ticket) return;
    await fetch(`/api/tickets/${ticket.thread_ts}/assign`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: assignId }),
    });
    window.location.reload();
  }

  async function addInternalNote() {
    if (!noteText.trim() || !ticket || noteSending) return;
    noteSending = true;
    try {
      await fetch(`/api/tickets/${ticket.thread_ts}/notes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ note: noteText.trim() }),
      });
      noteText = '';
      notes = await api<typeof notes>(`/api/tickets/${ticket.thread_ts}/notes`);
    } catch (e) { /* */ }
    noteSending = false;
  }

  onMount(() => {
    setTimeout(() => {
      const el = document.getElementById('msgList');
      if (el) el.scrollTop = el.scrollHeight;
    }, 100);
  });
</script>

<svelte:head><title>{ticket ? `Ticket #${ticket.ticket_number}` : 'Loading...'} — Support</title></svelte:head>

{#if !ticket}
  <div class="empty">Loading...</div>
{:else}
  <a href="/dashboard" class="back">&larr; Back to Dashboard</a>

  <div class="header">
    <div class="info">
      <div class="tnum">#{ticket.ticket_number} <span class="badge {ticket.status}">{ticket.status}</span></div>
      <div class="meta">Created {fmt(ticket.created_at)} by {@html esc(ticket.user_name || ticket.user_id)}</div>
      {#if ticket.resolved_at}
        <div class="meta">Resolved {fmt(ticket.resolved_at)} by {@html esc(ticket.resolved_by || '')}</div>
      {/if}
    </div>
    <button class="action-btn {ticket.status}" onclick={toggleStatus}>
      {ticket.status === 'open' ? 'Resolve' : 'Reopen'}
    </button>
  </div>

  {#if ticket.status === 'open'}
  <div class="assign-row">
    <select bind:value={assignId} class="assign-select">
      <option value="">Assign to...</option>
      {#each team as m}
        <option value={m.user_id}>{m.name}</option>
      {/each}
    </select>
    <button class="assign-btn" onclick={assign} disabled={!assignId}>Assign</button>
  </div>
  {/if}

  <div class="thread-list" id="msgList">
    {#if msgsLoading}
      <div class="empty-inner">Loading messages from Slack...</div>
    {:else if messages.length === 0}
      <div class="empty-inner">No messages yet.</div>
    {:else}
      {#each messages as m}
        <div class="msg">
          <div class="author">{m.isBot ? 'Bot' : m.user} <span class="time">{fmt(m.ts)}</span></div>
          <div class="body">{@html esc(m.text || '')}</div>
        </div>
      {/each}
    {/if}
  </div>

  <div class="notes-section">
    <h3 class="notes-title">Internal Notes</h3>
    {#if notes.length === 0}
      <div class="notes-empty">No notes yet.</div>
    {:else}
      <div class="notes-list">
        {#each notes as n}
          <div class="note-item">
            <div class="note-author">{@html esc(n.author_name)} <span class="note-time">{fmt(n.created_at)}</span></div>
            <div class="note-body">{n.note}</div>
          </div>
        {/each}
      </div>
    {/if}
    <div class="note-input-row">
      <input type="text" bind:value={noteText} placeholder="Add internal note (not visible in Slack)..." onkeydown={(e) => e.key === 'Enter' && addInternalNote()}>
      <button class="note-btn" onclick={addInternalNote} disabled={noteSending || !noteText.trim()}>Add Note</button>
    </div>
  </div>

  <div class="send-box">
    <textarea
      bind:value={msgText}
      placeholder="Type a reply..."
      rows="2"
      onkeydown={onKeydown}
    ></textarea>
    <div class="send-actions">
      <label class="anon-label"><input type="checkbox" bind:checked={anon}> Anonymous</label>
      <button class="send-btn" onclick={send} disabled={sending}>{sending ? '...' : 'Send'}</button>
    </div>
  </div>
{/if}

<style>
  .header { background: rgba(255, 255, 255, 0.04); backdrop-filter: blur(4px); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; padding: 16px 20px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
  .info { display: flex; flex-direction: column; gap: 4px; }
  .tnum { font-size: 18px; font-weight: 700; }
  .meta { font-size: 13px; color: #888; }
  .badge { font-size: 13px; padding: 3px 10px; border-radius: 4px; font-weight: 600; }
  .badge.open { background: rgba(255, 255, 255, 0.1); }
  .badge.resolved { background: rgba(255, 255, 255, 0.04); color: #888; }
  .action-btn { padding: 8px 20px; border-radius: 4px; border: none; cursor: pointer; font-size: 14px; font-weight: 600; }
  .action-btn.open { background: rgba(255, 255, 255, 0.12); color: #fff; }
  .action-btn.open:hover { background: rgba(255, 255, 255, 0.2); }
  .action-btn.resolved { background: rgba(255, 255, 255, 0.06); color: #ccc; border: 1px solid rgba(255, 255, 255, 0.12); }
  .action-btn.resolved:hover { background: rgba(255, 255, 255, 0.15); }
  .thread-list { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 8px; padding: 16px; margin-bottom: 20px; max-height: 500px; overflow-y: auto; }
  .msg { padding: 10px 12px; margin-bottom: 6px; border-radius: 6px; background: rgba(255, 255, 255, 0.04); line-height: 1.5; }
  .msg .author { font-weight: 700; color: #ccc; font-size: 13px; margin-bottom: 3px; }
  .msg .time { font-weight: 400; color: #555; font-size: 11px; margin-left: 8px; }
  .msg .body { white-space: pre-wrap; word-break: break-word; color: #fff; font-size: 14px; }
  .send-box { display: flex; gap: 10px; align-items: flex-start; background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 8px; padding: 16px; }
  .send-box textarea { flex: 1; background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.1); color: #fff; padding: 10px; border-radius: 6px; font-size: 14px; resize: vertical; min-height: 48px; font-family: inherit; }
  .send-box textarea:focus { outline: 0; border-color: rgba(255, 255, 255, 0.2); }
  .send-actions { display: flex; flex-direction: column; gap: 8px; align-items: center; }
  .anon-label { display: flex; align-items: center; gap: 4px; font-size: 12px; color: #888; cursor: pointer; white-space: nowrap; }
  .send-btn { background: rgba(255, 255, 255, 0.12); color: #fff; border: none; padding: 8px 20px; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 700; }
  .send-btn:hover { background: rgba(255, 255, 255, 0.2); }
  .send-btn:disabled { opacity: 0.4; cursor: default; }
  .empty, .empty-inner { color: #555; padding: 24px; text-align: center; }
  .back { color: #aaa; text-decoration: none; font-size: 13px; display: inline-block; margin-bottom: 12px; }
  .back:hover { color: #fff; }
  .assign-row { display: flex; gap: 8px; margin-bottom: 16px; align-items: center; }
  .assign-select { background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 6px 10px; border-radius: 4px; font-size: 13px; font-family: inherit; }
  .assign-select option { background: #1a1a2e; color: #fff; }
  .assign-btn { background: rgba(255,255,255,0.1); color: #fff; border: 1px solid rgba(255,255,255,0.15); padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 13px; }
  .assign-btn:hover:not(:disabled) { background: rgba(255,255,255,0.18); }
  .assign-btn:disabled { opacity: 0.3; cursor: default; }
  .notes-section { background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.05); border-radius: 8px; padding: 16px; margin-bottom: 20px; }
  .notes-title { font-size: 14px; color: #aaa; margin-bottom: 12px; }
  .notes-empty { color: #555; padding: 12px 0; font-size: 13px; text-align: center; }
  .notes-list { max-height: 250px; overflow-y: auto; margin-bottom: 12px; }
  .note-item { padding: 8px 10px; margin-bottom: 4px; border-radius: 4px; background: rgba(255,255,255,0.03); }
  .note-author { font-size: 12px; color: #888; margin-bottom: 2px; }
  .note-time { font-weight: 400; color: #555; font-size: 11px; margin-left: 6px; }
  .note-body { font-size: 13px; color: #ccc; white-space: pre-wrap; word-break: break-word; }
  .note-input-row { display: flex; gap: 8px; }
  .note-input-row input { flex: 1; background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.1); color: #fff; padding: 8px 10px; border-radius: 4px; font-size: 13px; font-family: inherit; }
  .note-input-row input:focus { outline: 0; border-color: rgba(255,255,255,0.2); }
  .note-btn { background: rgba(255,255,255,0.08); color: #ccc; border: 1px solid rgba(255,255,255,0.12); padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 12px; }
  .note-btn:hover:not(:disabled) { background: rgba(255,255,255,0.15); }
  .note-btn:disabled { opacity: 0.3; cursor: default; }
</style>
