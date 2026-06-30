<script lang="ts">
	import { onMount } from 'svelte';

	let email = $state('');
	let joined = $state(false);
	let showScrolledHeader = $state(false);

	const footerLinks = {
		'Hack Club': [
			{ label: 'Philosophy', href: 'https://hackclub.com/philosophy/' },
			{ label: 'Our Team & Board', href: 'https://hackclub.com/team/' },
			{ label: 'Branding', href: 'https://hackclub.com/brand/' },
			{ label: 'Donate', href: 'https://hackclub.com/donate/' }
		],
		Resources: [
			{ label: 'Community Events', href: 'https://hackclub.com/events/' },
			{ label: 'Jams', href: 'https://jams.hackclub.com/' },
			{ label: 'Workshops', href: 'https://workshops.hackclub.com/' },
			{ label: 'Code of Conduct', href: 'https://hackclub.com/conduct/' }
		]
	};

	const joinOperation = () => {
		joined = true;
	};

	onMount(() => {
		const updateScrolledHeader = () => {
			showScrolledHeader = window.scrollY >= window.innerHeight - 8;
		};

		updateScrolledHeader();
		window.addEventListener('scroll', updateScrolledHeader, { passive: true });
		window.addEventListener('resize', updateScrolledHeader);

		return () => {
			window.removeEventListener('scroll', updateScrolledHeader);
			window.removeEventListener('resize', updateScrolledHeader);
		};
	});
</script>

<svelte:head>
	<title>The Heist - 1,000 hours. One weekend.</title>
	<meta
		name="description"
		content="Join The Heist, a weekend Hack Club operation to build together for 1,000 hours."
	/>
</svelte:head>

<a class="hackclub-flag" href="https://hackclub.com/">
	<img src="https://assets.hackclub.com/flag-orpheus-top.svg" alt="Hack Club" />
</a>

<header class:heist-scrolled-header--visible={showScrolledHeader} class="heist-scrolled-header">
	<a class="heist-scrolled-header-brand" href="/" aria-label="The Heist home">
		<img src="/landing/logo-horiziontal.svg" alt="The Heist" />
	</a>
	<a class="heist-btn heist-btn--login" href="/login">Log in</a>
</header>

<main class="heist-landing">
	<div class="heist-landing-grid" aria-hidden="true"></div>
	<img class="heist-landing-ellipse" src="/landing/dark-layer.png" alt="" aria-hidden="true" />
	<div class="heist-landing-inner">
		<section class="heist-hero" aria-labelledby="heist-title">
			<h1 id="heist-title" class="heist-title">
				<span class="visually-hidden">THE HEIST</span>
				<img class="heist-title-img" src="/landing/heist-title.svg" alt="" aria-hidden="true" />
			</h1>

			<p class="heist-tagline">
				<span>Work on <span class="heist-tagline-accent">personal projects</span></span>
				<span>Rob the <span class="heist-tagline-accent">vault</span> with others and...</span>
				<span>Get <span class="heist-tagline-accent">prizes!</span></span>
			</p>

			<form
				class="heist-join"
				onsubmit={(event) => {
					event.preventDefault();
					joinOperation();
				}}
			>
				<label class="visually-hidden" for="email">Email</label>
				<input
					id="email"
					class="heist-join-input"
					type="email"
					bind:value={email}
					placeholder="burglar@hackclub.com"
					autocomplete="email"
					required
				/>
				<button class="heist-btn heist-btn--join" type="submit">Join</button>
			</form>

			{#if joined}
				<p class="heist-flash heist-flash--ok" role="status">
					You're in. We'll send the details when the heist begins.
				</p>
			{/if}
		</section>
	</div>
</main>

<footer class="heist-footer">
	<div class="heist-footer-glow" aria-hidden="true"></div>
	<div class="heist-footer-inner">
		<div class="heist-footer-content">
			<h2 class="heist-footer-title">Start Heisting now!</h2>

			<nav class="heist-footer-links" aria-label="Footer">
				{#each Object.entries(footerLinks) as [group, links]}
					<div class="heist-footer-link-group">
						<h3>{group}</h3>
						<ul>
							{#each links as link}
								<li><a href={link.href}>{link.label}</a></li>
							{/each}
						</ul>
					</div>
				{/each}
			</nav>
		</div>

		<div class="heist-footer-crts" aria-hidden="true">
			<img class="heist-footer-crt heist-footer-crt-counter" src="/landing/crt1.png" alt="" />
			<img class="heist-footer-crt heist-footer-crt-scene" src="/landing/crt2.png" alt="" />
			<img class="heist-footer-crt heist-footer-crt-stream" src="/landing/crt3.png" alt="" />
		</div>
	</div>
</footer>

<style>
	* {
		font-family: "Mode Seven", monospace;
	}

	:global(body) {
		margin: 0;
		background: #0a1309;
	}

	:global(button),
	:global(input) {
		font: inherit;
	}

	.heist-landing img {
		user-select: none;
		pointer-events: none;
		-webkit-user-drag: none;
	}

	.heist-scrolled-header {
		--heist-grid: rgba(92, 157, 91, 0.045);
		--heist-grid-major: rgba(105, 178, 101, 0.1);
		--heist-amber: #dec35f;
		--heist-ink: #14251c;
		position: fixed;
		top: 0;
		left: 0;
		z-index: 900;
		display: flex;
		width: 100%;
		min-height: 4.6rem;
		align-items: flex-start;
		justify-content: space-between;
		padding: 0.8rem 1.15rem 0.95rem 1.75rem;
		background:
			linear-gradient(to right, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to right, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(90deg, rgba(19, 43, 23, 0.98) 0%, rgba(13, 33, 21, 0.98) 42%, rgba(7, 20, 14, 0.98) 100%);
		background-size:
			233.57px 233.57px,
			233.57px 233.57px,
			46.71px 46.71px,
			46.71px 46.71px,
			auto;
		opacity: 0;
		pointer-events: none;
		transform: translateY(-0.9rem);
		transition:
			opacity 160ms ease,
			transform 160ms ease;
	}

	.heist-scrolled-header--visible {
		opacity: 1;
		pointer-events: auto;
		transform: translateY(0);
	}

	.heist-scrolled-header-brand {
		display: block;
		line-height: 0;
	}

	.heist-scrolled-header-brand img {
		display: block;
		width: clamp(14rem, 24vw, 19rem);
		height: auto;
		filter: drop-shadow(0 0 8px rgba(192, 244, 118, 0.35));
	}

	.hackclub-flag {
		position: absolute;
		top: 0;
		left: 10px;
		z-index: 999;
		display: block;
		line-height: 0;
	}

	.hackclub-flag img {
		display: block;
		width: clamp(9.5rem, 22vw, 16rem);
		height: auto;
		border: 0;
	}

	.heist-landing {
		--heist-bg: #102416;
		--heist-bg-2: #07140e;
		--heist-grid: rgba(92, 157, 91, 0.045);
		--heist-grid-major: rgba(105, 178, 101, 0.1);
		--heist-lime: #c0f476;
		--heist-lime-soft: #dafbac;
		--heist-green: #dafbac;
		--heist-amber: #dec35f;
		--heist-yellow: #ffe572;
		--heist-ink: #14251c;
		position: relative;
		min-height: 100vh;
		overflow-x: hidden;
		background:
			radial-gradient(ellipse 46rem 16rem at -7% 45%, rgba(78, 128, 59, 0.32) 0%, rgba(28, 67, 34, 0.2) 38%, rgba(7, 20, 14, 0) 76%),
			linear-gradient(90deg, rgba(19, 43, 23, 0.92) 0%, rgba(13, 33, 21, 0.95) 42%, var(--heist-bg-2) 100%);
		color: var(--heist-green);
		font-family: 'SFMono-Regular', Menlo, Monaco, Consolas, 'Liberation Mono', monospace;
	}

	.heist-landing-grid {
		position: absolute;
		inset: 0;
		opacity: 0.82;
		background-image:
			linear-gradient(to right, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to right, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid) 1px, transparent 1px);
		background-size:
			233.57px 233.57px,
			233.57px 233.57px,
			46.71px 46.71px,
			46.71px 46.71px;
		pointer-events: none;
	}

	.heist-landing-ellipse {
		position: absolute;
		top: 9%;
		left: -5%;
		z-index: 0;
		width: 42%;
		max-width: 600px;
		height: auto;
		opacity: 0.36;
		transform: scaleX(-1);
	}

	.heist-landing-inner {
		position: relative;
		display: flex;
		min-height: 100vh;
		width: min(100%, 70rem);
		margin: 0 auto;
		padding: clamp(3.5rem, 10vh, 5.5rem) 1.25rem 3rem;
		align-items: flex-start;
		justify-content: center;
	}

	.heist-hero {
		position: relative;
		display: flex;
		width: min(100%, 48rem);
		min-width: 0;
		flex-direction: column;
		align-items: center;
		padding-top: 0;
		text-align: center;
	}

	.heist-title {
		width: min(37rem, 64vw);
		max-width: 100%;
		margin: 0;
		line-height: 0;
	}

	.heist-title-img {
		display: block;
		width: 100%;
		height: auto;
	}

	.heist-tagline {
		display: flex;
		flex-direction: column;
		margin: clamp(2rem, 5vh, 2.75rem) 0 clamp(2.4rem, 6vh, 3rem);
		color: var(--heist-lime);
		font-size: clamp(1.65rem, 3vw, 2rem);
		line-height: 1;
		letter-spacing: 0.03em;
		text-shadow: 0 0 10px rgba(192, 244, 118, 0.3);
	}

	.heist-tagline-accent {
		color: var(--heist-amber);
		text-shadow: 0 0 10px rgba(222, 195, 95, 0.3);
	}

	.heist-join {
		display: flex;
		align-items: stretch;
		gap: 0.5rem;
		width: min(100%, 28rem);
		padding: 0.42rem;
		border: 2px solid var(--heist-lime-soft);
		border-radius: 3px;
		background: rgba(218, 251, 172, 0.06);
		box-shadow:
			0 0 0 1px rgba(218, 251, 172, 0.18),
			0 0 24px rgba(218, 251, 172, 0.26);
	}

	.heist-join-input {
		min-width: 0;
		flex: 1;
		padding: 0.34rem 1rem;
		border: none;
		outline: none;
			background: rgba(12, 27, 17, 0.2);
			color: var(--heist-lime);
			font-size: 1.35rem;
			letter-spacing: 0.02em;
		}

		.heist-join-input::placeholder {
			color: rgba(218, 251, 172, 0.44);
			text-decoration: underline;
			text-decoration-color: rgba(218, 251, 172, 0.44);
		}

	.heist-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		border: 0;
		cursor: pointer;
		text-transform: uppercase;
		transition:
			transform 120ms ease,
			filter 120ms ease;
	}

	.heist-btn:hover {
		filter: brightness(1.1);
	}

	.heist-btn:active {
		transform: translateY(1px);
	}

	.heist-btn--join {
		min-width: 5.4rem;
		padding: 0.4rem 1rem;
		border-radius: 2px;
		background: var(--heist-amber);
		color: var(--heist-ink);
		font-size: 1.2rem;
		box-shadow: 0 0 12px rgba(222, 195, 95, 0.35);
	}

	.heist-btn--login {
		min-width: 8.75rem;
		padding: 0.7rem 1.1rem;
		border-radius: 2px;
		background: var(--heist-amber);
		color: var(--heist-ink);
		font-size: 1.2rem;
		line-height: 1;
		text-decoration: none;
		box-shadow: 0 0 12px rgba(222, 195, 95, 0.26);
	}

	.heist-flash {
		max-width: 32rem;
		margin: 1.25rem 0 0;
		padding: 0.6rem 0.9rem;
		border-left: 2px solid var(--heist-lime);
		background: rgba(192, 244, 118, 0.08);
		color: var(--heist-lime);
		font-size: 0.95rem;
		letter-spacing: 0.02em;
	}

	.visually-hidden {
		position: absolute;
		width: 1px;
		height: 1px;
		overflow: hidden;
		clip: rect(0 0 0 0);
		white-space: nowrap;
	}

	button:focus-visible,
	input:focus-visible {
		outline: 2px solid var(--heist-lime);
		outline-offset: 4px;
	}

	.heist-footer {
		--heist-grid: rgba(92, 157, 91, 0.045);
		--heist-grid-major: rgba(105, 178, 101, 0.1);
		--heist-lime: #c0f476;
		--heist-lime-soft: #dafbac;
		--heist-green: #dafbac;
		--heist-amber: #dec35f;
		position: relative;
		overflow: hidden;
		min-height: min(100vh, 46rem);
		color: var(--heist-green);
		background:
			linear-gradient(to right, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to right, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid) 1px, transparent 1px),
			radial-gradient(ellipse 40rem 18rem at 18% 66%, rgba(91, 142, 62, 0.22), rgba(8, 22, 14, 0) 72%),
			linear-gradient(90deg, rgba(19, 43, 23, 0.97) 0%, rgba(13, 33, 21, 0.99) 42%, rgba(7, 20, 14, 1) 100%);
		background-size:
			233.57px 233.57px,
			233.57px 233.57px,
			46.71px 46.71px,
			46.71px 46.71px,
			auto,
			auto;
	}

	.heist-footer img {
		user-select: none;
		pointer-events: none;
		-webkit-user-drag: none;
	}

	.heist-footer-glow {
		position: absolute;
		inset: auto auto -16rem -10rem;
		width: 46rem;
		height: 36rem;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(124, 173, 82, 0.22), rgba(14, 35, 20, 0) 68%);
		filter: blur(6px);
		pointer-events: none;
	}

	.heist-footer-inner {
		position: relative;
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(22rem, 36rem);
		gap: clamp(2rem, 7vw, 6rem);
		width: min(100%, 78rem);
		min-height: inherit;
		margin: 0 auto;
		padding: clamp(5rem, 12vh, 8rem) clamp(1.25rem, 4vw, 2.5rem) clamp(3rem, 8vh, 5rem);
		align-items: end;
	}

	.heist-footer-content {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: clamp(2.25rem, 5vw, 3.5rem);
		min-width: 0;
	}

	.heist-footer-title {
		max-width: 42rem;
		margin: 0;
		color: var(--heist-lime);
		font-size: clamp(2.35rem, 5.5vw, 5rem);
		font-weight: 400;
		line-height: 0.92;
		letter-spacing: 0.01em;
		text-shadow:
			0 0 10px rgba(192, 244, 118, 0.34),
			0 0 30px rgba(192, 244, 118, 0.14);
	}

	.heist-footer-title span {
		color: var(--heist-lime);
	}

	.heist-footer-links {
		display: grid;
		grid-template-columns: repeat(2, minmax(8rem, 1fr));
		gap: clamp(2rem, 5vw, 4rem);
	}

	.heist-footer-link-group h3 {
		margin: 0 0 1.45rem;
		color: #ffffff;
		font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
		font-size: clamp(1.1rem, 2vw, 1.35rem);
		font-weight: 700;
		line-height: 1;
	}

	.heist-footer-link-group ul {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.heist-footer-link-group a {
		color: rgba(255, 255, 255, 0.92);
		font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
		font-size: 0.95rem;
		line-height: 1.1;
		text-decoration: none;
		transition:
			color 120ms ease,
			text-shadow 120ms ease;
	}

	.heist-footer-link-group a:hover {
		color: var(--heist-lime);
		text-shadow: 0 0 8px rgba(192, 244, 118, 0.32);
	}

	.heist-footer-crts {
		position: relative;
		width: min(100%, 36rem);
		min-height: 24rem;
		justify-self: end;
		filter: drop-shadow(0 2rem 3rem rgba(0, 0, 0, 0.38));
	}

	.heist-footer-crt {
		position: absolute;
		display: block;
		height: auto;
	}

	.heist-footer-crt-counter {
		top: 0;
		left: 1%;
		z-index: 1;
		width: 52%;
		opacity: 0.96;
		transform: rotate(-4deg);
	}

	.heist-footer-crt-scene {
		top: 1.75rem;
		right: 0;
		z-index: 2;
		width: 52%;
		transform: rotate(3deg);
	}

	.heist-footer-crt-stream {
		right: 6%;
		bottom: 0;
		z-index: 3;
		width: 78%;
	}

	@media (max-width: 899px) {
		.heist-landing-inner {
			padding-top: clamp(4rem, 12vh, 6rem);
		}

		.heist-title {
			width: min(34rem, 88vw);
		}

		.heist-footer-inner {
			grid-template-columns: minmax(0, 1fr);
			gap: 3rem;
			padding-top: 4.5rem;
		}

		.heist-footer-content {
			align-items: center;
			text-align: center;
		}

		.heist-footer-links {
			width: min(100%, 28rem);
			text-align: left;
		}

		.heist-footer-crts {
			width: min(100%, 32rem);
			min-height: 21rem;
			justify-self: center;
		}
	}

	@media (max-width: 640px) {
		.heist-scrolled-header {
			min-height: 3.85rem;
			padding: 0.65rem 0.7rem 0.8rem;
		}

		.heist-scrolled-header-brand img {
			width: clamp(10.5rem, 48vw, 13.5rem);
		}

		.heist-btn--login {
			min-width: 5.8rem;
			padding: 0.6rem 0.7rem;
			font-size: 0.92rem;
		}

		.hackclub-flag {
			left: 6px;
		}

		.hackclub-flag img {
			width: clamp(7rem, 34vw, 9rem);
		}

		.heist-landing-inner {
			padding-right: 0.75rem;
			padding-left: 0.75rem;
		}

		.heist-join {
			flex-direction: column;
		}

		.heist-tagline {
			font-size: clamp(1.15rem, 5.8vw, 1.45rem);
			line-height: 1.05;
		}

		.heist-footer {
			min-height: auto;
		}

		.heist-footer-inner {
			padding: 4rem 1rem 3rem;
		}

		.heist-footer-kicker {
			font-size: 0.72rem;
		}

		.heist-footer-title {
			font-size: clamp(2rem, 12vw, 3.35rem);
		}

		.heist-footer-links {
			grid-template-columns: 1fr 1fr;
			gap: 1.5rem;
		}

		.heist-footer-link-group h3 {
			margin-bottom: 1rem;
			font-size: 1rem;
		}

		.heist-footer-link-group a {
			font-size: 0.82rem;
		}

		.heist-footer-crts {
			min-height: 15rem;
		}
	}
</style>
