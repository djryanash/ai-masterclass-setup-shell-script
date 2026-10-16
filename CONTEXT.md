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
git repository / deployed site. Names the student types are automatically
adjusted to kebab-case (lowercase letters, digits, and hyphens) before use —
the same name is used for the folder, the GitHub repository, and Vercel.

*Not to be confused with:* the **Launch Directory** — the Project Folder is
*inside* it.

### Installation Log
The single log file the setup script writes during a run: a verbose record of
everything the script did and everything that failed. It lives in the Launch
Directory. Each run overwrites it — it describes the most recent attempt, not
run history. Every run identifies the **Script Revision** it ran under, and
when a run ends (successfully or not) the log is automatically uploaded as an
`[auto]` issue on the suite's GitHub repository, so support never has to ask
for the file.

### Script Revision
A short marker (e.g. `2026-10-16O`) printed at the start of every run and in
every Installation Log, identifying which version of the Setup Script ran.
The first thing to check when helping a student.

### Setup Script
The shell script that installs the full taught toolchain (git, gh, Node via
nvm, Ollama, Pi, Vercel CLI), configures Pi, installs skills (see **Custom
Skills Folder** and **Canonical Skills Repo**), creates the Project Folder,
and ends by launching Pi inside it — followed by handing the student a fresh,
ready-to-use shell in the Project Folder (which re-reads the profile, so `pi`
and `node` work there immediately).

### Ollama API Key
The API key the student creates at `https://ollama.com/settings/keys`
("Create API Key") after signing up and adding prepaid credit. The **only**
authentication Pi needs — there is no `/login` or token file. The Setup Script
will refuse to launch Pi without it, and asks for it twice (credentials step
and again at the launch gate).

*Not to be confused with:* the **Ollama account password** (never used by the
script) or a GitHub login (handled separately in an earlier step).

### Custom Skills Folder
A folder named `ryans-ai-agent-skills` placed in the Launch Directory (or
beside the Setup Script), holding private skills for a single student. Its
contents are copied into the skill directory at every run; the folder itself
is removed only after a successful, correctly laid-out install (a folder with
no `SKILL.md` files is left in place with a layout warning).

### Canonical Skills Repo
The public GitHub repository (`djryanash/ryans-agent-skills`) from which the
shared class skills are refreshed on every run of the Setup Script. Skills
from the repo are added/replace-last, so a repo skill wins a name conflict
with a **Custom Skills Folder** skill.

*Not to be confused with:* this script suite's repository.