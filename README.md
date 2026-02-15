# wp-ddev-tools

**A toolkit for non-developer WordPress site owners who want easy-to-use tools for setting up and managing a local development environment for collaboration with AI coding tools and agents.**

## Why does this exist?

If you run a WordPress site — maybe a business site, a coaching practice, a blog — you've probably been in this situation: you want to try something (a new plugin, a theme tweak, a schema markup change) but you have no idea where to start and/or you're terrified of breaking your live site. So you either spend hours and hours looking for the right niche plug-in or special theme that does that one thing you want, or you pay someone to make it custom, or you just… don't.

**Welcome to the Future**

But things have changed. You don't need to hire someone anymore, and you don't need to feel like you're on your own. You also don't have to settle for a "good enough" theme or plug-in. **AI coding tools like [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) now exist.** And they're remarkably good at building things for you — writing plugins, editing theme files, debugging issues, generating structured data. But they need a workspace. You wouldn't hand a contractor the keys to your house and say "experiment on my kitchen." You'd set up a workshop.

There's a whole world of "local development" tools that developers use to run a copy of their site on their own computer. You can experiment freely, break things, undo them, and only push changes to your real site when you're confident they work. But setting it up has always required developer knowledge — Docker, command-line tools, database imports, SSH configuration, URL replacement — a dozen steps where one wrong move means starting over.

A local dev environment is that workshop. It's where you and an AI collaborator can build things together — you describe what you want, it writes the code, you test it in your browser, you iterate. No risk to your live site. When it's ready, you deploy.

Before these tools, even with a local environment, a non-developer would still be stuck staring at PHP files. Now you can actually *use* the environment.

I went through this process with Claude and although Claude gave me some great step-by-step tutorials, it was still a lot of copy and pasting into terminal with trial and error. Along the way I noticed I was doing a lot of steps or repeating commands a ton, so I asked Claude to create some tools for me to do common things needed to setup and manage a local Wordpress environment. Now I'm giving it to the open-source community to help other folks. Maybe you or your agent will find it someday and save you some time ;)

After consulting Reddit and Claude + research, although a solution like LocalWP is awesome too, and comes with a nice GUI, we landed on using DDEV as the backend for a few important reasons:
- **CLI*-first design** — AI coding tools like Claude Code work through the terminal. DDEV's command-line interface means your AI collaborator can start/stop the environment, run WP-CLI commands, inspect databases, and test changes directly. LocalWP's GUI is great for humans but invisible to AI.
- **WP-CLI built in** — `ddev wp` gives you full WordPress CLI access out of the box. Export databases, manage plugins, search-replace URLs, flush caches — all scriptable and all automatable.
- **Precise environment matching** — DDEV lets you specify the exact PHP version, database engine (MySQL vs MariaDB), and database version to match your live host. LocalWP gives you a few choices; DDEV gives you exact parity.
- **Configuration as code** — Your entire environment is defined in `.ddev/config.yaml` — a simple text file you commit to Git. Anyone who clones your repo gets the exact same setup. No clicking through GUI settings, no "it works on my machine" surprises. New team member? `git clone` + `ddev start`. That's it.
- **Extensible with hooks** — DDEV's post-start hooks let you automatically fix things that reset on restart (like custom table prefixes and WP_DEBUG). This turned out to be critical for our setup.
- **Docker-based and open source** — Runs on any Docker provider (OrbStack, Colima, Docker Desktop), no vendor lock-in, no account required, fully free.
- **Scriptable everything** — Because it's all CLI, we were able to build tools like `sync-from-live.sh` and `verify-env.sh` on top of it. That's much harder with a GUI-first tool.

\*CLI = Command Line Interface — it just means you type text commands instead of clicking buttons. Terminal on your Mac is a CLI. WordPress's admin dashboard is a GUI (Graphical User Interface — buttons, menus, mouse clicks). Same stuff gets done, different way of talking to the computer.



**This toolkit automates all of the setup into a single command.**

## Who is this for?

You're a good fit if you:

- **Own a WordPress site** hosted somewhere like SiteGround, Cloudways, WP Engine, or any host with SSH access
- **Aren't a developer** but you're comfortable (or willing to get comfortable) typing commands in Terminal
- **Want to make changes safely** — test plugins, edit themes, tweak structured data — without risking your live site
- **Have heard of "local development"** and know it's probably the right move, but every guide you've found assumes you already know what Docker is

You don't need to know PHP, Git, Docker, or anything about databases. The setup script asks you plain questions ("What's your site URL?", "What's your SSH username?") and handles the rest.

## What does it actually do? (Explain Like I'm 5)

Imagine your live website is a sandcastle on the beach. Right now, every change you make is to *that* sandcastle — the real one, the one people see. If you mess up, everyone sees the mess.

**wp-ddev-tools makes a perfect copy of your sandcastle in your backyard.** You can smash it, rebuild it, try crazy things. When you're happy with a change, you carry just that piece back to the beach. If you mess up? Knock it down and make another copy. The real sandcastle was never touched.

Technically, it:

1. **Sets up a mini web server on your computer** (using a tool called DDEV) that runs WordPress just like your hosting provider does
2. **Copies everything from your live site** — themes, plugins, images, database, settings — so your local copy looks and works identically
3. **Matches the technical details** — same PHP version, same database engine, same configuration — so what works locally will work when you deploy it
4. **Gives you ongoing tools** to re-sync from your live site and verify the two environments still match

The whole setup takes about 10 minutes and one Terminal command.

---

## What's included

| Script | Purpose |
|--------|---------|
| `wp-ddev-setup.sh` | Full setup — installs Docker, DDEV, HTTPS, pulls your live site, configures everything |
| `sync-from-live.sh` | Ongoing sync — pulls latest database and files from live into local |
| `verify-env.sh` | Parity check — compares local vs live (PHP, MySQL, plugins, config) |

## Quick Start

```bash
git clone https://github.com/yourname/wp-ddev-tools.git
cd wp-ddev-tools
chmod +x *.sh
./wp-ddev-setup.sh
```

The setup script will walk you through everything interactively:

1. **Project name and directory** — what to call it and where to put it
2. **Live site connection** — SSH host, user, port, WordPress path
3. **Prerequisites** — installs Docker (OrbStack/Colima/Docker Desktop), DDEV, mkcert, if needed
4. **SSH config** — creates an alias, tests the connection
5. **Environment detection** — auto-detects PHP version, database engine/version, table prefix from live
6. **DDEV project** — creates and configures to match live environment exactly
7. **File sync** — pulls plugins, themes, and uploads via rsync
8. **Database** — exports live DB, imports locally, fixes URLs
9. **Git** — initializes repo with .gitignore, optionally creates GitHub repo
10. **Config** — generates `.wp-ddev-tools.conf` for the helper scripts

## Ongoing Sync

After initial setup, pull latest changes from live anytime:

```bash
cd ~/Projects/your-site
./sync-from-live.sh              # Full sync: database + uploads
./sync-from-live.sh --skip-uploads   # Database only (faster)
```

What it does:
- Loads SSH key (one passphrase prompt)
- Snapshots local DB (easy rollback)
- Rsyncs uploads from live
- Exports, downloads, imports live database
- Restarts DDEV (applies config hooks)
- Runs URL search-replace, flushes caches

Roll back anytime:
```bash
ddev snapshot restore pre-sync-20250214-203000
```

## Environment Verification

Confirm local matches live:

```bash
./verify-env.sh
```

Checks: WordPress version, PHP version, database version, table prefix, active theme, blog name, and all active plugins with exact version matching. Single SSH connection for speed.

```
Core Versions
  ✓ WordPress: 6.9.1
  ✓ PHP: 8.2
  ~ Database
    Local: 8.4.5
    Live:  8.4.5-5

Configuration
  ✓ Table prefix: nab_
  ✓ Active theme: flavor
  ✓ Blog name: My Site

Active Plugins
  ✓ 31 plugins match exactly (name + version)
```

## Requirements

- **macOS** (Linux support planned)
- **Homebrew** (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- **SSH access** to your live WordPress site with WP-CLI available
- ~2GB free disk space for Docker + WordPress

The setup script handles installing everything else (Docker, DDEV, mkcert, Git).

## How it works

### Architecture

```
┌──────────────────────────────────────────────────────┐
│  LOCAL (your machine)                                │
│                                                      │
│  ~/Projects/your-site/                               │
│    .ddev/                                            │
│      config.yaml          ← PHP, DB engine, version  │
│      config.local.yaml    ← Table prefix, WP_DEBUG   │
│    wp-content/                                       │
│      plugins/             ← Synced from live         │
│      themes/              ← Synced from live         │
│      uploads/             ← Media (Git ignored)      │
│    .wp-ddev-tools.conf    ← Script configuration     │
│    sync-from-live.sh      ← Ongoing sync             │
│    verify-env.sh          ← Parity check             │
│                                                      │
│  DDEV (Docker) serves at https://your-site.ddev.site │
└────────────────────┬─────────────────────────────────┘
                     │  SSH + rsync
                     ▼
          ┌─────────────────────┐
          │   Live Server       │
          │   wp-content/       │
          │   database          │
          └─────────────────────┘
```

### Key design decisions

**Table prefix handling:** Many hosts randomize the WordPress table prefix for security (e.g., `abc_` instead of `wp_`). DDEV regenerates `wp-config-ddev.php` on every restart, resetting the prefix to `wp_`. The setup script creates a post-start hook in `.ddev/config.local.yaml` that patches it back automatically.

**WP_DEBUG suppression:** DDEV defaults WP_DEBUG to `true`, which can be noisy (e.g., deprecation notices from plugins that work fine in production). The post-start hook sets it to `false` to match production behavior.

**Database engine matching:** DDEV defaults to MariaDB, but many hosts now run MySQL 8.x. The setup script detects the live engine and version, configuring DDEV to match exactly.

**Single SSH connections:** Both `sync-from-live.sh` and `verify-env.sh` gather all remote data in a single SSH call using `bash -s`, minimizing passphrase prompts and connection overhead.

## Configuration

The setup script generates `.wp-ddev-tools.conf`:

```bash
SSH_HOST="your-site-live"
SSH_PORT="22"
REMOTE_ROOT="~/public_html"
LOCAL_URL="https://your-site.ddev.site"
LIVE_URL="https://your-site.com"
TABLE_PREFIX="wp_"
```

Both helper scripts read this file automatically. You can also edit it manually.

## Daily workflow

```
Morning:    ddev start
Develop:    Edit files → refresh browser → test
Sync:       ./sync-from-live.sh (when live site changes)
Verify:     ./verify-env.sh (confirm parity)
Commit:     git add . && git commit -m "msg" && git push
Deploy:     rsync -avz -e "ssh -p PORT" wp-content/ host:path/wp-content/
Evening:    ddev stop
```

## Troubleshooting

**Blank page after sync:** Plugins or themes missing locally. Re-run `./sync-from-live.sh` for a full sync.

**"Table prefix" errors after restart:** The post-start hook may not have fired. Run `ddev restart` and check `.ddev/config.local.yaml` exists.

**WP_DEBUG notices after restart:** Same as above — the hook patches WP_DEBUG on each start.

**SSH passphrase prompts:** Load your key first: `eval "$(ssh-agent -s)" && ssh-add`

**HTTPS certificate warnings:** Run `mkcert -install` and `ddev restart`.

**Database engine mismatch:** Check live with `ssh your-host "mysql -V"`, then `ddev config --database=mysql:8.4` (or appropriate version).

## Contributing

Issues and PRs welcome. The main areas for contribution:

- **Linux support** — the setup script assumes macOS/Homebrew
- **Additional hosting providers** — tested with SiteGround, should work with any SSH+WP-CLI host
- **Deploy script** — a `deploy-to-live.sh` counterpart to `sync-from-live.sh`
- **Multi-site support** — WordPress multisite configurations

## License

MIT
