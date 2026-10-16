# Installation Instructions

> **NOTE:** PLEASE READ ALL INSTRUCTIONS CAREFULLY.

* **Windows Users:** Begin at **Step 1**.
* **Linux Users:** Jump to **Step 3**.
* **Mac Users:** Jump to **Step 4**.

---

### Windows Users

#### 1. Extract the Zip File

1. Move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Right-click `ai-website-masterclass.zip` (or two-finger tap / press bottom-right trackpad) and select **Extract All...**.
3. Double-click the extracted `ai-website-masterclass` folder to enter it.

#### 2. Check if Windows Subsystem for Linux (WSL) is Installed

1. Inside the `ai-website-masterclass` folder, press Ctrl + L to focus the address bar.
2. Type `wsl` and press Enter.
* **If a WSL Terminal window opens:** WSL is installed. Proceed to **Step 2b** below.
* **If an error or command-not-found prompt appears:** Proceed to **Step 2c**.



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

---

### Linux Users

#### 3. Extract and Open Terminal

1. In **File Manager**, move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Right-click `ai-website-masterclass.zip` (or two-finger tap / press bottom-right trackpad) and select **Extract Here**.
3. Once extracted, delete the `.zip` file.
4. Double-click the extracted `ai-website-masterclass` folder to enter it.
5. Right-click any empty space inside the folder and select **Open in Terminal** (or **Open Terminal Here**).
6. Jump to **All Users Continue Here**.

---

### Mac Users

#### 4. Extract and Open Terminal

1. In **Finder**, move `ai-website-masterclass.zip` to your preferred folder for AI Agent Projects.
2. Double-click `ai-website-masterclass.zip` to extract it.
3. Once extracted, delete the `.zip` file.
4. Right-click (or Control + click) the extracted `ai-website-masterclass` folder.
5. Select **Services** $\rightarrow$ **New Terminal at Folder** (or **New Terminal at Folder** directly from the context menu).
6. Jump to **All Users Continue Here**.

---

### All Users Continue Here

1. In your open Terminal window, type the following command and press Enter:
```bash
bash start-a-new-project.sh

```


2. Follow the on-screen terminal instructions carefully. Once complete, Pi will launch in your project directory and be ready to use.

---

> **NOTE:** If you run into any difficulties or errors, please feel free to ask for assistance.