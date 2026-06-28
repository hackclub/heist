<script lang="ts">
	let email = $state('');
	let joined = $state(false);

	const joinOperation = () => {
		joined = true;
	};
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

<main class="heist-landing">
	<div class="heist-landing__grid" aria-hidden="true"></div>
	<img class="heist-landing__ellipse" src="/landing/dark-layer.png" alt="" aria-hidden="true" />
	<div class="heist-landing__inner">
		<section class="heist-hero" aria-labelledby="heist-title">
			<h1 id="heist-title" class="heist-title">
				<span class="visually-hidden">THE HEIST</span>
				<img class="heist-title__img" src="/landing/heist-title.svg" alt="" aria-hidden="true" />
			</h1>

			<p class="heist-tagline">
				<span>Work on <span class="heist-tagline__accent">personal projects</span></span>
				<span>Rob the vault with others and...</span>
				<span>Get <span class="heist-tagline__accent">prizes!</span></span>
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
					class="heist-join__input"
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

	.heist-landing__grid {
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

	.heist-landing__ellipse {
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

	.heist-landing__inner {
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

	.heist-title__img {
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

	.heist-tagline__accent {
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

	.heist-join__input {
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

		.heist-join__input::placeholder {
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

	@media (max-width: 899px) {
		.heist-landing__inner {
			padding-top: clamp(4rem, 12vh, 6rem);
		}

		.heist-title {
			width: min(34rem, 88vw);
		}
	}

	@media (max-width: 640px) {
		.hackclub-flag {
			left: 6px;
		}

		.hackclub-flag img {
			width: clamp(7rem, 34vw, 9rem);
		}

		.heist-landing__inner {
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
	}
</style>
