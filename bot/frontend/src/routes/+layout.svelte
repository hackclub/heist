<script lang="ts">
  import '../app.css';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';

  let userName = $state('');
  let isAuthed = $state(false);

  async function checkAuth() {
    try {
      const r = await fetch('/auth/me');
      if (r.ok) {
        const data = await r.json();
        userName = data.name || '';
        isAuthed = true;
        return true;
      }
    } catch (e) { /* */ }
    isAuthed = false;
    return false;
  }

  onMount(async () => {
    await checkAuth();
    if (!isAuthed && $page.url.pathname !== '/') {
      window.location.href = '/';
    }
  });
</script>

<div class="top">
  <a href="/dashboard" class="brand">Support</a>
  <nav>
    {#if isAuthed}
      <a href="/dashboard">Dashboard</a>
      <a href="/stats">Stats</a>
      <a href="/mine">My Tickets</a>
      <a href="/audit">Owner Tools</a>
      <span class="user">{userName || 'Loading...'}</span>
      <a href="/auth/logout">Logout</a>
    {:else}
      <a href="/">Login</a>
    {/if}
  </nav>
</div>

<main class="cont">
  <slot />
</main>

<style>
  .top {
    background: rgba(0, 0, 0, 0.9);
    padding: 12px 28px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    position: sticky;
    top: 0;
    z-index: 10;
  }
  .brand { font-size: 17px; color: #fff; font-weight: 600; text-decoration: none; }
  .brand:hover { color: #fff; }
  nav { display: flex; align-items: center; gap: 14px; }
  nav a { color: #aaa; text-decoration: none; font-size: 13px; }
  nav a:hover { color: #fff; }
  .user { font-size: 13px; color: #888; }
  .cont { max-width: 1000px; margin: 0 auto; padding: 24px; }
</style>
