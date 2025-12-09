# Task Manager Application

A collaborative task management application with real-time updates, built for ECE1779.

## 🌟 Features

- **User Authentication**: Secure registration and login
- **Team Management**: Create teams and manage memberships with role-based access (Admin/Member)
- **Projects & Tasks**: Organize tasks within team projects
- **Real-time Updates**: Socket.IO powered live task updates across all clients
- **Task Assignment**: Assign tasks to team members
- **Task Status Tracking**: Track tasks through To-Do, In Progress, and Done states
- **Activity Logging**: Complete audit trail of all task activities
- **Search & Filtering**: Find tasks by title, description, or assignee

## 🏗️ Architecture

- **Backend**: Node.js + Express.js
- **Database**: PostgreSQL 16
- **Real-time**: Socket.IO for WebSocket connections
- **Session Management**: PostgreSQL-backed session storage
- **Authentication**: bcrypt for password hashing

## 🚀 Deployment Options

### Option 1: Local Development (Docker Compose)

Perfect for development and testing.

**Prerequisites:**
- Docker and Docker Compose installed

**Quick Start (Windows + PowerShell):**

```powershell
cd .\infra

# 1) Start containers
docker compose up -d

# 2) Register demo users (Zicong and Alex)
Invoke-RestMethod -Uri http://localhost:3000/auth/register -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345","name":"Zicong"}' | Out-Null

Invoke-RestMethod -Uri http://localhost:3000/auth/register -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"a.chia@mail.utoronto.ca","password":"12345","name":"Alex"}' | Out-Null

# 3) Check user IDs
docker compose exec -T db `
  psql -U taskapp -d taskdb `
  -c "SELECT id, email, name FROM users ORDER BY id;"

# 4) Create Team 14
docker compose exec -T db `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO teams(name) VALUES('Team 14') RETURNING id, name;"

# 5) Make Zicong the Admin of Team 14
docker compose exec -T db `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO team_memberships(user_id, team_id, role) VALUES(1, 1, 'Admin');"

# 6) Create the ECE1779 project under Team 14
docker compose exec -T db `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO projects(team_id, name) VALUES(1, 'ECE1779 Task Board') RETURNING id, team_id, name;"

# Access the application:
#   Web UI: http://localhost:3000/
#   Real-time: http://localhost:3000/realtime.html
```

**Linux/Mac:**

```bash
cd infra

# Start containers
docker compose up -d

# Access at http://localhost:3000/
```

### Option 2: Production Deployment (Kubernetes on DigitalOcean)

Scalable, production-ready deployment with high availability.

**Prerequisites:**
- DigitalOcean account
- kubectl installed
- doctl (DigitalOcean CLI) installed

**Quick Deploy:**

```bash
# Navigate to k8s directory
cd infra/k8s

# Deploy everything
./deploy.sh          # Linux/Mac
./deploy.ps1         # Windows PowerShell
```

**📖 Complete Guide:** See [infra/k8s/KUBERNETES_DEPLOYMENT.md](infra/k8s/KUBERNETES_DEPLOYMENT.md) for:
- Step-by-step DigitalOcean cluster setup
- Container registry configuration
- SSL/TLS setup with Let's Encrypt
- Domain configuration
- Monitoring and scaling
- Troubleshooting

**🔧 Quick Reference:** See [infra/k8s/QUICK_REFERENCE.md](infra/k8s/QUICK_REFERENCE.md) for common commands and operations.

## 💻 Web UI & Demo Walkthrough

The UI is served from the `api/public/index.html` file and is available at:

- Local Docker Compose: http://localhost:3000/
- DigitalOcean Kubernetes: http://209.38.0.81/

A demo flow:

1. **Login**
   - Use one of the demo accounts:
     - `zicong.shao@mail.utoronto.ca` / `12345`
     - `a.chia@mail.utoronto.ca` / `12345`
   - After login, the session is stored in PostgreSQL using `connect-pg-simple`.

2. **Create a team & project**
   - Use the “Create Project” section to create a project under that team.

3. **Create tasks**
   - In the “Create Task” section, provide:
     - `project_id`
     - title / description
     - optional assignee IDs (comma-separated)
   - A task will be inserted into the `tasks` table and initial activity is logged.

4. **Assign & update status**
   - Use the “Assign” controls to add assignees to an existing task.
   - Use the status dropdown to move a task between `To-Do`, `In Progress`, and `Done`.
   - Each change writes an entry into `task_activity_log`.

5. **Search & filter tasks**
   - Use the “Load My Tasks” section:
     - `query` (search in title/description)
     - `assignee_id` filter

6. **View activity timeline**
   - Enter a task ID in the “Activity” section and click “Load Activity”.
   - The UI calls `GET /tasks/:id/activity` and displays the chronological log.

7. **Realtime events**
   - Open a second tab at `http://localhost:3000/realtime.html` (or `http://209.38.0.81/realtime.html`).
   - When you create/assign/update tasks in the main UI, the realtime page will show:
     - `task_created`
     - `task_assigned`
     - `task_status_changed`


## 📁 Project Structure
```
ECE1779-Project-Taskmanager/
├ .github/
│   └── workflows/
│       └── ci.yml                  # GitHub Actions CI/CD pipeline
├ api/
│   ├── app.js                      # Main application server
│   ├── package.json                # Node.js dependencies & scripts
│   ├── Dockerfile                  # Container image definition
│   └── public/                     # Static HTML files
│       ├── index.html              # Main Web UI (login, projects, tasks, overview)
│       └── realtime.html           # Real-time task events demo (WebSockets)
├ infra/
│   ├── compose.yml                 # Docker Compose configuration
│   ├── db/
│   │   └── init.sql                # Database schema 
│   ├── backups/
│   │   ├── backup_to_spaces.ps1    # Powershell script: dump + upload DB to DO Spaces
│   │   └── .gitignore              # Ignore local *.sql dump files
│   └── k8s/
│       ├── *.yaml                  # Kubernetes manifests (API, Postgres, ingress, etc.)
│       ├── KUBERNETES_DEPLOYMENT.md# Full K8s deployment guide
│       └── QUICK_REFERENCE.md      # Command reference
└ README.md                         # This file
```

## 🔌 API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login
- `POST /auth/logout` - Logout

### Teams
- `POST /teams` - Create team
- `POST /teams/:id/members` - Add team member

### Projects
- `POST /projects` - Create project

### Tasks
- `POST /tasks` - Create task
- `GET /tasks` - List tasks (with optional filtering)
- `POST /tasks/:id/assignees` - Assign users to task
- `PATCH /tasks/:id/status` - Update task status
- `GET /tasks/:id/activity` - Get task activity log

### Health
- `GET /check` - Health check endpoint

## 🔄 Real-time Events

Socket.IO events emitted by the server:
- `task_created` - New task created
- `task_assigned` - Task assigned to users
- `task_status_changed` - Task status updated

## 🗄️ Database Schema

- **users** - User accounts
- **teams** - Team definitions
- **team_memberships** - User-team relationships with roles
- **projects** - Projects within teams
- **tasks** - Task items
- **task_assignees** - Task assignments
- **task_activity_log** - Complete activity audit trail

## 🛠️ Development

### Running Locally (without Docker)

```bash
# Install PostgreSQL 16
# Create database and run init.sql

cd api
npm install

# Create .env file
cat > .env << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=taskdb
DB_USER=taskapp
DB_PASSWORD=taskpass
SESSION_SECRET=your_session_secret
EOF

npm run dev
```

### Building Docker Image

```bash
cd api
docker build -t taskmanager-api:latest .
```

## 🔐 Security Notes

- **Change default passwords** in production!
- Use **strong session secrets** (generate with `openssl rand -base64 32`)
- Enable **SSL/TLS** for production deployments
- Regularly **update dependencies** for security patches
- Use **environment variables** for sensitive configuration
- Never commit secrets to version control

## 📊 Operations

### Docker Compose

```bash
# View logs
docker compose logs -f api

# Access database
docker compose exec db psql -U taskapp -d taskdb

# Stop services
docker compose down
```

### Kubernetes

```bash
# View logs
kubectl logs -f -l app=taskmanager-api -n taskmanager

# Check status
kubectl get all -n taskmanager

# Access database
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb
```

## 🐛 Troubleshooting

### Docker Compose Issues

**Database connection failed:**
```bash
# Check if database is ready
docker compose ps
docker compose logs db
```

**Port already in use:**
```bash
# Change port in compose.yml or stop conflicting service
```
### Kubernetes Issues

See [infra/k8s/QUICK_REFERENCE.md](infra/k8s/QUICK_REFERENCE.md) for comprehensive troubleshooting guide.

## 📈 Monitoring & Alerting (DigitalOcean)

### Cluster monitoring (DigitalOcean dashboard)

We use DigitalOcean’s built-in monitoring for the Kubernetes cluster instead of running our own Prometheus stack.

- The **Insights** dashboard shows time-series graphs for the worker nodes, including:
  - **CPU Usage** – average / max / min CPU percent over time.
  - **Load Average** – 1 / 5 / 15 minute load averages.
  - **Memory Usage** – percentage of node memory in use.
  - **Disk Usage** – percentage of root disk in use.

### Alerting with DigitalOcean Resource Alerts

- We configured a single alert rule:
  - **Name:** `CPU Utilization Percent is running high`
  - **Applied to:** `All Droplets` (this includes the Kubernetes worker nodes of our cluster).
  - **Condition:** CPU utilization **> 75%** for **5 minutes**.
  - **Notification:** DigitalOcean sends an email notification to the project owners when the condition is met.

Alerts are delivered via email to the team so that we can quickly investigate issues in the
Kubernetes cluster.

## Automated Database Backups to DigitalOcean Spaces

This section describes how to run and schedule automated PostgreSQL backups from the Docker
infrastructure to a DigitalOcean Spaces bucket.

The backup logic lives under the `infra/` folder and is implemented in:

- `infra/compose.yml` – defines the `db` PostgreSQL container.
- `infra/backup_to_spaces.ps1` – PowerShell script that dumps the database and uploads it to Spaces.
- `infra/backups/` – local folder where `.sql` dump files are stored before upload.

---

### 1. One-time setup on DigitalOcean

1. **Create a Spaces bucket**

   - Go to **Spaces Object Storage** in the DigitalOcean control panel.
   - Create a bucket with:
     - **Name:** `ece1779-taskmanager-backups`
     - **Region:** `TOR1` (API region code: `tor1`)
     - **Storage type:** Standard
   - After creation, the bucket origin URL looks like:

     ```text
     https://ece1779-taskmanager-backups.tor1.digitaloceanspaces.com
     ```

2. **Create a Spaces access key**

   - In the DO panel, open **Spaces → Access Keys**.
   - Create a new access key (limited to this bucket is recommended).
   - Save the two values:
     - `Access key`
     - `Secret key`
   - These will be used when configuring the AWS CLI.

---

### 2. One-time setup on the backup machine

  **Install AWS CLI v2**

   - Download and install AWS CLI for Windows from the official installer, or:

     ```powershell
     winget install --id Amazon.AWSCLI -e
     ```

   - Verify:

     ```powershell
     aws --version
     ```

 **Configure AWS CLI to use DigitalOcean Spaces**

 Use the Spaces access key and secret key you created earlier:

 AWS Access Key ID: <your Spaces access key>

 AWS Secret Access Key: <your Spaces secret key>

 Default region name: tor1

 Default output format: leave blank

   ```powershell
   aws configure

### 3. Run a Backup manually

  # Go to infra
  cd "<path-to-project>\infra"

  # Make sure Docker services are running
  docker compose up -d

  # Run the backup script (dump + upload)
  .\backup_to_spaces.ps1

  # Check local backup files
  ls .\backups
  # Expect: taskdb_YYYYMMDD-HHMMSS.sql
  # You should see the same .sql file show in the ece1779-taskmanager-backups Space.

### 4. Schedule daily backups on Windows
 #To avoid using any external scheduler, we use Powershell Scheduled Jobs
  # Register a daily job at 01:00 AM
  $scriptPath = (Resolve-Path .\backup_to_spaces.ps1).Path
  $trigger    = New-JobTrigger -Daily -At 1:00am

  Register-ScheduledJob -Name "DailyDbBackupToSpaces" -FilePath $scriptPath -Trigger $trigger

  # List scheduled jobs 
  Get-ScheduledJob
  # Expect: DailyDbBackupToSpaces

  # Manually trigger the scheduled job once
  Start-Job -DefinitionName "DailyDbBackupToSpaces"

  # Check
  ls .\backups

### 5. Debugging
  # See job instances and states
  Get-Job
  # Inspect output/errors of a specific job instance
  Receive-Job -Id <jobId> -Keep
  ```
## CI pipeline

#### The CI pupeline runs on Github Actions and builds for health checks on API services when any change is pushed. 

### The purpose of CI pipeline
    • Automatically runs on every push and pull request to the main branches (main and k8s-feature).
    • Checks out the repository and installs Node.js on a clean GitHub-hosted runner.
    • Installs API dependencies in the api folder using npm ci and package-lock.json so that the same versions are used locally and in CI.
    • Runs npm test in the api folder to execute the Jest + Supertest health-check test for GET /health.
    • Marks the commit or pull request as “passing” or “failing” based on whether dependencies install successfully and the tests pass.
    • Provides detailed logs for each step so a reviewer can see exactly where a failure occurs (dependency error, test failure, etc.).

### If you are reviewing the project in our original GitHub repository:

    • Open the repository on GitHub.
    • Click the “Actions” tab at the top.
    • If GitHub shows a banner like “Workflows are disabled for this repository”, click the button to enable them.
    • After workflows are enabled:
       Any new commit pushed to main or k8s-feature will automatically trigger the CI pipeline.
       Any pull request targeting main or k8s-feature will also trigger the CI pipeline.

  
    In the Actions tab, click the latest run to see details.
    You will see steps such as:
    -Checkout repository
    -Set up Node.js
    -Install dependencies in the api folder using npm ci
    -Run tests in the api folder using npm test
    If all steps show green check marks, the CI run has succeeded.

## CD pipeline

#### It is for building the Docker Image and pushing it to DigitalOcean Container Registry and deploying the latest version to Kubernetes Cluster. 

### The purpose of CD pipeline
        • Triggered when the CI job has passed for main or k8s-feature.
        • Applies doctl with DIGITALOCEAN_ACCESS_TOKEN 
        • Logs in to DigitalOcean Container Registry by DO_REGISTRY.
        • Builds a Docker image based on the api directory with a tag name of $REGISTRY/task-api:latest.
        • Pushes this image to a registry accessible for pulling by this cluster.
        • Retrieves a kubeconfig for a Kubernetes cluster using DO_CLUSTER_NAME.
        • Executes kubectl apply -f infra/k8s to synchronize deployments, services, cron jobs, Postgres, and more.
        • Executes kubectl rollout restart deployment/taskmanager-api -n taskmanager to refresh the API pods with the latest image.

### If you are reviewing the project in our original GitHub repository:

### Three GitHub Actions secrets:
    DIGITALOCEAN_ACCESS_TOKEN – DigitalOcean personal access token.
    DO_REGISTRY – registry.digitalocean.com/taskmanager-registry.
    DO_CLUSTER_NAME – taskmanager-cluster.

After pushing commit
Wait for the CI job to turn green.

#
    In the “Actions” tab:
    Open the latest workflow run.
    Click the job named “Deploy to DigitalOcean Kubernetes”.
    You should see steps like:
    -Install doctl (DigitalOcean CLI)  
    -Auth doctl with DigitalOcean token  
    -Log in to DigitalOcean Container Registry  
    -Build and push API image  
    -Save kubeconfig for cluster  
    -Apply Kubernetes manifests  

If all of these steps have green check marks, the CD run is successful and the new API version is running on the DigitalOcean Kubernetes cluster(reachable at http://209.38.0.81).

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [DigitalOcean Kubernetes Guide](https://docs.digitalocean.com/products/kubernetes/)
- [Express.js Documentation](https://expressjs.com/)
- [Socket.IO Documentation](https://socket.io/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 👥 Team

ECE1779 - Team 14
- Zicong Shao
- Alex Chia

## 📝 License

This project is part of ECE1779 course work.
