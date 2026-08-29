<script lang="ts">
  import { checkAuth, isAuthed } from '$lib/api';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';

  onMount(async () => {
    const ok = await checkAuth();
    if (ok) goto('/dashboard');
  });
</script>

<svelte:head>
  <title>Support — Login</title>
</svelte:head>

<div class="center">
  <div class="box">
    <h1>Support Dashboard</h1>
    <p>Sign in with your Hack Club account</p>
    <a href="/auth/hc" class="btn">Login with Hack Club</a>
  </div>
</div>

<style>
  .center {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 80vh;
  }
  .box {
    background: rgba(255, 255, 255, 0.03);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 40px 50px;
    text-align: center;
    max-width: 400px;
    width: 90%;
  }
  .box h1 { font-size: 22px; margin-bottom: 8px; }
  .box p { color: #888; font-size: 14px; margin-bottom: 24px; }
  .btn {
    display: inline-block;
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
    border: 1px solid rgba(255, 255, 255, 0.15);
    padding: 12px 32px;
    border-radius: 6px;
    font-size: 15px;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    transition: all .15s;
  }
  .btn:hover { background: rgba(255, 255, 255, 0.18); }
</style>
