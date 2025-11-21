# Demo Setup Guide - Kubernetes Deployment

This guide walks you through setting up demo users and data on your Kubernetes-deployed Task Manager application.

## Prerequisites

- Application successfully deployed to Kubernetes
- LoadBalancer IP address available (check with `kubectl get ingress -n taskmanager`)
- PowerShell or bash terminal access
- `kubectl` configured and connected to your cluster

## Your Application URL

After deployment, get your LoadBalancer IP:

```powershell
kubectl get ingress -n taskmanager
```

For this guide, we'll use: **http://152.42.145.25** (replace with your actual IP)

---

## Quick Start Demo Setup

### Step 1: Register Demo Users (Zicong and Alex)

```powershell
# Register Zicong
Invoke-RestMethod -Uri http://152.42.145.25/auth/register -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345","name":"Zicong"}'

# Register Alex
Invoke-RestMethod -Uri http://152.42.145.25/auth/register -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"a.chia@mail.utoronto.ca","password":"12345","name":"Alex"}'
```

### Step 2: Check User IDs

```powershell
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "SELECT id, email, name FROM users ORDER BY id;"
```

Expected output:
```
 id |            email             |  name  
----+------------------------------+--------
  1 | zicong.shao@mail.utoronto.ca | Zicong
  2 | a.chia@mail.utoronto.ca      | Alex
```

### Step 3: Create Team 14

```powershell
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO teams(name) VALUES('Team 14') RETURNING id, name;"
```

Expected output:
```
 id |  name   
----+---------
  1 | Team 14
```

### Step 4: Make Zicong the Admin of Team 14

Assumes Zicong has `user_id = 1` and `team_id = 1`:

```powershell
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO team_memberships(user_id, team_id, role) VALUES(1, 1, 'Admin');"
```

### Step 5: Create the ECE1779 Project under Team 14

```powershell
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO projects(team_id, name) VALUES(1, 'ECE1779 Task Board') RETURNING id, team_id, name;"
```

Expected output:
```
 id | team_id |        name        
----+---------+--------------------
  1 |       1 | ECE1779 Task Board
```

### Step 6: Add Alex to Team 14 as a Member (Optional)

```powershell
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "INSERT INTO team_memberships(user_id, team_id, role) VALUES(2, 1, 'Member');"
```

---

## Verify Setup

Check that everything is configured correctly:

```powershell
# View all users
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "SELECT id, email, name FROM users;"

# View team memberships
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "SELECT u.name, t.name as team, tm.role FROM users u JOIN team_memberships tm ON u.id = tm.user_id JOIN teams t ON tm.team_id = t.id;"

# View projects
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "SELECT p.id, p.name, t.name as team FROM projects p JOIN teams t ON p.team_id = t.id;"
```

---

## Access the Application

### Web UI

Open in your browser:
```
http://152.42.145.25/
```

**Login as Zicong:**
- Email: `zicong.shao@mail.utoronto.ca`
- Password: `12345`

**Login as Alex:**
- Email: `a.chia@mail.utoronto.ca`
- Password: `12345`

### Real-time Updates Page

View live task updates:
```
http://152.42.145.25/realtime.html
```

---

## Using the API via PowerShell

### Login and Get Session

```powershell
# Login as Zicong
$loginResponse = Invoke-WebRequest -Uri http://152.42.145.25/auth/login -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' `
  -SessionVariable session

# Check login success
$loginResponse.Content | ConvertFrom-Json
```

### Create a Task

```powershell
# Create a task (must be logged in)
$taskData = @{
    project_id = 1
    title = "Complete ECE1779 Assignment"
    description = "Finish the cloud computing project"
    assignees = @(1, 2)  # Assign to both Zicong and Alex
} | ConvertTo-Json

Invoke-RestMethod -Uri http://152.42.145.25/tasks -Method Post `
  -ContentType 'application/json' `
  -Body $taskData `
  -WebSession $session
```

### List All Tasks

```powershell
# Get all tasks
Invoke-RestMethod -Uri http://152.42.145.25/tasks -WebSession $session
```

### Update Task Status

```powershell
# Update task 1 to "In Progress"
$statusUpdate = @{
    status = "In Progress"
} | ConvertTo-Json

Invoke-RestMethod -Uri http://152.42.145.25/tasks/1/status -Method Patch `
  -ContentType 'application/json' `
  -Body $statusUpdate `
  -WebSession $session
```

### Assign Task to User

```powershell
# Assign task 1 to additional users
$assignData = @{
    user_ids = @(2)  # Assign to Alex
} | ConvertTo-Json

Invoke-RestMethod -Uri http://152.42.145.25/tasks/1/assignees -Method Post `
  -ContentType 'application/json' `
  -Body $assignData `
  -WebSession $session
```

### Get Task Activity Log

```powershell
# View activity history for task 1
Invoke-RestMethod -Uri http://152.42.145.25/tasks/1/activity -WebSession $session
```

---

## Linux/Mac Commands

If you're using Linux or Mac, use these equivalent commands:

### Register Users

```bash
# Register Zicong
curl -X POST http://152.42.145.25/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"zicong.shao@mail.utoronto.ca","password":"12345","name":"Zicong"}'

# Register Alex
curl -X POST http://152.42.145.25/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"a.chia@mail.utoronto.ca","password":"12345","name":"Alex"}'
```

### Database Commands

```bash
# Check user IDs
kubectl exec postgres-0 -n taskmanager -- \
  psql -U taskapp -d taskdb \
  -c "SELECT id, email, name FROM users ORDER BY id;"

# Create Team 14
kubectl exec postgres-0 -n taskmanager -- \
  psql -U taskapp -d taskdb \
  -c "INSERT INTO teams(name) VALUES('Team 14') RETURNING id, name;"

# Make Zicong the Admin
kubectl exec postgres-0 -n taskmanager -- \
  psql -U taskapp -d taskdb \
  -c "INSERT INTO team_memberships(user_id, team_id, role) VALUES(1, 1, 'Admin');"

# Create ECE1779 project
kubectl exec postgres-0 -n taskmanager -- \
  psql -U taskapp -d taskdb \
  -c "INSERT INTO projects(team_id, name) VALUES(1, 'ECE1779 Task Board') RETURNING id, team_id, name;"
```

### Login and Create Task

```bash
# Login and save cookies
curl -X POST http://152.42.145.25/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' \
  -c cookies.txt

# Create a task
curl -X POST http://152.42.145.25/tasks \
  -H "Content-Type: application/json" \
  -d '{"project_id":1,"title":"Complete ECE1779 Assignment","description":"Finish the cloud computing project","assignees":[1,2]}' \
  -b cookies.txt

# List tasks
curl http://152.42.145.25/tasks -b cookies.txt
```

---

## Sample Data Creation Script

Create multiple tasks for demonstration:

### PowerShell Script

```powershell
# Login as Zicong
$loginResponse = Invoke-WebRequest -Uri http://152.42.145.25/auth/login -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' `
  -SessionVariable session

# Create multiple tasks
$tasks = @(
    @{ title = "Set up development environment"; description = "Install Node.js, Docker, and kubectl"; assignees = @(1) },
    @{ title = "Design database schema"; description = "Create ER diagram and SQL scripts"; assignees = @(1, 2) },
    @{ title = "Implement API endpoints"; description = "Build REST API for task management"; assignees = @(1) },
    @{ title = "Create frontend UI"; description = "Build React components for task board"; assignees = @(2) },
    @{ title = "Deploy to Kubernetes"; description = "Set up K8s manifests and deploy to DigitalOcean"; assignees = @(1, 2) }
)

foreach ($task in $tasks) {
    $taskData = @{
        project_id = 1
        title = $task.title
        description = $task.description
        assignees = $task.assignees
    } | ConvertTo-Json

    Write-Host "Creating task: $($task.title)"
    Invoke-RestMethod -Uri http://152.42.145.25/tasks -Method Post `
      -ContentType 'application/json' `
      -Body $taskData `
      -WebSession $session
    
    Start-Sleep -Milliseconds 500
}

Write-Host "✅ Created $($tasks.Count) demo tasks!"
```

### Bash Script

```bash
#!/bin/bash

# Login and save cookies
curl -s -X POST http://152.42.145.25/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' \
  -c cookies.txt > /dev/null

# Create tasks
declare -a tasks=(
  '{"project_id":1,"title":"Set up development environment","description":"Install Node.js, Docker, and kubectl","assignees":[1]}'
  '{"project_id":1,"title":"Design database schema","description":"Create ER diagram and SQL scripts","assignees":[1,2]}'
  '{"project_id":1,"title":"Implement API endpoints","description":"Build REST API for task management","assignees":[1]}'
  '{"project_id":1,"title":"Create frontend UI","description":"Build React components for task board","assignees":[2]}'
  '{"project_id":1,"title":"Deploy to Kubernetes","description":"Set up K8s manifests and deploy to DigitalOcean","assignees":[1,2]}'
)

for task in "${tasks[@]}"; do
  curl -s -X POST http://152.42.145.25/tasks \
    -H "Content-Type: application/json" \
    -d "$task" \
    -b cookies.txt > /dev/null
  echo "Created task"
  sleep 0.5
done

echo "✅ Created ${#tasks[@]} demo tasks!"

# Cleanup
rm cookies.txt
```

---

## Testing Real-time Updates with realtime.html

### What is realtime.html?

The `realtime.html` page is a **live event feed** that displays real-time Socket.IO events for your task management system. It's perfect for monitoring activity, testing WebSocket connections, and demonstrating collaborative features.

### What It Displays

1. **Connection Status**
   - Shows "connected" (green) when Socket.IO is connected
   - Shows "disconnected" (red) when connection is lost

2. **Live Event Feed**
   - Updates instantly without page refresh
   - New events appear at the top (most recent first)
   - Shows all task-related activities from all users

### Events Monitored

The page monitors three types of real-time events:

1. **`task_created`** - When a new task is created
   ```
   created  #2 "Complete ECE1779 Assignment"
   ```

2. **`task_assigned`** - When users are assigned to a task
   ```
   assigned #2 -> [1,2]
   ```

3. **`task_status_changed`** - When task status changes
   ```
   status   #2 -> In Progress
   status   #2 -> Done
   ```

### How to Test Real-time Updates

#### Method 1: Two Browser Windows

1. **Open the real-time page** in one browser window:
   ```
   http://152.42.145.25/realtime.html
   ```

2. **Open the main app** in another window:
   ```
   http://152.42.145.25/
   ```

3. **Login** as Zicong or Alex and create/update tasks

4. **Watch the first window** - Events appear instantly without refresh!

#### Method 2: Automated Demo Script

Run this PowerShell script to see all three event types in action:

**PowerShell (Windows):**

```powershell
# Save as demo-realtime.ps1

# Open the realtime page in a browser
Start-Process "http://152.42.145.25/realtime.html"
Write-Host "`nWatch the browser for real-time updates...`n" -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Login as Zicong
Write-Host "1. Logging in as Zicong..." -ForegroundColor Yellow
$loginResponse = Invoke-WebRequest -Uri http://152.42.145.25/auth/login -Method Post `
  -ContentType 'application/json' `
  -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' `
  -SessionVariable session

# Create a task (triggers 'created' and 'assigned' events)
Write-Host "2. Creating a task (watch for 'created' event)..." -ForegroundColor Yellow
$taskData = @{
    project_id = 1
    title = "Demo Real-time Task"
    description = "Watch the events appear live!"
    assignees = @(1)
} | ConvertTo-Json

$task = Invoke-RestMethod -Uri http://152.42.145.25/tasks -Method Post `
  -ContentType 'application/json' -Body $taskData -WebSession $session
$taskId = $task.id
Write-Host "   ✓ Created task #$taskId" -ForegroundColor Green
Start-Sleep -Seconds 2

# Assign another user (triggers 'assigned' event)
Write-Host "3. Assigning task to Alex (watch for 'assigned' event)..." -ForegroundColor Yellow
$assignData = @{ user_ids = @(2) } | ConvertTo-Json
Invoke-RestMethod -Uri "http://152.42.145.25/tasks/$taskId/assignees" -Method Post `
  -ContentType 'application/json' -Body $assignData -WebSession $session
Write-Host "   ✓ Assigned task #$taskId to Alex (user 2)" -ForegroundColor Green
Start-Sleep -Seconds 2

# Update status to In Progress (triggers 'status_changed' event)
Write-Host "4. Changing status to 'In Progress' (watch for 'status' event)..." -ForegroundColor Yellow
$statusData = @{ status = "In Progress" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://152.42.145.25/tasks/$taskId/status" -Method Patch `
  -ContentType 'application/json' -Body $statusData -WebSession $session
Write-Host "   ✓ Status changed to 'In Progress'" -ForegroundColor Green
Start-Sleep -Seconds 2

# Update status to Done (triggers another 'status_changed' event)
Write-Host "5. Completing task (watch for 'status' event)..." -ForegroundColor Yellow
$statusData = @{ status = "Done" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://152.42.145.25/tasks/$taskId/status" -Method Patch `
  -ContentType 'application/json' -Body $statusData -WebSession $session
Write-Host "   ✓ Status changed to 'Done'" -ForegroundColor Green
Start-Sleep -Seconds 1

Write-Host "`n✅ Demo complete! Check the browser to see all events.`n" -ForegroundColor Cyan
Write-Host "You should see 5 events:" -ForegroundColor White
Write-Host "  • status   #$taskId -> Done" -ForegroundColor Gray
Write-Host "  • status   #$taskId -> In Progress" -ForegroundColor Gray
Write-Host "  • assigned #$taskId -> [2]" -ForegroundColor Gray
Write-Host "  • assigned #$taskId -> [1]" -ForegroundColor Gray
Write-Host "  • created  #$taskId ""Demo Real-time Task""" -ForegroundColor Gray
```

**Bash (Linux/Mac):**

```bash
#!/bin/bash

# Save as demo-realtime.sh and run: chmod +x demo-realtime.sh && ./demo-realtime.sh

echo -e "\n\033[0;36mOpen http://152.42.145.25/realtime.html in your browser now!\033[0m"
echo "Press Enter when ready..."
read

# Login as Zicong
echo -e "\n\033[0;33m1. Logging in as Zicong...\033[0m"
curl -s -X POST http://152.42.145.25/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"zicong.shao@mail.utoronto.ca","password":"12345"}' \
  -c cookies.txt > /dev/null

# Create a task
echo -e "\033[0;33m2. Creating a task (watch for 'created' event)...\033[0m"
TASK_RESPONSE=$(curl -s -X POST http://152.42.145.25/tasks \
  -H "Content-Type: application/json" \
  -d '{"project_id":1,"title":"Demo Real-time Task","description":"Watch the events appear!","assignees":[1]}' \
  -b cookies.txt)
TASK_ID=$(echo $TASK_RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo -e "   \033[0;32m✓ Created task #$TASK_ID\033[0m"
sleep 2

# Assign another user
echo -e "\033[0;33m3. Assigning task to Alex (watch for 'assigned' event)...\033[0m"
curl -s -X POST http://152.42.145.25/tasks/$TASK_ID/assignees \
  -H "Content-Type: application/json" \
  -d '{"user_ids":[2]}' \
  -b cookies.txt > /dev/null
echo -e "   \033[0;32m✓ Assigned task #$TASK_ID to Alex\033[0m"
sleep 2

# Update status to In Progress
echo -e "\033[0;33m4. Changing status to 'In Progress' (watch for 'status' event)...\033[0m"
curl -s -X PATCH http://152.42.145.25/tasks/$TASK_ID/status \
  -H "Content-Type: application/json" \
  -d '{"status":"In Progress"}' \
  -b cookies.txt > /dev/null
echo -e "   \033[0;32m✓ Status changed to 'In Progress'\033[0m"
sleep 2

# Update status to Done
echo -e "\033[0;33m5. Completing task (watch for 'status' event)...\033[0m"
curl -s -X PATCH http://152.42.145.25/tasks/$TASK_ID/status \
  -H "Content-Type: application/json" \
  -d '{"status":"Done"}' \
  -b cookies.txt > /dev/null
echo -e "   \033[0;32m✓ Status changed to 'Done'\033[0m"
sleep 1

echo -e "\n\033[0;36m✅ Demo complete! Check the browser to see all events.\033[0m\n"
echo "You should see 5 events:"
echo "  • status   #$TASK_ID -> Done"
echo "  • status   #$TASK_ID -> In Progress"
echo "  • assigned #$TASK_ID -> [2]"
echo "  • assigned #$TASK_ID -> [1]"
echo "  • created  #$TASK_ID \"Demo Real-time Task\""

# Cleanup
rm -f cookies.txt
```

### Advanced Testing: Multiple Users Simultaneously

To see true real-time collaboration:

1. **Open realtime.html** on one screen/device
2. **Login as Zicong** in a browser window
3. **Login as Alex** in another browser window (or Incognito mode)
4. **Both users** create and update tasks
5. **Watch realtime.html** show all activities from both users instantly!

### Debugging WebSocket Connection

Open browser Developer Console (F12) on the realtime.html page:

```javascript
// In the console, you should see:
// Socket.IO connection established

// You can manually test events:
s.on('task_created', (data) => {
  console.log('Task created:', data);
});

// Check connection status:
s.connected  // should be true
```

### Use Cases for realtime.html

1. **Monitoring Dashboard** - Keep open on a second monitor to track team activity
2. **Testing** - Verify Socket.IO is working correctly during development
3. **Debugging** - Watch events as they fire in real-time
4. **Demonstrations** - Show live collaboration features to stakeholders
5. **Activity Feed** - See what team members are working on
6. **Integration Testing** - Verify API changes trigger correct events

### What Makes Real-time Work?

The application uses **Socket.IO** which maintains a persistent WebSocket connection. When anyone performs actions (even from different browsers, devices, or locations), events instantly broadcast to all connected clients.

**Architecture:**
```
Browser 1 (Zicong)          Browser 2 (realtime.html)
     |                              |
     | HTTP: Create task            |
     |----------------------------->|
     |                              |
     | WebSocket: task_created      |
     |<-----------------------------|
     |                              |
     |                      ✓ Event displayed instantly
```

This enables building:
- Live task boards
- Real-time notifications  
- Activity feeds
- Collaborative editing
- Presence indicators ("Who's online")

---

## Direct Database Access

For advanced operations or debugging:

```powershell
# Interactive PostgreSQL shell
kubectl exec -it postgres-0 -n taskmanager -- psql -U taskapp -d taskdb
```

Once in the psql shell:
```sql
-- View all tables
\dt

-- View table structure
\d tasks

-- Query tasks
SELECT id, title, status, created_at FROM tasks;

-- Query with joins
SELECT 
  t.id, 
  t.title, 
  t.status, 
  u.name as created_by,
  p.name as project
FROM tasks t
JOIN users u ON t.created_by = u.id
JOIN projects p ON t.project_id = p.id;

-- Exit
\q
```

---

## Cleanup Demo Data

To reset and start over:

```powershell
# Delete all tasks
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "DELETE FROM tasks;"

# Delete all projects
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "DELETE FROM projects;"

# Delete all team memberships
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "DELETE FROM team_memberships;"

# Delete all teams
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "DELETE FROM teams;"

# Delete all users
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "DELETE FROM users;"
```

Then run the setup steps again to recreate demo data.

---

## Troubleshooting

### Can't connect to application

```powershell
# Check ingress status
kubectl get ingress -n taskmanager

# Check if API pods are running
kubectl get pods -n taskmanager

# View API logs
kubectl logs -f -l app=taskmanager-api -n taskmanager
```

### Database connection issues

```powershell
# Check database pod
kubectl get pods -n taskmanager -l app=postgres

# View database logs
kubectl logs postgres-0 -n taskmanager

# Test database connection
kubectl exec postgres-0 -n taskmanager -- psql -U taskapp -d taskdb -c "SELECT 1;"
```

### Users can't login

```powershell
# Check if users exist
kubectl exec postgres-0 -n taskmanager -- `
  psql -U taskapp -d taskdb `
  -c "SELECT * FROM users;"

# Check API logs for errors
kubectl logs -f -l app=taskmanager-api -n taskmanager
```

---

## Next Steps

- Explore the API endpoints (see main README.md)
- Build your own tasks and projects
- Test real-time updates with multiple browser windows
- Add more team members
- Integrate with a frontend framework

For more information, see:
- [KUBERNETES_DEPLOYMENT.md](./KUBERNETES_DEPLOYMENT.md) - Complete deployment guide
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Common kubectl commands
- [Main README.md](../../README.md) - Full project documentation

