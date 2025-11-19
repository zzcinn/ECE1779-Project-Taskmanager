\## Quick Start (Windows + PowerShell)



From the project root:



```powershell

cd .\\infra



\# 1) Start containers

docker compose up -d



\# 2) Register demo users (Zicong and Alex)

Invoke-RestMethod -Uri http://localhost:3000/auth/register -Method Post `

&nbsp; -ContentType 'application/json' `

&nbsp; -Body '{"email":"zicong.shao@mail.utoronto.ca","password":"12345","name":"Zicong"}' | Out-Null



Invoke-RestMethod -Uri http://localhost:3000/auth/register -Method Post `

&nbsp; -ContentType 'application/json' `

&nbsp; -Body '{"email":"a.chia@mail.utoronto.ca","password":"12345","name":"Alex"}' | Out-Null



\# 3) Check user IDs

docker compose exec -T db `

&nbsp; psql -U taskapp -d taskdb `

&nbsp; -c "SELECT id, email, name FROM users ORDER BY id;"



\# 4) Create Team 14

docker compose exec -T db `

&nbsp; psql -U taskapp -d taskdb `

&nbsp; -c "INSERT INTO teams(name) VALUES('Team 14') RETURNING id, name;"



\# 5) Make Zicong the Admin of Team 14 (assumes Zicong has user\_id = 1 and team\_id = 1)

docker compose exec -T db `

&nbsp; psql -U taskapp -d taskdb `

&nbsp; -c "INSERT INTO team\_memberships(user\_id, team\_id, role) VALUES(1, 1, 'Admin');"



\# 6) Create the ECE1779 project under Team 14

docker compose exec -T db `

&nbsp; psql -U taskapp -d taskdb `

&nbsp; -c "INSERT INTO projects(team\_id, name) VALUES(1, 'ECE1779 Task Board') RETURNING id, team\_id, name;"



\# Web UI:

\#   http://localhost:3000/

\# Real-time updates:

\#   http://localhost:3000/realtime.html



