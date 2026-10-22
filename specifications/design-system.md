<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>The Dump — Design System v1.0</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;0,9..40,800;0,9..40,900;1,9..40,400&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #FFFFFF;
    --bg-page: #F2F2F7;
    --surface: #F9F9F9;
    --surface-2: #F2F2F7;
    --surface-3: #E5E5EA;
    --border: #E5E5EA;
    --border-light: #ECECEC;
    --text-1: #1C1C1E;
    --text-2: #636366;
    --text-3: #8E8E93;
    --text-4: #AEAEB2;
    --text-5: #D1D1D6;
    --accent: #FF2D55;
    --accent-subtle: rgba(255, 45, 85, 0.08);
    --success: #34C759;
    --warning: #FF9500;
    --info: #007AFF;
    --purple: #5856D6;
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    background: var(--bg);
    color: var(--text-1);
    font-family: 'DM Sans', -apple-system, sans-serif;
    -webkit-font-smoothing: antialiased;
    line-height: 1.6;
  }

  /* ===== LAYOUT ===== */
  .doc-nav {
    position: fixed;
    top: 0;
    left: 0;
    width: 240px;
    height: 100vh;
    background: var(--bg);
    border-right: 1px solid var(--border);
    padding: 32px 24px;
    overflow-y: auto;
    z-index: 100;
  }
  .doc-nav h2 {
    font-size: 14px;
    font-weight: 800;
    letter-spacing: -0.3px;
    margin-bottom: 4px;
  }
  .doc-nav .version {
    font-size: 11px;
    color: var(--text-4);
    margin-bottom: 32px;
    font-family: 'Space Mono', monospace;
  }
  .doc-nav a {
    display: block;
    font-size: 13px;
    color: var(--text-3);
    text-decoration: none;
    padding: 6px 0;
    transition: color 0.15s;
  }
  .doc-nav a:hover { color: var(--text-1); }
  .doc-nav .nav-section {
    font-size: 10px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: var(--text-4);
    font-weight: 600;
    margin-top: 20px;
    margin-bottom: 8px;
  }

  .doc-main {
    margin-left: 240px;
    max-width: 960px;
    padding: 48px 48px 120px;
  }

  /* ===== SECTION STYLES ===== */
  .section {
    margin-bottom: 80px;
  }
  .section-label {
    font-size: 10px;
    letter-spacing: 3px;
    text-transform: uppercase;
    color: var(--text-4);
    font-weight: 600;
    margin-bottom: 8px;
  }
  .section h2 {
    font-size: 28px;
    font-weight: 900;
    letter-spacing: -1px;
    margin-bottom: 8px;
  }
  .section .section-desc {
    font-size: 15px;
    color: var(--text-2);
    margin-bottom: 32px;
    max-width: 600px;
    line-height: 1.6;
  }
  .section h3 {
    font-size: 16px;
    font-weight: 700;
    margin-bottom: 12px;
    margin-top: 40px;
  }
  .section h3:first-of-type { margin-top: 0; }

  .divider {
    border: none;
    border-top: 1px solid var(--border);
    margin: 0 0 80px;
  }

  /* ===== TOKENS TABLE ===== */
  .token-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 24px;
  }
  .token-table th {
    text-align: left;
    font-size: 10px;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    color: var(--text-4);
    font-weight: 600;
    padding: 8px 12px 8px 0;
    border-bottom: 1px solid var(--border);
  }
  .token-table td {
    padding: 10px 12px 10px 0;
    font-size: 13px;
    border-bottom: 1px solid var(--border-light);
    vertical-align: middle;
  }
  .token-table .token-name {
    font-family: 'Space Mono', monospace;
    font-size: 12px;
    color: var(--text-2);
  }
  .token-table .token-value {
    font-family: 'Space Mono', monospace;
    font-size: 12px;
    color: var(--text-3);
  }

  /* Color swatches */
  .color-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 12px;
    margin-bottom: 32px;
  }
  .color-card {
    border: 1px solid var(--border-light);
    border-radius: 12px;
    overflow: hidden;
  }
  .color-swatch {
    height: 64px;
  }
  .color-info {
    padding: 10px 12px;
  }
  .color-info .name {
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 2px;
  }
  .color-info .hex {
    font-size: 11px;
    font-family: 'Space Mono', monospace;
    color: var(--text-3);
  }
  .color-info .ios-name {
    font-size: 10px;
    font-family: 'Space Mono', monospace;
    color: var(--text-4);
    margin-top: 2px;
  }

  /* Typography samples */
  .type-sample {
    display: flex;
    align-items: baseline;
    gap: 32px;
    padding: 20px 0;
    border-bottom: 1px solid var(--border-light);
  }
  .type-meta {
    flex-shrink: 0;
    width: 200px;
  }
  .type-meta .label {
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 4px;
  }
  .type-meta .specs {
    font-size: 11px;
    font-family: 'Space Mono', monospace;
    color: var(--text-3);
    line-height: 1.5;
  }
  .type-preview {
    flex: 1;
    min-width: 0;
  }

  /* Spacing vis */
  .spacing-vis {
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
    align-items: flex-end;
    margin-bottom: 24px;
  }
  .spacing-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }
  .spacing-block {
    background: var(--accent-subtle);
    border: 1px solid rgba(255,45,85,0.15);
    border-radius: 3px;
  }
  .spacing-label {
    font-size: 10px;
    font-family: 'Space Mono', monospace;
    color: var(--text-3);
  }

  /* Component preview */
  .component-preview {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 32px;
    margin-bottom: 16px;
  }
  .component-preview.dark {
    background: #000;
    border-color: #333;
  }
  .component-note {
    font-size: 12px;
    color: var(--text-3);
    margin-bottom: 24px;
    line-height: 1.5;
  }

  /* Code blocks */
  .code-block {
    background: #1C1C1E;
    color: #E5E5EA;
    border-radius: 8px;
    padding: 16px 20px;
    font-family: 'Space Mono', monospace;
    font-size: 12px;
    line-height: 1.6;
    overflow-x: auto;
    margin-bottom: 16px;
  }
  .code-block .comment { color: #636366; }
  .code-block .key { color: #FF9500; }
  .code-block .value { color: #34C759; }
  .code-block .string { color: #FF2D55; }

  /* Implementation note */
  .impl-note {
    background: rgba(0, 122, 255, 0.06);
    border-left: 3px solid var(--info);
    padding: 16px 20px;
    border-radius: 0 8px 8px 0;
    margin-bottom: 24px;
  }
  .impl-note .impl-label {
    font-size: 10px;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    font-weight: 700;
    color: var(--info);
    margin-bottom: 6px;
  }
  .impl-note p {
    font-size: 13px;
    color: var(--text-2);
    line-height: 1.5;
  }

  .warning-note {
    background: rgba(255, 149, 0, 0.06);
    border-left: 3px solid var(--warning);
    padding: 16px 20px;
    border-radius: 0 8px 8px 0;
    margin-bottom: 24px;
  }
  .warning-note .impl-label {
    font-size: 10px;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    font-weight: 700;
    color: var(--warning);
    margin-bottom: 6px;
  }
  .warning-note p {
    font-size: 13px;
    color: var(--text-2);
    line-height: 1.5;
  }

  /* Radii vis */
  .radii-row {
    display: flex;
    gap: 20px;
    align-items: center;
    flex-wrap: wrap;
  }
  .radius-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }
  .radius-box {
    width: 64px;
    height: 64px;
    border: 2px solid var(--border);
    background: var(--surface);
  }

  /* Category icon examples */
  .cat-icon-grid {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 16px;
  }
  .cat-icon-example {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 16px;
    background: var(--surface);
    border: 1px solid var(--border-light);
    border-radius: 10px;
  }
  .cat-icon-circle {
    width: 38px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 17px;
  }
  .cat-icon-name {
    font-size: 14px;
    font-weight: 500;
  }

  /* Button examples */
  .btn-row {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    align-items: center;
    margin-bottom: 16px;
  }
  .btn {
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    font-family: 'DM Sans', sans-serif;
    cursor: pointer;
    border: none;
    transition: all 0.15s;
  }
  .btn-primary {
    background: var(--text-1);
    color: var(--bg);
  }
  .btn-secondary {
    background: var(--surface-2);
    color: var(--text-2);
    border: 1px solid var(--border);
  }
  .btn-accent {
    background: var(--accent);
    color: white;
  }
  .btn-ghost {
    background: transparent;
    color: var(--text-2);
    border: 1px solid var(--border);
  }
  .btn-sm {
    padding: 6px 14px;
    font-size: 13px;
  }

  /* Card examples */
  .example-card {
    background: var(--surface);
    border: 1px solid var(--border-light);
    border-radius: 12px;
    padding: 16px;
    max-width: 340px;
    margin-bottom: 12px;
  }
  .example-card-title {
    font-size: 15px;
    font-weight: 600;
    margin-bottom: 6px;
  }
  .example-card-preview {
    font-size: 13px;
    color: var(--text-3);
    line-height: 1.45;
    margin-bottom: 10px;
  }
  .example-card-footer {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .example-card-date {
    font-size: 11px;
    color: var(--text-4);
  }
  .example-card-tag {
    font-size: 10px;
    color: var(--text-2);
    background: var(--surface-3);
    padding: 2px 7px;
    border-radius: 4px;
    font-weight: 500;
  }

  /* Filter pills */
  .pill-row {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
  }
  .pill {
    padding: 6px 14px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 500;
    border: 1px solid var(--border);
    background: var(--surface-2);
    color: var(--text-2);
    cursor: pointer;
  }
  .pill.active {
    background: var(--text-1);
    color: var(--bg);
    border-color: var(--text-1);
  }

  /* Recent item example */
  .recent-example {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 13px 0;
    border-bottom: 1px solid var(--surface-2);
  }
  .recent-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .recent-info { flex: 1; }
  .recent-title-ex {
    font-size: 14px;
    font-weight: 500;
  }
  .recent-meta-ex {
    font-size: 11px;
    color: var(--text-4);
    margin-top: 2px;
  }
  .recent-cat-badge {
    font-size: 10px;
    color: var(--text-2);
    background: var(--surface-2);
    padding: 3px 8px;
    border-radius: 4px;
    font-weight: 500;
  }

  /* Dark mode section */
  .dark-preview-row {
    display: flex;
    gap: 16px;
    margin-bottom: 16px;
  }
  .dark-swatch-sm {
    flex: 1;
    padding: 16px;
    border-radius: 10px;
    font-size: 12px;
    font-family: 'Space Mono', monospace;
    text-align: center;
  }

  @media (max-width: 800px) {
    .doc-nav { display: none; }
    .doc-main { margin-left: 0; padding: 24px 20px 80px; }
    .type-sample { flex-direction: column; gap: 8px; }
    .type-meta { width: 100%; }
  }
</style>
</head>
<body>

<!-- NAV -->
<nav class="doc-nav">
  <h2>THE DUMP</h2>
  <div class="version">Design System v1.0</div>
  <div class="nav-section">Foundation</div>
  <a href="#principles">Principles</a>
  <a href="#color">Color</a>
  <a href="#typography">Typography</a>
  <a href="#spacing">Spacing</a>
  <a href="#radii">Corner Radius</a>
  <a href="#icons">Category Icons</a>
  <div class="nav-section">Components</div>
  <a href="#buttons">Buttons</a>
  <a href="#cards">Note Cards</a>
  <a href="#pills">Filter Pills</a>
  <a href="#recent">Recent Feed</a>
  <a href="#capture">Capture Cards</a>
  <a href="#search">Search Bar</a>
  <a href="#nav-bar">Tab Bar</a>
  <div class="nav-section">Modes</div>
  <a href="#dark-mode">Dark Mode</a>
  <div class="nav-section">Implementation</div>
  <a href="#ios-impl">iOS / Swift</a>
  <a href="#web-impl">Web / Vanilla JS</a>
  <a href="#emoji-impl">AI Emoji Assignment</a>
</nav>

<!-- MAIN -->
<div class="doc-main">

<!-- ===== HEADER ===== -->
<div class="section" style="margin-bottom: 48px;">
  <div class="section-label">Design System v1.0</div>
  <h1 style="font-size: 42px; font-weight: 900; letter-spacing: -2px; line-height: 1; margin-bottom: 12px;">THE DUMP</h1>
  <p style="font-size: 16px; color: var(--text-2); max-width: 550px; line-height: 1.6;">A design system built for confident, zero-friction capture. Bold typography, surgical color, generous space. Light mode default with dark mode toggle.</p>
</div>

<hr class="divider">

<!-- ===== PRINCIPLES ===== -->
<div class="section" id="principles">
  <div class="section-label">Foundation</div>
  <h2>Principles</h2>
  <p class="section-desc">Every design decision should pass through these four filters.</p>

  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
    <div style="padding: 20px; background: var(--surface); border: 1px solid var(--border-light); border-radius: 12px;">
      <div style="font-size: 13px; font-weight: 700; margin-bottom: 6px;">⚡ Zero-Friction Capture</div>
      <div style="font-size: 13px; color: var(--text-2); line-height: 1.5;">Every capture mode — voice, photo, text, file — is one tap from the home screen. No mode is subordinate to another. The user's context decides which to use.</div>
    </div>
    <div style="padding: 20px; background: var(--surface); border: 1px solid var(--border-light); border-radius: 12px;">
      <div style="font-size: 13px; font-weight: 700; margin-bottom: 6px;">✨ Show the Magic</div>
      <div style="font-size: 13px; color: var(--text-2); line-height: 1.5;">After every dump, show what the AI did. Processing states and category assignments in the Recent feed make the value immediately visible. This is the retention moment.</div>
    </div>
    <div style="padding: 20px; background: var(--surface); border: 1px solid var(--border-light); border-radius: 12px;">
      <div style="font-size: 13px; font-weight: 700; margin-bottom: 6px;">🏗 Confidence Through Restraint</div>
      <div style="font-size: 13px; color: var(--text-2); line-height: 1.5;">Bold type, surgical color, generous space. When everything is quiet, the one important thing pops. Accent color is reserved for primary CTAs and status indicators only.</div>
    </div>
    <div style="padding: 20px; background: var(--surface); border: 1px solid var(--border-light); border-radius: 12px;">
      <div style="font-size: 13px; font-weight: 700; margin-bottom: 6px;">🔍 Retrieval Builds Trust</div>
      <div style="font-size: 13px; color: var(--text-2); line-height: 1.5;">The Browse experience is where retention lives. Clean hierarchy, fast scanning, and clear AI-organized structure prove the dump was worth it.</div>
    </div>
  </div>
</div>

<hr class="divider">

<!-- ===== COLOR ===== -->
<div class="section" id="color">
  <div class="section-label">Foundation</div>
  <h2>Color</h2>
  <p class="section-desc">Light mode default. Black and white foundation with one surgical accent. Color is functional, not decorative.</p>

  <h3>Core Palette</h3>
  <div class="color-grid">
    <div class="color-card">
      <div class="color-swatch" style="background: #FFFFFF;"></div>
      <div class="color-info">
        <div class="name">Background</div>
        <div class="hex">#FFFFFF</div>
        <div class="ios-name">systemBackground</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #F9F9F9;"></div>
      <div class="color-info">
        <div class="name">Surface</div>
        <div class="hex">#F9F9F9</div>
        <div class="ios-name">cards, inputs</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #F2F2F7;"></div>
      <div class="color-info">
        <div class="name">Surface 2</div>
        <div class="hex">#F2F2F7</div>
        <div class="ios-name">secondarySystemBg</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #E5E5EA;"></div>
      <div class="color-info">
        <div class="name">Surface 3</div>
        <div class="hex">#E5E5EA</div>
        <div class="ios-name">separator</div>
      </div>
    </div>
  </div>

  <div class="color-grid">
    <div class="color-card">
      <div class="color-swatch" style="background: #1C1C1E;"></div>
      <div class="color-info">
        <div class="name">Text Primary</div>
        <div class="hex">#1C1C1E</div>
        <div class="ios-name">label</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #636366;"></div>
      <div class="color-info">
        <div class="name">Text Secondary</div>
        <div class="hex">#636366</div>
        <div class="ios-name">secondaryLabel</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #8E8E93;"></div>
      <div class="color-info">
        <div class="name">Text Tertiary</div>
        <div class="hex">#8E8E93</div>
        <div class="ios-name">tertiaryLabel</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #AEAEB2;"></div>
      <div class="color-info">
        <div class="name">Text Quaternary</div>
        <div class="hex">#AEAEB2</div>
        <div class="ios-name">quaternaryLabel</div>
      </div>
    </div>
  </div>

  <h3>Accent & Semantic</h3>
  <div class="color-grid">
    <div class="color-card">
      <div class="color-swatch" style="background: #FF2D55;"></div>
      <div class="color-info">
        <div class="name">Accent</div>
        <div class="hex">#FF2D55</div>
        <div class="ios-name">systemPink</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(255,45,85,0.08);"></div>
      <div class="color-info">
        <div class="name">Accent Subtle</div>
        <div class="hex">8% opacity</div>
        <div class="ios-name">accent @ 0.08</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #34C759;"></div>
      <div class="color-info">
        <div class="name">Success</div>
        <div class="hex">#34C759</div>
        <div class="ios-name">systemGreen</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #FF9500;"></div>
      <div class="color-info">
        <div class="name">Warning</div>
        <div class="hex">#FF9500</div>
        <div class="ios-name">systemOrange</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #007AFF;"></div>
      <div class="color-info">
        <div class="name">Info</div>
        <div class="hex">#007AFF</div>
        <div class="ios-name">systemBlue</div>
      </div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: #5856D6;"></div>
      <div class="color-info">
        <div class="name">Purple</div>
        <div class="hex">#5856D6</div>
        <div class="ios-name">systemIndigo</div>
      </div>
    </div>
  </div>

  <h3>Category Icon Tints</h3>
  <p class="component-note">Each category gets a tinted background for its emoji icon. Use 10% opacity of the base color. These map to the semantic colors above plus a few extras.</p>
  <div class="color-grid">
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(255,45,85,0.10);"></div>
      <div class="color-info"><div class="name">Tint Red</div><div class="hex">accent @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(255,149,0,0.10);"></div>
      <div class="color-info"><div class="name">Tint Orange</div><div class="hex">orange @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(0,122,255,0.10);"></div>
      <div class="color-info"><div class="name">Tint Blue</div><div class="hex">blue @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(52,199,89,0.10);"></div>
      <div class="color-info"><div class="name">Tint Green</div><div class="hex">green @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(88,86,214,0.10);"></div>
      <div class="color-info"><div class="name">Tint Indigo</div><div class="hex">indigo @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(175,82,222,0.10);"></div>
      <div class="color-info"><div class="name">Tint Purple</div><div class="hex">purple @ 10%</div></div>
    </div>
    <div class="color-card">
      <div class="color-swatch" style="background: rgba(255,204,0,0.10);"></div>
      <div class="color-info"><div class="name">Tint Yellow</div><div class="hex">yellow @ 10%</div></div>
    </div>
  </div>

  <div class="impl-note">
    <div class="impl-label">Implementation</div>
    <p>Assign tint colors by hashing the category name to an index in a 7-color array. This ensures the same category always gets the same tint without storing it. Both Swift and JS can use a simple hash function: <code>name.charCodeAt(0) % 7</code>.</p>
  </div>

  <h3>Accent Color Usage Rules</h3>
  <table class="token-table">
    <tr><th>Use accent for</th><th>Do NOT use accent for</th></tr>
    <tr><td>Primary CTA buttons (rare — 1 per screen max)</td><td>Section headers</td></tr>
    <tr><td>Processing/active status dots</td><td>Category list text</td></tr>
    <tr><td>Category badge on note detail screen</td><td>Navigation elements</td></tr>
    <tr><td>Destructive action confirmation</td><td>Body text emphasis</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== TYPOGRAPHY ===== -->
<div class="section" id="typography">
  <div class="section-label">Foundation</div>
  <h2>Typography</h2>
  <p class="section-desc">DM Sans for all text. Bold, confident headlines create the Nike energy. Clear hierarchy through weight and size contrast.</p>

  <div class="impl-note">
    <div class="impl-label">iOS</div>
    <p>Use the system font (SF Pro) on iOS to match platform conventions. DM Sans is the web font. The weights and sizes below apply to both — just swap the family. SF Pro's weight names map: Black = .heavy, Bold = .bold, Semibold = .semibold, Regular = .regular.</p>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Page Title</div>
      <div class="specs">
        Web: DM Sans 900<br>
        iOS: SF Pro Heavy<br>
        36px / -1.5px tracking<br>
        Line height: 1.0
      </div>
    </div>
    <div class="type-preview" style="font-size: 36px; font-weight: 900; letter-spacing: -1.5px; line-height: 1;">DUMP IT.</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Screen Title</div>
      <div class="specs">
        Web: DM Sans 900<br>
        iOS: SF Pro Heavy<br>
        34px / -1.5px tracking<br>
        Line height: 1.0
      </div>
    </div>
    <div class="type-preview" style="font-size: 34px; font-weight: 900; letter-spacing: -1.5px; line-height: 1;">Browse</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Section Title</div>
      <div class="specs">
        Web: DM Sans 900<br>
        iOS: SF Pro Bold<br>
        28px / -1px tracking<br>
        Line height: 1.1
      </div>
    </div>
    <div class="type-preview" style="font-size: 28px; font-weight: 900; letter-spacing: -1px; line-height: 1.1;">George Labs</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Note Title</div>
      <div class="specs">
        Web: DM Sans 800<br>
        iOS: SF Pro Bold<br>
        24px / -0.8px tracking<br>
        Line height: 1.15
      </div>
    </div>
    <div class="type-preview" style="font-size: 24px; font-weight: 800; letter-spacing: -0.8px; line-height: 1.15;">Afternoon Pickup and Work Plan</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Category Name</div>
      <div class="specs">
        Weight: 500 (Medium)<br>
        16px<br>
        Color: text-primary
      </div>
    </div>
    <div class="type-preview" style="font-size: 16px; font-weight: 500;">Business Ideas</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Card Title</div>
      <div class="specs">
        Weight: 600 (Semibold)<br>
        15px<br>
        Line height: 1.3
      </div>
    </div>
    <div class="type-preview" style="font-size: 15px; font-weight: 600; line-height: 1.3;">Extend Voice Note Duration Limit</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Body</div>
      <div class="specs">
        Weight: 400 (Regular)<br>
        15px<br>
        Line height: 1.7<br>
        Color: text-secondary
      </div>
    </div>
    <div class="type-preview" style="font-size: 15px; color: #48484A; line-height: 1.7;">I need to work out and eat lunch before then. I can have a turkey sandwich for lunch.</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Card Preview</div>
      <div class="specs">
        Weight: 400<br>
        13px<br>
        Line height: 1.45<br>
        Color: text-tertiary<br>
        Max 2 lines, ellipsis
      </div>
    </div>
    <div class="type-preview" style="font-size: 13px; color: var(--text-3); line-height: 1.45;">Schedule for the day. It's 12 now. I would like to pick Lily up at 3:15...</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Section Label</div>
      <div class="specs">
        Weight: 600<br>
        10px / 2px letter-spacing<br>
        UPPERCASE<br>
        Color: text-quaternary
      </div>
    </div>
    <div class="type-preview" style="font-size: 10px; letter-spacing: 2px; text-transform: uppercase; font-weight: 600; color: var(--text-4);">Categories</div>
  </div>

  <div class="type-sample">
    <div class="type-meta">
      <div class="label">Meta / Caption</div>
      <div class="specs">
        Weight: 400<br>
        11px<br>
        Color: text-quaternary
      </div>
    </div>
    <div class="type-preview" style="font-size: 11px; color: var(--text-4);">Feb 10, 2026 · Voice · Processing...</div>
  </div>

  <div class="type-sample" style="border-bottom: none;">
    <div class="type-meta">
      <div class="label">Monospace / Counts</div>
      <div class="specs">
        Space Mono 400<br>
        iOS: SF Mono<br>
        12px<br>
        Color: text-quaternary
      </div>
    </div>
    <div class="type-preview" style="font-size: 12px; color: var(--text-4); font-family: 'Space Mono', monospace;">214</div>
  </div>
</div>

<hr class="divider">

<!-- ===== SPACING ===== -->
<div class="section" id="spacing">
  <div class="section-label">Foundation</div>
  <h2>Spacing</h2>
  <p class="section-desc">8-point grid base. Every margin, padding, and gap must come from this scale. No exceptions.</p>

  <div class="spacing-vis">
    <div class="spacing-item">
      <div class="spacing-block" style="width: 4px; height: 4px;"></div>
      <span class="spacing-label">4</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 8px; height: 8px;"></div>
      <span class="spacing-label">8</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 12px; height: 12px;"></div>
      <span class="spacing-label">12</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 16px; height: 16px;"></div>
      <span class="spacing-label">16</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 24px; height: 24px;"></div>
      <span class="spacing-label">24</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 32px; height: 32px;"></div>
      <span class="spacing-label">32</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 48px; height: 48px;"></div>
      <span class="spacing-label">48</span>
    </div>
    <div class="spacing-item">
      <div class="spacing-block" style="width: 64px; height: 64px;"></div>
      <span class="spacing-label">64</span>
    </div>
  </div>

  <h3>Common Usage</h3>
  <table class="token-table">
    <tr><th>Context</th><th>Value</th><th>Token</th></tr>
    <tr><td>Screen horizontal padding</td><td class="token-value">24px</td><td class="token-name">space-lg</td></tr>
    <tr><td>Card internal padding</td><td class="token-value">16px</td><td class="token-name">space-md</td></tr>
    <tr><td>Gap between cards</td><td class="token-value">8px</td><td class="token-name">space-sm</td></tr>
    <tr><td>Capture grid gap</td><td class="token-value">10px</td><td class="token-name">~space-sm+</td></tr>
    <tr><td>Section label to content</td><td class="token-value">12px</td><td class="token-name">space-sm+</td></tr>
    <tr><td>Header bottom padding</td><td class="token-value">16–20px</td><td class="token-name">space-md</td></tr>
    <tr><td>Section to section</td><td class="token-value">28–32px</td><td class="token-name">space-xl</td></tr>
    <tr><td>Screen top padding (below status)</td><td class="token-value">28px</td><td class="token-name">~space-xl</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== CORNER RADIUS ===== -->
<div class="section" id="radii">
  <div class="section-label">Foundation</div>
  <h2>Corner Radius</h2>
  <p class="section-desc">Consistent radii create visual cohesion. Five values only.</p>

  <div class="radii-row" style="margin-bottom: 32px;">
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 4px;"></div>
      <span class="spacing-label">4px — tags</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 8px;"></div>
      <span class="spacing-label">8px — buttons</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 10px;"></div>
      <span class="spacing-label">10px — cat icons</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 12px;"></div>
      <span class="spacing-label">12px — cards</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 16px;"></div>
      <span class="spacing-label">16px — capture</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 20px;"></div>
      <span class="spacing-label">20px — pills</span>
    </div>
    <div class="radius-item">
      <div class="radius-box" style="border-radius: 50%;"></div>
      <span class="spacing-label">50% — circles</span>
    </div>
  </div>
</div>

<hr class="divider">

<!-- ===== CATEGORY ICONS ===== -->
<div class="section" id="icons">
  <div class="section-label">Foundation</div>
  <h2>Category Icons</h2>
  <p class="section-desc">AI assigns an emoji when creating a new category. Emoji + tinted background circle. Tint color derived from a hash of the category name.</p>

  <div class="cat-icon-grid">
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,149,0,0.10);">💡</div>
      <span class="cat-icon-name">Business Ideas</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(0,122,255,0.10);">💻</div>
      <span class="cat-icon-name">Coding Courses</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,45,85,0.08);">👨‍👩‍👧</div>
      <span class="cat-icon-name">Family</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,45,85,0.10);">🚀</div>
      <span class="cat-icon-name">George Labs</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(52,199,89,0.10);">🏠</div>
      <span class="cat-icon-name">Dreary Lane House</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,204,0,0.10);">📚</div>
      <span class="cat-icon-name">Learning</span>
    </div>
  </div>

  <h3>Icon Container Spec</h3>
  <table class="token-table">
    <tr><th>Property</th><th>Value</th></tr>
    <tr><td>Size</td><td class="token-value">38 × 38px</td></tr>
    <tr><td>Corner radius</td><td class="token-value">10px</td></tr>
    <tr><td>Emoji font size</td><td class="token-value">17px</td></tr>
    <tr><td>Background</td><td class="token-value">Tint color @ 10% opacity</td></tr>
    <tr><td>Alignment</td><td class="token-value">Center/center</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== BUTTONS ===== -->
<div class="section" id="buttons">
  <div class="section-label">Components</div>
  <h2>Buttons</h2>
  <p class="section-desc">Four variants. Primary (black) is the default. Accent (red) is used sparingly for the main CTA on the Dump screen only.</p>

  <div class="component-preview">
    <div class="btn-row" style="margin-bottom: 24px;">
      <button class="btn btn-primary">Edit</button>
      <button class="btn btn-secondary">Cancel</button>
      <button class="btn btn-ghost">Details</button>
      <button class="btn btn-accent">DUMP IT</button>
    </div>
    <div class="btn-row">
      <button class="btn btn-primary btn-sm">Edit</button>
      <button class="btn btn-secondary btn-sm">Cancel</button>
      <button class="btn btn-ghost btn-sm">ⓘ</button>
    </div>
  </div>

  <table class="token-table">
    <tr><th>Variant</th><th>Background</th><th>Text</th><th>Border</th><th>Use</th></tr>
    <tr><td>Primary</td><td class="token-value">#1C1C1E</td><td class="token-value">#FFFFFF</td><td class="token-value">none</td><td>Primary actions (Edit, Save)</td></tr>
    <tr><td>Secondary</td><td class="token-value">#F2F2F7</td><td class="token-value">#636366</td><td class="token-value">#E5E5EA</td><td>Secondary actions (Cancel)</td></tr>
    <tr><td>Ghost</td><td class="token-value">transparent</td><td class="token-value">#636366</td><td class="token-value">#E5E5EA</td><td>Tertiary actions (Details, Info)</td></tr>
    <tr><td>Accent</td><td class="token-value">#FF2D55</td><td class="token-value">#FFFFFF</td><td class="token-value">none</td><td>Primary CTA only (DUMP IT on web)</td></tr>
  </table>

  <h3>Button Spec</h3>
  <table class="token-table">
    <tr><th>Property</th><th>Default</th><th>Small</th></tr>
    <tr><td>Padding</td><td class="token-value">10px 20px</td><td class="token-value">6px 14px</td></tr>
    <tr><td>Font size</td><td class="token-value">14px</td><td class="token-value">13px</td></tr>
    <tr><td>Font weight</td><td class="token-value">600</td><td class="token-value">500</td></tr>
    <tr><td>Corner radius</td><td class="token-value">8px</td><td class="token-value">8px</td></tr>
    <tr><td>Min touch target</td><td class="token-value">44px height</td><td class="token-value">32px height</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== NOTE CARDS ===== -->
<div class="section" id="cards">
  <div class="section-label">Components</div>
  <h2>Note Cards</h2>
  <p class="section-desc">Used in category detail view. Consistent height via 2-line preview clamp.</p>

  <div class="component-preview">
    <div class="example-card">
      <div class="example-card-title">Afternoon pickup and work plan</div>
      <div class="example-card-preview">Schedule for the day. It's 12 now. I would like to pick Lily up at 3:15 (so leave here at 3)...</div>
      <div class="example-card-footer">
        <span class="example-card-date">Feb 10, 2026</span>
        <span class="example-card-tag">Schedule</span>
      </div>
    </div>
    <div class="example-card">
      <div style="display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 6px;">
        <span class="example-card-title" style="margin-bottom: 0;">Finalize Payments and App Release</span>
        <span style="font-size: 14px; opacity: 0.5; flex-shrink: 0; margin-left: 8px;">🎙</span>
      </div>
      <div class="example-card-preview">My plan for the train ride home: Get token tracking working and deployed...</div>
      <div class="example-card-footer">
        <span class="example-card-date">Feb 8, 2026</span>
        <span class="example-card-tag">Dev</span>
      </div>
    </div>
  </div>

  <table class="token-table">
    <tr><th>Property</th><th>Value</th></tr>
    <tr><td>Background</td><td class="token-value">#F9F9F9 (surface)</td></tr>
    <tr><td>Border</td><td class="token-value">1px solid #ECECEC</td></tr>
    <tr><td>Corner radius</td><td class="token-value">12px</td></tr>
    <tr><td>Padding</td><td class="token-value">16px</td></tr>
    <tr><td>Gap between cards</td><td class="token-value">8px</td></tr>
    <tr><td>Title</td><td class="token-value">15px / 600 weight</td></tr>
    <tr><td>Preview</td><td class="token-value">13px / 400 / text-tertiary / 2 lines max</td></tr>
    <tr><td>Date</td><td class="token-value">11px / text-quaternary</td></tr>
    <tr><td>Tag</td><td class="token-value">10px / 500 / #636366 on #ECECEC / 4px radius</td></tr>
    <tr><td>Media type icon</td><td class="token-value">14px emoji, 50% opacity, top-right</td></tr>
  </table>

  <div class="impl-note">
    <div class="impl-label">Media type indicators</div>
    <p>📝 = text note, 🎙 = voice note, 📷 = photo, 📄 = file upload. Show in top-right of card header at 50% opacity so it's visible but doesn't dominate.</p>
  </div>
</div>

<hr class="divider">

<!-- ===== FILTER PILLS ===== -->
<div class="section" id="pills">
  <div class="section-label">Components</div>
  <h2>Filter Pills</h2>
  <p class="section-desc">Horizontal scrollable row for filtering by media type within a category.</p>

  <div class="component-preview">
    <div class="pill-row">
      <span class="pill active">All</span>
      <span class="pill">Voice</span>
      <span class="pill">Text</span>
      <span class="pill">Photo</span>
      <span class="pill">File</span>
    </div>
  </div>

  <table class="token-table">
    <tr><th>Property</th><th>Inactive</th><th>Active</th></tr>
    <tr><td>Background</td><td class="token-value">#F2F2F7</td><td class="token-value">#1C1C1E</td></tr>
    <tr><td>Text color</td><td class="token-value">#636366</td><td class="token-value">#FFFFFF</td></tr>
    <tr><td>Border</td><td class="token-value">1px solid #E5E5EA</td><td class="token-value">1px solid #1C1C1E</td></tr>
    <tr><td>Font</td><td class="token-value" colspan="2">12px / 500 weight</td></tr>
    <tr><td>Padding</td><td class="token-value" colspan="2">6px 14px</td></tr>
    <tr><td>Corner radius</td><td class="token-value" colspan="2">20px</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== RECENT FEED ===== -->
<div class="section" id="recent">
  <div class="section-label">Components</div>
  <h2>Recent Feed</h2>
  <p class="section-desc">Shows on the Dump screen below capture cards. Displays recent dumps with processing status and AI-assigned category. This is the "magic moment" component.</p>

  <div class="component-preview">
    <div class="recent-example">
      <div class="recent-dot" style="background: #FF2D55; animation: pulse 1.5s infinite;"></div>
      <div class="recent-info">
        <div class="recent-title-ex">Voice note about meal prep ideas</div>
        <div class="recent-meta-ex">Just now · Voice · Processing...</div>
      </div>
    </div>
    <div class="recent-example">
      <div class="recent-dot" style="background: #34C759;"></div>
      <div class="recent-info">
        <div class="recent-title-ex">Afternoon pickup and work plan</div>
        <div class="recent-meta-ex">2 hours ago · Text</div>
      </div>
      <span class="recent-cat-badge">George Labs</span>
    </div>
    <div class="recent-example" style="border-bottom: none;">
      <div class="recent-dot" style="background: #34C759;"></div>
      <div class="recent-info">
        <div class="recent-title-ex">Screenshot of Etsy shop layout</div>
        <div class="recent-meta-ex">Yesterday · Photo</div>
      </div>
      <span class="recent-cat-badge">Dreary Lane House</span>
    </div>
  </div>

  <h3>Status Dot</h3>
  <table class="token-table">
    <tr><th>State</th><th>Color</th><th>Animation</th></tr>
    <tr><td>Processing</td><td class="token-value">#FF2D55 (accent)</td><td class="token-value">Pulse: opacity 1→0.4→1, 1.5s infinite</td></tr>
    <tr><td>Complete</td><td class="token-value">#34C759 (success)</td><td class="token-value">None</td></tr>
    <tr><td>Error</td><td class="token-value">#FF9500 (warning)</td><td class="token-value">None</td></tr>
  </table>

  <div class="warning-note">
    <div class="impl-label">Retention Critical</div>
    <p>The transition from "Processing..." to showing the category badge is the aha moment. Consider animating the badge appearance (fade in + slight slide) so the user notices the AI just categorized their dump. This is what makes people come back.</p>
  </div>
</div>

<hr class="divider">

<!-- ===== CAPTURE CARDS ===== -->
<div class="section" id="capture">
  <div class="section-label">Components</div>
  <h2>Capture Cards</h2>
  <p class="section-desc">2×2 grid on the Dump screen. Each card is an equal-weight entry point for a capture mode.</p>

  <table class="token-table">
    <tr><th>Property</th><th>Value</th></tr>
    <tr><td>Layout</td><td class="token-value">2-column grid, 10px gap</td></tr>
    <tr><td>Background</td><td class="token-value">#F9F9F9 (surface)</td></tr>
    <tr><td>Border</td><td class="token-value">1px solid #ECECEC</td></tr>
    <tr><td>Corner radius</td><td class="token-value">16px</td></tr>
    <tr><td>Padding</td><td class="token-value">22px 16px</td></tr>
    <tr><td>Alignment</td><td class="token-value">Center</td></tr>
    <tr><td>Icon container</td><td class="token-value">48px circle, tinted bg @ 10%</td></tr>
    <tr><td>Icon size</td><td class="token-value">22px emoji</td></tr>
    <tr><td>Label</td><td class="token-value">14px / 600 weight</td></tr>
    <tr><td>Sub-label</td><td class="token-value">11px / text-quaternary</td></tr>
    <tr><td>Active state</td><td class="token-value">scale(0.97) + bg shift to #F2F2F7</td></tr>
    <tr><td>Min touch target</td><td class="token-value">Entire card (~155 × 110px)</td></tr>
  </table>

  <h3>Capture Mode Mapping</h3>
  <table class="token-table">
    <tr><th>Mode</th><th>Emoji</th><th>Tint Base</th><th>Sub-label</th></tr>
    <tr><td>Voice</td><td>🎙</td><td class="token-value">#FF2D55 (accent)</td><td>Speak your mind</td></tr>
    <tr><td>Photo</td><td>📷</td><td class="token-value">#FF9500 (orange)</td><td>Snap & save</td></tr>
    <tr><td>Note</td><td>⌨</td><td class="token-value">#007AFF (blue)</td><td>Type it out</td></tr>
    <tr><td>File</td><td>📄</td><td class="token-value">#5856D6 (indigo)</td><td>Upload anything</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== SEARCH BAR ===== -->
<div class="section" id="search">
  <div class="section-label">Components</div>
  <h2>Search Bar</h2>

  <div class="component-preview">
    <div style="background: #F2F2F7; border: 1px solid #E5E5EA; border-radius: 12px; padding: 12px 16px; display: flex; align-items: center; gap: 8px; max-width: 340px;">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#AEAEB2" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
      <span style="color: #AEAEB2; font-size: 14px;">Search all notes</span>
    </div>
  </div>

  <table class="token-table">
    <tr><th>Property</th><th>Value</th></tr>
    <tr><td>Background</td><td class="token-value">#F2F2F7</td></tr>
    <tr><td>Border</td><td class="token-value">1px solid #E5E5EA</td></tr>
    <tr><td>Corner radius</td><td class="token-value">12px</td></tr>
    <tr><td>Padding</td><td class="token-value">12px 16px</td></tr>
    <tr><td>Icon</td><td class="token-value">16px magnifying glass, #AEAEB2</td></tr>
    <tr><td>Placeholder</td><td class="token-value">14px / #AEAEB2</td></tr>
    <tr><td>Horizontal margin</td><td class="token-value">24px (matches screen padding)</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== TAB BAR ===== -->
<div class="section" id="nav-bar">
  <div class="section-label">Components</div>
  <h2>Tab Bar</h2>
  <p class="section-desc">Floating pill-style tab bar with two tabs: Dump and Browse.</p>

  <table class="token-table">
    <tr><th>Property</th><th>Value</th></tr>
    <tr><td>Position</td><td class="token-value">Fixed bottom, centered</td></tr>
    <tr><td>Background fade</td><td class="token-value">Linear gradient: bg color 70% → transparent</td></tr>
    <tr><td>Container bg</td><td class="token-value">#F2F2F7 with 1px #E5E5EA border</td></tr>
    <tr><td>Container radius</td><td class="token-value">28px</td></tr>
    <tr><td>Container padding</td><td class="token-value">5px</td></tr>
    <tr><td>Tab padding</td><td class="token-value">8px 28px</td></tr>
    <tr><td>Tab radius</td><td class="token-value">22px</td></tr>
    <tr><td>Active tab bg</td><td class="token-value">#FFFFFF with subtle shadow</td></tr>
    <tr><td>Active text</td><td class="token-value">#1C1C1E</td></tr>
    <tr><td>Inactive text</td><td class="token-value">#AEAEB2</td></tr>
    <tr><td>Icon size</td><td class="token-value">22px</td></tr>
    <tr><td>Label</td><td class="token-value">11px / 500 weight</td></tr>
  </table>
</div>

<hr class="divider">

<!-- ===== DARK MODE ===== -->
<div class="section" id="dark-mode">
  <div class="section-label">Modes</div>
  <h2>Dark Mode</h2>
  <p class="section-desc">Toggle-able alternative. Same design system, inverted surfaces. Every light token maps to a dark counterpart.</p>

  <h3>Color Mapping</h3>
  <table class="token-table">
    <tr><th>Token</th><th>Light</th><th>Dark</th></tr>
    <tr><td>Background</td><td class="token-value">#FFFFFF</td><td class="token-value">#000000</td></tr>
    <tr><td>Surface</td><td class="token-value">#F9F9F9</td><td class="token-value">#111111</td></tr>
    <tr><td>Surface 2</td><td class="token-value">#F2F2F7</td><td class="token-value">#1A1A1A</td></tr>
    <tr><td>Surface 3</td><td class="token-value">#E5E5EA</td><td class="token-value">#222222</td></tr>
    <tr><td>Border</td><td class="token-value">#E5E5EA</td><td class="token-value">#2A2A2A</td></tr>
    <tr><td>Border Light</td><td class="token-value">#ECECEC</td><td class="token-value">#222222</td></tr>
    <tr><td>Text Primary</td><td class="token-value">#1C1C1E</td><td class="token-value">#FFFFFF</td></tr>
    <tr><td>Text Secondary</td><td class="token-value">#636366</td><td class="token-value">#999999</td></tr>
    <tr><td>Text Tertiary</td><td class="token-value">#8E8E93</td><td class="token-value">#666666</td></tr>
    <tr><td>Text Quaternary</td><td class="token-value">#AEAEB2</td><td class="token-value">#555555</td></tr>
    <tr><td>Accent</td><td class="token-value" colspan="2">#FF2D55 (unchanged)</td></tr>
    <tr><td>Success</td><td class="token-value" colspan="2">#34C759 (unchanged)</td></tr>
    <tr><td>Tint opacity</td><td class="token-value">10%</td><td class="token-value">12%</td></tr>
  </table>

  <div class="impl-note">
    <div class="impl-label">iOS Implementation</div>
    <p>Use iOS semantic colors (UIColor.systemBackground, .label, .secondaryLabel, etc.) and they'll automatically switch in dark mode. For custom colors, define them in the asset catalog with light/dark variants. The accent and semantic colors (green, orange, blue) don't need to change.</p>
  </div>

  <div class="impl-note">
    <div class="impl-label">Web Implementation</div>
    <p>Define CSS custom properties at <code>:root</code> for light mode and override in a <code>[data-theme="dark"]</code> selector or <code>@media (prefers-color-scheme: dark)</code>. Toggle by setting <code>document.documentElement.dataset.theme</code>. Store preference in localStorage.</p>
  </div>
</div>

<hr class="divider">

<!-- ===== iOS IMPLEMENTATION ===== -->
<div class="section" id="ios-impl">
  <div class="section-label">Implementation</div>
  <h2>iOS / Swift Notes</h2>

  <h3>Typography</h3>
  <div class="code-block">
<span class="comment">// Define a type scale enum</span>
<span class="key">enum</span> DumpFont {
    <span class="key">static let</span> pageTitle = UIFont.systemFont(ofSize: <span class="value">36</span>, weight: .heavy)
    <span class="key">static let</span> screenTitle = UIFont.systemFont(ofSize: <span class="value">34</span>, weight: .heavy)
    <span class="key">static let</span> sectionTitle = UIFont.systemFont(ofSize: <span class="value">28</span>, weight: .bold)
    <span class="key">static let</span> noteTitle = UIFont.systemFont(ofSize: <span class="value">24</span>, weight: .bold)
    <span class="key">static let</span> categoryName = UIFont.systemFont(ofSize: <span class="value">16</span>, weight: .medium)
    <span class="key">static let</span> cardTitle = UIFont.systemFont(ofSize: <span class="value">15</span>, weight: .semibold)
    <span class="key">static let</span> body = UIFont.systemFont(ofSize: <span class="value">15</span>, weight: .regular)
    <span class="key">static let</span> cardPreview = UIFont.systemFont(ofSize: <span class="value">13</span>, weight: .regular)
    <span class="key">static let</span> sectionLabel = UIFont.systemFont(ofSize: <span class="value">10</span>, weight: .semibold)
    <span class="key">static let</span> meta = UIFont.systemFont(ofSize: <span class="value">11</span>, weight: .regular)
    <span class="key">static let</span> mono = UIFont.monospacedSystemFont(ofSize: <span class="value">12</span>, weight: .regular)
}
  </div>

  <h3>Spacing</h3>
  <div class="code-block">
<span class="key">enum</span> DumpSpacing {
    <span class="key">static let</span> xs: CGFloat = <span class="value">4</span>
    <span class="key">static let</span> sm: CGFloat = <span class="value">8</span>
    <span class="key">static let</span> smPlus: CGFloat = <span class="value">12</span>
    <span class="key">static let</span> md: CGFloat = <span class="value">16</span>
    <span class="key">static let</span> lg: CGFloat = <span class="value">24</span>
    <span class="key">static let</span> xl: CGFloat = <span class="value">32</span>
    <span class="key">static let</span> xxl: CGFloat = <span class="value">48</span>
    <span class="key">static let</span> xxxl: CGFloat = <span class="value">64</span>
    <span class="key">static let</span> screenH: CGFloat = <span class="value">24</span> <span class="comment">// horizontal screen padding</span>
}
  </div>

  <h3>Category Tint Color</h3>
  <div class="code-block">
<span class="key">static let</span> tintColors: [UIColor] = [
    .systemPink, .systemOrange, .systemBlue,
    .systemGreen, .systemIndigo, .systemPurple, .systemYellow
]

<span class="key">static func</span> tintColor(for name: String) -> UIColor {
    <span class="key">let</span> hash = name.utf8.reduce(<span class="value">0</span>) { $0 &+ Int($1) }
    <span class="key">return</span> tintColors[abs(hash) % tintColors.count].withAlphaComponent(<span class="value">0.10</span>)
}
  </div>

  <h3>Tracking (Letter Spacing)</h3>
  <div class="code-block">
<span class="comment">// iOS uses points for kern, not pixels
// -1.5px tracking ≈ -1.5 kern value in NSAttributedString</span>
<span class="key">let</span> attrs: [NSAttributedString.Key: Any] = [
    .font: DumpFont.pageTitle,
    .kern: <span class="value">-1.5</span>
]
  </div>
</div>

<hr class="divider">

<!-- ===== WEB IMPLEMENTATION ===== -->
<div class="section" id="web-impl">
  <div class="section-label">Implementation</div>
  <h2>Web / Vanilla JS</h2>
  <p class="section-desc">No framework required. CSS custom properties for theming, vanilla JS for the dark mode toggle.</p>

  <h3>CSS Custom Properties</h3>
  <div class="code-block">
<span class="comment">/* Light mode (default) */</span>
:root {
  <span class="key">--bg</span>: <span class="value">#FFFFFF</span>;
  <span class="key">--surface</span>: <span class="value">#F9F9F9</span>;
  <span class="key">--surface-2</span>: <span class="value">#F2F2F7</span>;
  <span class="key">--surface-3</span>: <span class="value">#E5E5EA</span>;
  <span class="key">--border</span>: <span class="value">#E5E5EA</span>;
  <span class="key">--border-light</span>: <span class="value">#ECECEC</span>;
  <span class="key">--text-1</span>: <span class="value">#1C1C1E</span>;
  <span class="key">--text-2</span>: <span class="value">#636366</span>;
  <span class="key">--text-3</span>: <span class="value">#8E8E93</span>;
  <span class="key">--text-4</span>: <span class="value">#AEAEB2</span>;
  <span class="key">--accent</span>: <span class="value">#FF2D55</span>;
  <span class="key">--accent-subtle</span>: <span class="value">rgba(255, 45, 85, 0.08)</span>;
  <span class="key">--success</span>: <span class="value">#34C759</span>;
  <span class="key">--tint-opacity</span>: <span class="value">0.10</span>;
  <span class="key">--font-sans</span>: <span class="string">'DM Sans', -apple-system, sans-serif</span>;
  <span class="key">--font-mono</span>: <span class="string">'Space Mono', monospace</span>;
}

<span class="comment">/* Dark mode */</span>
[data-theme=<span class="string">"dark"</span>] {
  <span class="key">--bg</span>: <span class="value">#000000</span>;
  <span class="key">--surface</span>: <span class="value">#111111</span>;
  <span class="key">--surface-2</span>: <span class="value">#1A1A1A</span>;
  <span class="key">--surface-3</span>: <span class="value">#222222</span>;
  <span class="key">--border</span>: <span class="value">#2A2A2A</span>;
  <span class="key">--border-light</span>: <span class="value">#222222</span>;
  <span class="key">--text-1</span>: <span class="value">#FFFFFF</span>;
  <span class="key">--text-2</span>: <span class="value">#999999</span>;
  <span class="key">--text-3</span>: <span class="value">#666666</span>;
  <span class="key">--text-4</span>: <span class="value">#555555</span>;
  <span class="key">--tint-opacity</span>: <span class="value">0.12</span>;
}
  </div>

  <h3>Dark Mode Toggle</h3>
  <div class="code-block">
<span class="comment">// Toggle</span>
<span class="key">function</span> toggleTheme() {
  <span class="key">const</span> current = document.documentElement.dataset.theme;
  <span class="key">const</span> next = current === <span class="string">'dark'</span> ? <span class="string">'light'</span> : <span class="string">'dark'</span>;
  document.documentElement.dataset.theme = next;
  localStorage.setItem(<span class="string">'theme'</span>, next);
}

<span class="comment">// On page load — respect saved preference or system</span>
<span class="key">const</span> saved = localStorage.getItem(<span class="string">'theme'</span>);
<span class="key">if</span> (saved) {
  document.documentElement.dataset.theme = saved;
} <span class="key">else if</span> (matchMedia(<span class="string">'(prefers-color-scheme: dark)'</span>).matches) {
  document.documentElement.dataset.theme = <span class="string">'dark'</span>;
}
  </div>

  <h3>Tint Color Utility</h3>
  <div class="code-block">
<span class="key">const</span> TINT_BASES = [
  <span class="string">'255, 45, 85'</span>,   <span class="comment">// red</span>
  <span class="string">'255, 149, 0'</span>,   <span class="comment">// orange</span>
  <span class="string">'0, 122, 255'</span>,   <span class="comment">// blue</span>
  <span class="string">'52, 199, 89'</span>,   <span class="comment">// green</span>
  <span class="string">'88, 86, 214'</span>,   <span class="comment">// indigo</span>
  <span class="string">'175, 82, 222'</span>,  <span class="comment">// purple</span>
  <span class="string">'255, 204, 0'</span>,   <span class="comment">// yellow</span>
];

<span class="key">function</span> getCategoryTint(name) {
  <span class="key">let</span> hash = <span class="value">0</span>;
  <span class="key">for</span> (<span class="key">let</span> i = <span class="value">0</span>; i < name.length; i++) {
    hash = hash + name.charCodeAt(i);
  }
  <span class="key">const</span> base = TINT_BASES[Math.abs(hash) % TINT_BASES.length];
  <span class="key">const</span> opacity = getComputedStyle(document.documentElement)
    .getPropertyValue(<span class="string">'--tint-opacity'</span>).trim();
  <span class="key">return</span> <span class="string">`rgba(${base}, ${opacity})`</span>;
}
  </div>
</div>

<hr class="divider">

<!-- ===== EMOJI AI IMPLEMENTATION ===== -->
<div class="section" id="emoji-impl">
  <div class="section-label">Implementation</div>
  <h2>AI Emoji Assignment</h2>
  <p class="section-desc">How to get OpenAI to assign an emoji when creating a new category.</p>

  <h3>Prompt Addition</h3>
  <div class="code-block">
<span class="comment">// Add to your existing categorization prompt:</span>

<span class="string">"When creating a new category, also return a single
emoji that visually represents the category topic.
Return it as a UTF-8 emoji character in the 'emoji'
field. Choose concrete, recognizable emoji. Examples:
  - Business Ideas → 💡
  - Family → 👨‍👩‍👧
  - Coding → 💻
  - Travel → ✈️
  - Health → 🏥
  - Finance → 💰"</span>
  </div>

  <h3>Response Schema</h3>
  <div class="code-block">
<span class="comment">// Expected response when a new category is created:</span>
{
  <span class="key">"category"</span>: <span class="string">"George Labs"</span>,
  <span class="key">"emoji"</span>: <span class="string">"🚀"</span>,
  <span class="key">"sub_category"</span>: <span class="string">"Roadmap"</span>,
  <span class="key">"is_new_category"</span>: <span class="value">true</span>
}

<span class="comment">// Store emoji in your categories table:
// categories: { id, name, emoji, created_at }</span>
  </div>

  <div class="impl-note">
    <div class="impl-label">Key Considerations</div>
    <p>
      <strong>Yes, OpenAI can output emoji.</strong> They're just UTF-8 characters — they flow through the API like any other text. Store them as-is in PostgreSQL (which handles UTF-8 natively). Both Swift and JavaScript render emoji natively with zero special handling.<br><br>
      <strong>Only assign emoji on category creation</strong>, not on every note. Cache the emoji with the category record so it's consistent. If a user has 15 categories, that's 15 emoji assignments total, ever.<br><br>
      <strong>Fallback:</strong> If the API doesn't return an emoji (edge case), fall back to the first letter of the category name in the tinted circle. This also works as the initial state before the API responds.
    </p>
  </div>

  <h3>Fallback: Letter Avatar</h3>
  <div class="cat-icon-grid">
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,149,0,0.10); font-size: 16px; font-weight: 700; color: #FF9500;">B</div>
      <span class="cat-icon-name">Business Ideas</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(0,122,255,0.10); font-size: 16px; font-weight: 700; color: #007AFF;">C</div>
      <span class="cat-icon-name">Coding Courses</span>
    </div>
    <div class="cat-icon-example">
      <div class="cat-icon-circle" style="background: rgba(255,45,85,0.10); font-size: 16px; font-weight: 700; color: #FF2D55;">G</div>
      <span class="cat-icon-name">George Labs</span>
    </div>
  </div>
  <p class="component-note">The letter fallback uses the tint base color at full opacity for the letter, and 10% opacity for the background. Same container spec as the emoji version.</p>
</div>

<hr class="divider">

<!-- ===== SCREEN STRUCTURE ===== -->
<div class="section">
  <div class="section-label">Reference</div>
  <h2>Screen Structure Summary</h2>

  <h3>Dump Screen (Capture)</h3>
  <table class="token-table">
    <tr><th>Element</th><th>Spec</th></tr>
    <tr><td>Header</td><td>"DUMP IT." page title + subtitle</td></tr>
    <tr><td>Capture Grid</td><td>2×2 capture cards (Voice, Photo, Note, File)</td></tr>
    <tr><td>Recent Section</td><td>Section label + recent feed items</td></tr>
    <tr><td>Tab Bar</td><td>Floating pill, Dump active</td></tr>
  </table>

  <h3>Browse Screen</h3>
  <table class="token-table">
    <tr><th>Element</th><th>Spec</th></tr>
    <tr><td>Header</td><td>"Browse" screen title</td></tr>
    <tr><td>Search</td><td>Search bar component</td></tr>
    <tr><td>Categories</td><td>Section label + category rows (icon, name, count, chevron)</td></tr>
    <tr><td>Tab Bar</td><td>Floating pill, Browse active</td></tr>
  </table>

  <h3>Category Detail Screen</h3>
  <table class="token-table">
    <tr><th>Element</th><th>Spec</th></tr>
    <tr><td>Nav</td><td>Back button + breadcrumb</td></tr>
    <tr><td>Header</td><td>Category name (section title) + note count</td></tr>
    <tr><td>Filters</td><td>Pill row (All, Voice, Text, Photo, File)</td></tr>
    <tr><td>Notes</td><td>Vertical list of note cards</td></tr>
  </table>

  <h3>Note Detail Screen</h3>
  <table class="token-table">
    <tr><th>Element</th><th>Spec</th></tr>
    <tr><td>Nav</td><td>Back button + action buttons (Info, Edit)</td></tr>
    <tr><td>Meta</td><td>Category badge (accent) + date</td></tr>
    <tr><td>Title</td><td>Note title style</td></tr>
    <tr><td>Body</td><td>Body text with formatted bullets</td></tr>
  </table>
</div>

</div><!-- end doc-main -->

</body>
</html>
