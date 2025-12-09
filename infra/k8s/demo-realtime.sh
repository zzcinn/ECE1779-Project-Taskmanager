#!/bin/bash

# Demo script to showcase real-time Socket.IO events
# This script demonstrates task creation, assignment, and status updates
# Watch http://152.42.145.25/realtime.html to see events appear in real-time!

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
echo ""

# Cleanup
rm -f cookies.txt

