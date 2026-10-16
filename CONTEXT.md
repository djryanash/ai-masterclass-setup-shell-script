# CONTEXT.md

Glossary for the `start-a-new-project` script suite. Domain language only —
no implementation details live here.

## Terms

### Launch Directory
The folder where the student runs the setup script. Every artifact the script
produces lives here or in a sub-folder — students never have to look anywhere
else (the audience is complete beginners).

*Not to be confused with:* the **Project Folder**.

### Project Folder
The sub-folder created inside the Launch Directory during setup (default name
`my-website`). This is the working directory Pi opens in, and the root of the
git repository / deployed site.

*Not to be confused with:* the **Launch Directory** — the Project Folder is
*inside* it.

### Installation Log
The single log file the setup script writes during a run: a verbose record of
everything the script did and everything that failed. It lives in the Launch
Directory. Each run overwrites it — it describes the most recent attempt, not
run history.

### Setup Script
The shell script that installs the full taught toolchain (git, gh, Node via
nvm, Ollama, Pi, Vercel CLI), configures Pi, creates the Project Folder, and
ends by launching Pi inside it.