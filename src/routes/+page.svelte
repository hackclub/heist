<script lang="ts">
	import { onMount } from 'svelte';

	let email = $state('');
	let joined = $state(false);
	let showScrolledHeader = $state(false);

	const revealStep = (node: HTMLElement) => {
		if (!('IntersectionObserver' in window)) {
			node.classList.add('heist-step--visible');
			return;
		}

		const observer = new IntersectionObserver(
			([entry]) => {
				if (!entry?.isIntersecting) return;

				node.classList.add('heist-step--visible');
				observer.disconnect();
			},
			{
				rootMargin: '0px 0px -18% 0px',
				threshold: 0.28
			}
		);

		observer.observe(node);

		return {
			destroy() {
				observer.disconnect();
			}
		};
	};

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

	const steps = [
		{
			title: 'Join the stream',
			copy: 'Tune into the live streams throughout the weekend and build alongside everyone else in the operation.',
			image: '/landing/steps/1.png'
		},
		{
			title: 'Start a project',
			copy: 'Make anything you want: hardware, software, a tiny tool, a strange experiment, or the thing you have been meaning to ship.',
			image: '/landing/steps/2.png'
		},
		{
			title: 'Hit 1,000 hrs together',
			copy: 'Every hour of real making adds to the shared goal. The crew wins by collectively shipping 1,000 hours.',
			image: '/landing/steps/3.png'
		},
		{
			title: 'Steal the prizes',
			copy: 'Redeem rewards once the vault opens, from useful gear to odd little treasures worth bragging about.',
			image: '/landing/steps/4.png'
		}
	];

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

<div class="heist-coins-separator" aria-hidden="true">
	<img src="/landing/coins-separator.png" alt="" />
</div>

<section class="heist-steps" aria-labelledby="heist-steps-title">
	<div class="heist-steps-inner">
		<div class="heist-steps-intro">
			<p class="heist-steps-kicker">How it works</p>
			<h2 id="heist-steps-title" class="heist-steps-title">
				<span class="visually-hidden">The plan</span>
				<img src="/landing/the-plan.svg" alt="" aria-hidden="true" />
			</h2>
		</div>

		<div class="heist-steps-list">
			{#each steps as step, index}
				<article use:revealStep class:heist-step--reversed={index % 2 === 1} class="heist-step">
					<div class="heist-step-copy">
						<span class="heist-step-number">{String(index + 1).padStart(2, '0')}</span>
						<h3>{step.title}</h3>
						<p>{step.copy}</p>
					</div>

					<figure class="heist-step-art">
						<div class="heist-step-image-mask">
							<img src={step.image} alt="" aria-hidden="true" loading="lazy" />
						</div>
					</figure>
				</article>
			{/each}
		</div>
	</div>
</section>

<footer class="heist-footer">
	<div class="heist-footer-glow" aria-hidden="true"></div>
	<div class="heist-footer-inner">
		<div class="heist-footer-content">
			<h2 class="heist-footer-title">Join in now!</h2>

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
		background: transparent;
		opacity: 0;
		pointer-events: none;
		transform: translateY(-0.9rem);
		transition:
			opacity 160ms ease,
			transform 160ms ease;
	}

	.heist-scrolled-header::before,
	.heist-scrolled-header::after {
		display: none;
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

	.heist-coins-separator {
		position: relative;
		z-index: 2;
		height: clamp(7rem, 16.67vw, 16rem);
		margin-top: clamp(-12rem, -13vw, -6rem);
		margin-bottom: clamp(-6rem, -6vw, -2.5rem);
		overflow: hidden;
		pointer-events: none;
	}

	.heist-coins-separator img {
		display: block;
		width: 100%;
		height: 100%;
		object-fit: cover;
		object-position: center;
		user-select: none;
		-webkit-user-drag: none;
	}

	.heist-steps {
		--heist-grid: rgba(222, 195, 95, 0.05);
		--heist-grid-major: rgba(222, 195, 95, 0.12);
		position: relative;
		overflow: hidden;
		color: #dafbac;
		background:
			linear-gradient(135deg, rgba(222, 195, 95, 0.07) 0 1px, transparent 1px 18px),
			linear-gradient(to right, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to right, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid) 1px, transparent 1px),
			radial-gradient(ellipse 42rem 22rem at 18% 22%, rgba(222, 195, 95, 0.16), rgba(7, 20, 14, 0) 72%),
			linear-gradient(180deg, rgba(43, 36, 17, 0.98) 0%, rgba(14, 29, 17, 0.98) 48%, rgba(8, 20, 14, 1) 100%);
		background-size:
			24px 24px,
			233.57px 233.57px,
			233.57px 233.57px,
			46.71px 46.71px,
			46.71px 46.71px,
			auto,
			auto;
	}

	.heist-steps::before,
	.heist-steps::after {
		position: absolute;
		left: 0;
		z-index: 1;
		width: 100%;
		content: '';
		pointer-events: none;
	}

	.heist-steps::before {
		top: 0;
		height: clamp(7rem, 14vw, 12rem);
		background: linear-gradient(to bottom, rgba(18, 42, 23, 0.55), rgba(43, 36, 17, 0));
	}

	.heist-steps::after {
		bottom: 0;
		height: clamp(12rem, 20vw, 18rem);
		background:
			linear-gradient(to bottom, rgba(17, 31, 17, 0), rgba(17, 31, 17, 0.82)),
			linear-gradient(135deg, transparent 0 1px, rgba(222, 195, 95, 0.045) 1px 2px, transparent 2px 18px);
	}

	.heist-steps-inner {
		position: relative;
		z-index: 2;
		width: min(100%, 78rem);
		margin: 0 auto;
		padding: clamp(10rem, 17vw, 15rem) clamp(1.25rem, 4vw, 2.5rem) clamp(7rem, 12vw, 10rem);
	}

	.heist-steps-intro {
		display: flex;
		align-items: end;
		justify-content: space-between;
		gap: 2rem;
		margin-bottom: clamp(3.5rem, 7vw, 5.5rem);
		border-bottom: 1px solid rgba(218, 251, 172, 0.24);
		padding-bottom: 1.35rem;
	}

	.heist-steps-kicker {
		margin: 0;
		color: rgba(255, 229, 114, 0.8);
		font-size: clamp(0.9rem, 1.8vw, 1.1rem);
		letter-spacing: 0.08em;
		text-transform: uppercase;
	}

	.heist-steps-title {
		width: min(100%, clamp(13rem, 25vw, 18rem));
		margin: 0;
		line-height: 0;
	}

	.heist-steps-title img {
		display: block;
		width: 100%;
		height: auto;
		user-select: none;
		-webkit-user-drag: none;
	}

	.heist-steps-list {
		display: flex;
		flex-direction: column;
		gap: clamp(4rem, 9vw, 7.5rem);
	}

	.heist-step {
		display: grid;
		grid-template-columns: minmax(16rem, 0.72fr) minmax(0, 1.28fr);
		gap: clamp(1.5rem, 5vw, 4rem);
		align-items: center;
	}

	.heist-step--reversed {
		grid-template-columns: minmax(0, 1.28fr) minmax(16rem, 0.72fr);
	}

	.heist-step--reversed .heist-step-copy {
		grid-column: 2;
		grid-row: 1;
	}

	.heist-step--reversed .heist-step-art {
		grid-column: 1;
		grid-row: 1;
	}

	.heist-step-copy {
		position: relative;
		min-width: 0;
		padding: 1rem 0 1rem clamp(1rem, 2vw, 1.35rem);
		opacity: 0;
		transform: translateY(1.2rem);
		transition:
			opacity 520ms ease,
			transform 640ms cubic-bezier(0.16, 1, 0.3, 1);
	}

	.heist-step-number {
		display: inline-block;
		margin-bottom: 1.1rem;
		color: rgba(255, 229, 114, 0.82);
		font-size: 1rem;
		letter-spacing: 0.08em;
	}

	.heist-step-copy h3 {
		margin: 0;
		color: #dafbac;
		font-size: clamp(1.65rem, 3.4vw, 2.7rem);
		font-weight: 400;
		line-height: 0.98;
	}

	.heist-step-copy p {
		max-width: 28rem;
		margin: 1.1rem 0 0;
		color: rgba(218, 251, 172, 0.78);
		font-size: clamp(0.95rem, 1.8vw, 1.12rem);
		line-height: 1.35;
	}

	.heist-step-art {
		position: relative;
		overflow: hidden;
		margin: 0;
		background: rgba(7, 20, 14, 0.16);
		box-shadow: 0 1.1rem 2.4rem rgba(0, 0, 0, 0.16);
	}

	.heist-step-art::before,
	.heist-step-art::after {
		position: absolute;
		width: 1.45rem;
		height: 1.45rem;
		border-color: rgba(218, 251, 172, 0.82);
		content: '';
		opacity: 0;
		pointer-events: none;
		transition:
			opacity 360ms ease 120ms,
			left 1250ms cubic-bezier(0.16, 1, 0.3, 1) 160ms,
			right 1250ms cubic-bezier(0.16, 1, 0.3, 1) 160ms;
		will-change: left, right, opacity;
		z-index: 1;
	}

	.heist-step-art::before {
		top: 0;
		left: 50%;
		border-top: 3px solid;
		border-left: 3px solid;
	}

	.heist-step-art::after {
		right: 50%;
		bottom: 0;
		border-right: 3px solid;
		border-bottom: 3px solid;
	}

	.heist-step-image-mask {
		overflow: hidden;
		clip-path: inset(0 50% 0 50%);
		transition: clip-path 1250ms cubic-bezier(0.16, 1, 0.3, 1) 160ms;
		will-change: clip-path;
	}

	.heist-step-image-mask img {
		display: block;
		width: 100%;
		height: auto;
		aspect-ratio: 900 / 520;
		object-fit: cover;
		opacity: 0;
		transform: scale(1.018);
		transition:
			opacity 420ms ease 260ms,
			transform 1250ms cubic-bezier(0.16, 1, 0.3, 1) 160ms;
		user-select: none;
		-webkit-user-drag: none;
		will-change: transform, opacity;
	}

	:global(.heist-step--visible) .heist-step-copy,
	:global(.heist-step--visible) .heist-step-image-mask img {
		opacity: 1;
		transform: none;
	}

	:global(.heist-step--visible) .heist-step-art::before,
	:global(.heist-step--visible) .heist-step-art::after {
		opacity: 1;
	}

	:global(.heist-step--visible) .heist-step-art::before {
		left: 0;
	}

	:global(.heist-step--visible) .heist-step-art::after {
		right: 0;
	}

	:global(.heist-step--visible) .heist-step-image-mask {
		clip-path: inset(0);
	}

	@media (prefers-reduced-motion: reduce) {
		.heist-step-copy,
		.heist-step-art,
		.heist-step-art::before,
		.heist-step-art::after,
		.heist-step-image-mask,
		.heist-step-image-mask img {
			transition: none;
		}

		.heist-step-copy,
		.heist-step-image-mask img,
		.heist-step-art::before,
		.heist-step-art::after {
			opacity: 1;
			transform: none;
		}

		.heist-step-art {
			clip-path: none;
			transform: none;
		}

		.heist-step-image-mask {
			clip-path: none;
		}
	}

	.heist-footer {
		--heist-grid: rgba(192, 244, 118, 0.032);
		--heist-grid-major: rgba(222, 195, 95, 0.07);
		--heist-lime: #c0f476;
		--heist-lime-soft: #dafbac;
		--heist-green: #dafbac;
		--heist-amber: #dec35f;
		position: relative;
		overflow: hidden;
		min-height: 0;
		margin-top: -1px;
		color: var(--heist-green);
		background:
			linear-gradient(to right, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid-major) 1px, transparent 1px),
			linear-gradient(to right, var(--heist-grid) 1px, transparent 1px),
			linear-gradient(to bottom, var(--heist-grid) 1px, transparent 1px),
			radial-gradient(ellipse 42rem 22rem at 86% 20%, rgba(222, 195, 95, 0.09), rgba(7, 18, 13, 0) 72%),
			linear-gradient(180deg, rgba(17, 31, 17, 0.98) 0%, rgba(12, 26, 16, 1) 34%, rgba(5, 14, 11, 1) 100%),
			linear-gradient(90deg, rgba(9, 20, 14, 1) 0%, rgba(12, 24, 15, 1) 44%, rgba(5, 14, 11, 1) 100%);
		background-size:
			233.57px 233.57px,
			233.57px 233.57px,
			46.71px 46.71px,
			46.71px 46.71px,
			auto,
			auto;
	}

	.heist-footer::before {
		position: absolute;
		inset: 0;
		background:
			repeating-linear-gradient(to bottom, rgba(218, 251, 172, 0.03) 0 1px, transparent 1px 7px),
			repeating-linear-gradient(
				to right,
				transparent 0 7.75rem,
				rgba(218, 251, 172, 0.04) 7.75rem 7.82rem,
				transparent 7.82rem 10.5rem
			),
			linear-gradient(to bottom, rgba(222, 195, 95, 0.035) 0%, transparent 18rem);
		content: '';
		mask-image: linear-gradient(to bottom, transparent 0, rgba(0, 0, 0, 0.15) 5rem, #000 14rem);
		pointer-events: none;
	}

	.heist-footer::after {
		position: absolute;
		inset: 0;
		background:
			linear-gradient(to bottom, transparent 0%, rgba(5, 14, 11, 0.22) 100%),
			linear-gradient(to right, rgba(5, 14, 11, 0.22), transparent 22%, transparent 76%, rgba(5, 14, 11, 0.28));
		content: '';
		pointer-events: none;
	}

	.heist-footer img {
		user-select: none;
		pointer-events: none;
		-webkit-user-drag: none;
	}

	.heist-footer-glow {
		position: absolute;
		z-index: 1;
		inset: auto auto -16rem -10rem;
		width: 46rem;
		height: 36rem;
		border-radius: 50%;
		background: radial-gradient(circle, rgba(192, 244, 118, 0.1), rgba(14, 35, 20, 0) 68%);
		filter: blur(6px);
		pointer-events: none;
	}

	.heist-footer-inner {
		position: relative;
		z-index: 2;
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(22rem, 36rem);
		gap: clamp(2rem, 7vw, 6rem);
		width: min(100%, 78rem);
		margin: 0 auto;
		padding: clamp(2rem, 4.5vh, 3.25rem) clamp(1.25rem, 4vw, 2.5rem) clamp(3rem, 8vh, 5rem);
		align-items: center;
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

	.heist-footer-links {
		display: grid;
		grid-template-columns: repeat(2, minmax(8rem, 1fr));
		gap: clamp(2rem, 5vw, 4rem);
	}

	.heist-footer-link-group h3 {
		margin: 0 0 1.45rem;
		color: var(--heist-yellow);
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
		color: var(--heist-lime-soft);
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
		.heist-steps-inner {
			padding-top: 10rem;
		}

		.heist-steps-intro {
			display: block;
		}

		.heist-steps-title {
			margin-top: 0.75rem;
			width: min(100%, clamp(12rem, 45vw, 16rem));
		}

		.heist-step,
		.heist-step--reversed {
			grid-template-columns: 1fr;
			gap: 1.5rem;
		}

		.heist-step--reversed .heist-step-copy,
		.heist-step--reversed .heist-step-art {
			grid-column: auto;
			grid-row: auto;
		}

		.heist-step-copy {
			order: 1;
		}

		.heist-step-art {
			order: 2;
		}

		.heist-landing-inner {
			padding-top: clamp(4rem, 12vh, 6rem);
		}

		.heist-title {
			width: min(34rem, 88vw);
		}

		.heist-footer-inner {
			grid-template-columns: minmax(0, 1fr);
			gap: 3rem;
			padding-top: 3rem;
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
		.heist-coins-separator {
			height: 7rem;
			margin-top: -5.5rem;
			margin-bottom: -2.75rem;
		}

		.heist-steps-inner {
			padding: 7rem 1rem 5rem;
		}

		.heist-steps-list {
			gap: 3.5rem;
		}

		.heist-step-copy {
			padding-top: 0.75rem;
			padding-bottom: 0.75rem;
		}

		.heist-step-copy p {
			font-size: 0.92rem;
		}

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
			padding: 2.75rem 1rem 3rem;
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
			display: none;
		}
	}
</style>
