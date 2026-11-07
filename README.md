# free-coder

**Using it? Read [GUIDE.md](GUIDE.md)** (setup, adding free providers, daily use, fixing problems).

A coding assistant for a non-programmer technician (PLC code, R, data to reports), running on free LLM tiers.
It installs and connects two **official** apps, which update themselves:

- [OmniRoute](https://github.com/cheaper-inference/OmniRoute): local gateway that routes to free AI providers (`http://localhost:20128`)
- [Hermes Agent](https://hermes-agent.nousresearch.com): the assistant (desktop app + CLI, same agent)

No Docker, no WSL, no admin rights. About 0.6 GB download.

## Install
Double-click **`install.cmd`**. It handles PowerShell's "running scripts is disabled on this system" error.
Manual alternative: `powershell -ExecutionPolicy Bypass -File windows\install.ps1`
Then follow the two steps it prints. Re-running is safe.

## One step that cannot be automated: free providers
OmniRoute has no working models until you add provider accounts with your own email. Open the **Free Coder - add providers** shortcut, sign in (password in `%LOCALAPPDATA%\free-coder\login.txt`), then **Providers**, and add keys for a few of these (all have free tiers; check each one's current terms):

- Groq, Cloudflare Workers AI, NVIDIA NIM, Mistral (Codestral), OpenRouter (`:free` models), Google Gemini

Keyless routes shipped with OmniRoute mostly fail without accounts, and some need a browser runtime. After adding a key, click **Test**, then activate it.
Hermes uses the `auto/best-coding` combo; change with `hermes config set model.default auto/best-free`.

## Verified (Windows 11 ARM VM, x64 emulation)
OmniRoute silent install, headless start, API key creation, Hermes install, Hermes-to-OmniRoute request path.
**Not verified:** an actual model answer (needs a provider key), Hermes desktop app launch, autostart at real login, Windows 10.

## Files
- `windows/install.ps1` downloads and installs both, then runs `connect.ps1`
- `windows/connect.ps1` sets the admin password, creates an API key, points Hermes at OmniRoute, starts OmniRoute at login

## How the agent behaves

`install.cmd` installs a persona file (`windows/SOUL.md`) into Hermes. It tells the agent not to flatter or cave in, to say when you are wrong, to look facts up (web search, documentation, your actual files) instead of guessing, and to warn before anything that changes a physical process. Edit `%LOCALAPPDATA%\hermes\SOUL.md` to change it. Re-running `install.cmd` restores the original, and your previous file is kept as `SOUL.md.orig`. Put changes that must survive in the agent's memory by telling it "remember that ...".

Web search: the `web` toolset is enabled by default. With no API keys, Hermes uses the free tiers of its search providers. These are shared and rate-limited, so for steady use add a free Brave or Exa key (see the Hermes docs, "Web Search").
