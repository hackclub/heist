<script lang="ts">
  import { onMount } from 'svelte';
  onMount(async () => {
    await fetch('/auth/logout');
    window.location.href = '/';
  });
</script>

<svelte:head><title>Logging out...</title></svelte:head>
<div class="empty">Logging out...</div>

<style>
  .empty { color: #555; padding: 60px; text-align: center; font-size: 14px; }
</style>
