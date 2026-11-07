# free-coder: user guide

You have two programs. **OmniRoute** is the gateway that connects to free AI services. **Hermes** is the assistant you talk to. OmniRoute needs to be set up once with accounts, then you only use Hermes.

## 1. First-time setup (about 15 minutes, once)

1. Double-click `install.cmd` and wait for "Done". The first run downloads about 0.6 GB and can take 15+ minutes. Do not click inside the black window while it runs (a click can pause it; press Esc if it stops).
2. Your OmniRoute login is in `%LOCALAPPDATA%\free-coder\login.txt` (paste that into File Explorer's address bar). Keep it private.
3. Open the OmniRoute dashboard: double-click **Free Coder - add providers** on the desktop, or go to `http://localhost:20128` in a browser. Sign in with the password from `login.txt`.

## 2. Add free AI providers in OmniRoute (the important step)

Without at least one provider the assistant cannot answer. Each provider needs an account in your own name and email. They are free, but each has limits. Connect two or three so there is always a fallback.

**General steps in the OmniRoute dashboard** (menu names can change a little between versions):
1. Click **Providers** in the sidebar.
2. Click **+ Add Provider** and pick the provider.
3. Paste the API key (steps below), save, then click **Test**. It should show a success.
4. Make sure the connection is switched on (active). A new provider can start inactive.

**Good starting providers**

| Provider | Where to get the key | Notes |
| --- | --- | --- |
| Groq | console.groq.com > API Keys > Create | Fast, easiest to start with. Rate limited. |
| Google Gemini | aistudio.google.com/apikey | Needs a Google account. Limits vary. |
| Cloudflare Workers AI | dash.cloudflare.com > AI > Workers AI > API token (also needs your Account ID) | About 30M tokens a month. |
| OpenRouter | openrouter.ai/keys, then use models ending in `:free` | Shared limits. |
| Mistral | console.mistral.ai > API keys (Codestral for code) | Check the current free terms. |

Free terms change often, and some providers log your prompts or want a payment method. **Do not paste private plant data, passwords or proprietary PLC logic into any free service.** OmniRoute shows terms and privacy notes on each provider card. Read them. OmniRoute's own guide: https://github.com/cheaper-inference/OmniRoute/blob/main/docs/getting-started/FREE-TIERS-GUIDE.md

**Check it works:** in the dashboard open the playground or chat test for the model `auto/best-coding` and send "hello". If you get an answer, you are done. If you get "no provider available", no provider is active yet: go back to Providers and test again.

## 3. Daily use: Hermes

- **Desktop app:** double-click **Free Coder (Hermes)** on the desktop.
- **Command line:** open PowerShell and type `hermes`.
- OmniRoute starts by itself when you log in to Windows. If Hermes says it cannot connect, open `http://localhost:20128`. If that page does not load, open OmniRoute from the Start menu and wait a minute.

**Working well with the assistant**
- Give it the real thing: put your PLC code, R script or data file in a folder, open Hermes there, and tell it the file name. It reads real files instead of guessing.
- Say what the equipment is (PLC brand and model, software and version) once at the start. Ask it to remember it ("remember that we use ...").
- It is set up to tell you when you are wrong, to look facts up, and to say when it does not know. Check anything it says about real equipment before you run it.
- **Never let it download code to a live PLC or change dose settings without testing offline first.** It will warn you, but you decide.

## 4. Keeping it working

- **A provider stops working** (rate limit, expired key, "no provider available"): dashboard > Providers > **Test**. Replace the key if needed. Having several providers means one failing is not a problem.
- **Change the model it uses:** OmniRoute > Combos. Hermes uses `auto/best-coding`. To use `auto/best-free` instead, run `hermes config set model.default auto/best-free`.
- **Optional web search keys:** web search works without keys but on shared limits. For more, get a free Brave or Exa key and run `hermes config` to add it (see the Hermes docs, "Web Search").
- **Updates:** both programs update themselves. To check Hermes manually run `hermes update`.

## 5. If something is wrong

1. Re-run `install.cmd`. It is safe and skips what is already done.
2. Send us these files from `%LOCALAPPDATA%\free-coder\`: `install.log` and `last-error.txt`.
3. "Could not sign in to OmniRoute": re-run `install.cmd`. It resets the login on its own and keeps a backup of the old data.
