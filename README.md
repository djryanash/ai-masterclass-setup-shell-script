# AI Website-Building Class — Machine Setup

Everything you need to set up your machine for the class. The setup script
installs the full taught toolchain (git, GitHub CLI, Node.js, Ollama, Pi, the
Vercel CLI), walks you through every credential, creates your project folder
with the repo pushed, and launches **Pi** inside it so class can begin.

> **NOTE:** PLEASE READ ALL INSTRUCTIONS CAREFULLY.

* **Windows Users:** Begin at **Step 1**.
* **Linux Users:** Jump to **Step 3**.
* **Mac Users:** Jump to **Step 4**.

---

## The normal way: you were given a zip file

Use this section if you were handed `ai-website-masterclass.zip` in class.

### Windows Users

#### 1. Extract the Zip File

1. Move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Right-click `ai-website-masterclass.zip` (or two-finger tap / press bottom-right trackpad) and select **Extract All...**.
3. Double-click the extracted `ai-website-masterclass` folder to enter it.

#### 2. Check if Windows Subsystem for Linux (WSL) is Installed

1. Inside the `ai-website-masterclass` folder, press Ctrl + L to focus the address bar.
2. Type `wsl` and press Enter.
   * **If a WSL Terminal window opens:** WSL is installed. Proceed to **Step 2b** below.
   * **If an error or command-not-found prompt appears:** Proceed to **Step 2c** below.

#### 2b. Set Up Project in WSL (If WSL is Installed)

1. In the WSL Terminal window, type `cd ~` and press Enter.
2. Open your home directory in File Explorer by typing `explorer.exe .` and pressing Enter.
3. Drag the extracted `ai-website-masterclass` folder from your Windows folder into this newly opened WSL **File Explorer** window.
4. Double-click to open the `ai-website-masterclass` folder inside WSL.
5. Press Ctrl + L to focus the address bar.
6. Type `wsl` and press Enter.
7. Jump to **All Users Continue Here**.

#### 2c. Install WSL (If Not Installed)

1. While still inside the extracted `ai-website-masterclass` folder in **File Explorer**, press Ctrl + L to focus the address bar.
2. Type the following command and press Enter:

```powershell
Start-Process powershell -Verb RunAs -WorkingDirectory $PWD
```

3. In the elevated PowerShell window that opens, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-wsl-bootstrap.ps1
```

4. Wait for the script to complete and restart your computer when prompted.
5. After restarting, navigate back to your `ai-website-masterclass` folder and return to **Step 2**.

### Linux Users

#### 3. Extract and Open Terminal

1. In **File Manager**, move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Right-click `ai-website-masterclass.zip` and select **Extract Here**.
3. Once extracted, delete the `.zip` file.
4. Double-click the extracted `ai-website-masterclass` folder to enter it.
5. Right-click any empty space inside the folder and select **Open in Terminal** (or **Open Terminal Here**).
6. Jump to **All Users Continue Here**.

### Mac Users

#### 4. Extract and Open Terminal

1. In **Finder**, move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Double-click `ai-website-masterclass.zip` to extract it.
3. Once extracted, delete the `.zip` file.
4. Right-click (or Control + click) the extracted `ai-website-masterclass` folder.
5. Select **Services** → **New Terminal at Folder** (or **New Terminal at Folder** directly from the context menu).
6. Jump to **All Users Continue Here**.

---

## The fallback way: download straight from GitHub

Use this section **only if you do not have the zip file** (e.g. you lost it or
you're setting up a new machine before class). Copy-paste the commands for
your operating system.

Pick (or create) the folder where your AI Agent Projects should live first —
the project folder is created **inside the folder you run the command from**.

### Mac Users

Open **Terminal** (Applications → Utilities → Terminal), then paste:

```bash
cd ~/Documents   # or wherever you keep your AI projects — any folder works
curl -fsSL -O https://raw.githubusercontent.com/djryanash/ai-masterclass-setup-shell-script/main/start-a-new-project.sh
bash start-a-new-project.sh
```

### Linux Users

Open a terminal, then paste:

```bash
curl -fsSL -O https://raw.githubusercontent.com/djryanash/ai-masterclass-setup-shell-script/main/start-a-new-project.sh
bash start-a-new-project.sh
```

### Windows Users (two steps)

**Step 1 — inside Windows (PowerShell):** install WSL first. Open **PowerShell
as Administrator** (Start → type "PowerShell" → right-click → *Run as
Administrator*), then paste:

```powershell
cd ~\Documents   # or wherever you keep your AI projects
Invoke-WebRequest -OutFile windows-wsl-bootstrap.ps1 https://raw.githubusercontent.com/djryanash/ai-masterclass-setup-shell-script/main/windows-wsl-bootstrap.ps1
powershell -ExecutionPolicy Bypass -File .\windows-wsl-bootstrap.ps1
```

The computer **restarts** at the end of this step.

**Step 2 — inside WSL:** open **Ubuntu** from the Start menu (it asks for a
UNIX username + password — remember that password), then paste:

```bash
curl -fsSL -O https://raw.githubusercontent.com/djryanash/ai-masterclass-setup-shell-script/main/start-a-new-project.sh
bash start-a-new-project.sh
```

---

## All Users Continue Here

1. In your open Terminal window, type the following command and press Enter:

```bash
bash start-a-new-project.sh
```

2. Follow the on-screen terminal instructions carefully. Once complete, Pi will launch in your project directory and be ready to use.

---

## If something goes wrong

* Re-running `bash start-a-new-project.sh` is always safe — every step checks
  before acting, so it resumes or repairs and never repeats work.
* Every real run writes a verbose log to
  `start-a-new-project-installation.log` in the folder you ran the script
  from — **attach that file when asking for help**.
* Windows: the WSL bootstrap (Step 2c / Step 1 of the Windows fallback) writes
  its own log — `windows-wsl-bootstrap-installation.log`, next to the `.ps1`
  file. If you are stuck on WSL not installing, you can also run
  `powershell -ExecutionPolicy Bypass -File .\windows-wsl-bootstrap.ps1 -Report`
  to diagnose without changing anything, then attach that log.
* Good news: you usually don't have to attach anything. The setup script
  automatically uploads its installation log to this repository's Issues page
  (titles start with `[auto]`) when it finishes, and again if something fails.
  Just tell whoever is helping you roughly when you ran the script.
* If Pi fails to launch because of a missing Ollama API key: visit
  <https://ollama.com/settings/keys>, click **Create API Key**, and paste it
  when the script prompts you.

> **NOTE:** If you run into any difficulties or errors, please feel free to ask for assistance.