# Demo script to showcase real-time Socket.IO events
# This script demonstrates task creation, assignment, and status updates
# Watch http://209.38.0.81/realtime.html to see events appear in real-time!

# Open the realtime page in a browser
Start-Process "http://209.38.0.81/realtime.html"
Write-Host "`nWatch the browser for real-time updates...`n" -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Login as Zicong
Write-Host "1. Logging in as Zicong..." -ForegroundColor Yellow
$loginResponse = Invoke-WebRequest -Uri http://209.38.0.81/auth/login -Method Post `
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

$task = Invoke-RestMethod -Uri http://209.38.0.81/tasks -Method Post `
  -ContentType 'application/json' -Body $taskData -WebSession $session
$taskId = $task.id
Write-Host "   ✓ Created task #$taskId" -ForegroundColor Green
Start-Sleep -Seconds 2

# Assign another user (triggers 'assigned' event)
Write-Host "3. Assigning task to Alex (watch for 'assigned' event)..." -ForegroundColor Yellow
$assignData = @{ user_ids = @(2) } | ConvertTo-Json
Invoke-RestMethod -Uri "http://209.38.0.81/tasks/$taskId/assignees" -Method Post `
  -ContentType 'application/json' -Body $assignData -WebSession $session
Write-Host "   ✓ Assigned task #$taskId to Alex (user 2)" -ForegroundColor Green
Start-Sleep -Seconds 2

# Update status to In Progress (triggers 'status_changed' event)
Write-Host "4. Changing status to 'In Progress' (watch for 'status' event)..." -ForegroundColor Yellow
$statusData = @{ status = "In Progress" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://209.38.0.81/tasks/$taskId/status" -Method Patch `
  -ContentType 'application/json' -Body $statusData -WebSession $session
Write-Host "   ✓ Status changed to 'In Progress'" -ForegroundColor Green
Start-Sleep -Seconds 2

# Update status to Done (triggers another 'status_changed' event)
Write-Host "5. Completing task (watch for 'status' event)..." -ForegroundColor Yellow
$statusData = @{ status = "Done" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://209.38.0.81/tasks/$taskId/status" -Method Patch `
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
Write-Host ""

