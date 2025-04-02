# Namecheap DDNS Updater (w/ Mock Server)

This is a lightweight Docker-based mock server that simulates how your home server updates its public IP using Namecheap's [Dynamic DNS (DDNS)](https://www.namecheap.com/support/knowledgebase/article.aspx/29/11/how-do-i-dynamically-update-my-hosts-ip-with-an-http-request/) API.

It's designed to **test and validate** your DDNS update script logic in a containerized environment — without depending on your actual home server.

---

## 📁 Project Structure

```bash
├── Dockerfile        # Builds the testing container 
├── namecheap-ddns.sh # The DDNS update script (entrypoint) 
└── .env.example      # Template for your environment variables
```

## 🚀 Getting Started

### 1. 🔧 Setup Your Environment File

Copy the example environment file and customize it with your own Namecheap credentials and subdomain:

```bash
cp .env.example .env
```

Edit .env:

```
DOMAIN=yourdomain.com
SUBDOMAIN=vpn
PASSWORD=your_ddns_password
DRY_RUN=true
```
⚠️ Never commit your .env file with real credentials. Only .env.example should go in version control.

### 2. 🛠️ Build the Docker Image
```bash
docker build -t mock-namecheap-ddns .
```

### 3. 🧪 Run the Container (Mock Test)
```bash
docker run --rm \
  --env-file .env \
  --name ddns-test \
  mock-namecheap-ddns
```

The script will:

* Load your .env file
* Fetch your current public IP
* Compare it to the DNS record for your subdomain
* Attempt to update the DNS record using Namecheap’s API. If the DRY_RUN environment variable is removed your Namecheap A record will be updated.


## 📓 Notes
* This container does not run persistently — it simply executes the script and exits.
* It's intended for mock testing only (not for production DDNS updates).
* If you plan to automate this on your home server, use a cron job or systemd service instead.
* Automatic log rotation is built-in:

  If the log file (namecheap-ddns.log) grows beyond 1MB, it will be backed up to namecheap-ddns.log.bak and a new log file will be created. This ensures long-running setups won’t accumulate unbounded log files.


## 🛡️ Disclaimer
This project is for educational and testing purposes. Be cautious with API credentials and avoid running this in short intervals to prevent being rate-limited by Namecheap.
