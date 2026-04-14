# Autobumper

## Overview

A tiny app that bumps your Discord server written in Go.

Autobumper uses [discoself](https://github.com/krishnassh/discoself), which interacts with the Discord client API in ways that are outside Discord’s official bot platform. Use of selfbots may violate Discord’s Terms of Service. The author is not responsible for any misuse of this project or any consequences that may arise from its use.

![demo](assets/demo.png)

---

## How it works

Once connected, the client sends the Disboard `/bump` slash command and then repeats it at random intervals between **2 hours and 2.5 hours** to reduce predictable behavior.

It matches the command by both:

* Command name
* Disboard application ID: `302050872383242240`

This ensures it does not accidentally trigger another bot’s `bump` command if multiple bots are present in the server.

---

## Getting required arguments

You must enable **Developer Mode** in Discord to copy IDs.

Go to:
`Settings -> Advanced -> Developer Mode -> Enable`

Then:

* **Guild ID:** Right-click your server icon -> Copy Server ID
* **Channel ID:** Right-click the channel -> Copy Channel ID
* **User Token:** Refer to the token retrieval guide [here](https://gist.github.com/KrishnaSSH/b518ec90cd54f33d70a7d4525e9258a2).

---

## How to run

### Windows

Open Command Prompt or PowerShell and run:

```bat
powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.bat -OutFile start.bat"
start.bat
```

Alternatively, download manually:

1. Open:
   [https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.bat](https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.bat)
2. Save it as `start.bat`
3. Double-click to run

---

### Linux and macOS

Run directly:

```bash
curl -fsSL https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.sh | bash
```

Or download and execute manually:

```bash
curl -fsSL https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.sh -o start.sh
chmod +x start.sh
./start.sh
```

### Android (Termux)

You can also run Autobumper on Android using Termux.

1. Install Termux from [F-Droid (recommended)](https://f-droid.org/en/packages/com.termux/).

2. Open Termux and run:

3. Run the installer script:
```bash
curl -fsSL https://raw.githubusercontent.com/KrishnaSSH/autobumper/refs/heads/main/start.sh | bash
```
Fill the Token, Guild-id and channel-id when it prompts you

Note: Make sure Termux has network access and is allowed to run background processes for uninterrupted execution.

> **Note:** the android system kills termux application from running for longer sessions to prevent this make sure termux app has permission to send notifications and press on aquire-wakelock on the notification

---


## Support / Community

[![Join Discord](https://img.shields.io/badge/discord-join%20server-5865F2?logo=discord&logoColor=white)](https://discord.gg/pC34hC6q3q)

