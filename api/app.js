import express from "express";
import dotenv from "dotenv";
import pg from "pg";
import session from "express-session";
import connectPg from "connect-pg-simple";
import bcrypt from "bcrypt";          
import http from "http";
import { Server as IOServer } from "socket.io";

dotenv.config();

const { Pool } = pg;
const pool = new Pool({
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || "taskapp",
  password: process.env.DB_PASSWORD || "taskpass",
  database: process.env.DB_NAME || "taskdb",
});

const app = express();
app.use(express.json());
app.use(express.static("public"));

const PgSession = connectPg(session);
const sessionMiddleware = session({
  store: new PgSession({
    pool,
    tableName: "session",
    createTableIfMissing: true,
  }),
  secret: process.env.SESSION_SECRET || "change_me_later",
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, sameSite: "lax", maxAge: 1000 * 60 * 60 * 12 },
});
if (process.env.NODE_ENV !== "test") {
  app.use(sessionMiddleware);
}
app.get("/health", (_req, res) => {
  res.status(200).send("OK");
});

const server = http.createServer(app);
const io = new IOServer(server, { cors: { origin: "*" } });
io.on("connection", (socket) => {
  console.log("socket connected:", socket.id);
});
function emitAll(event, payload) {
  io.emit(event, payload);
}

function requireAuth(req, res, next) {
  if (!req.session.user) return res.status(401).json({ error: "not_logged_in" });
  next();
}
async function userRoleInTeam(userId, teamId) {
  const r = await pool.query(
    "SELECT role FROM team_memberships WHERE user_id=$1 AND team_id=$2",
    [userId, teamId]
  );
  return r.rowCount ? r.rows[0].role : null;
}
async function ensureTaskVisibleToUser(taskId, userId) {
  const p = await pool.query(
    `SELECT p.team_id
       FROM tasks t JOIN projects p ON t.project_id=p.id
      WHERE t.id=$1`,
    [taskId]
  );
  if (p.rowCount === 0) return { ok: false, code: 404 };
  const role = await userRoleInTeam(userId, p.rows[0].team_id);
  if (!role) return { ok: false, code: 403 };
  return { ok: true, team_id: p.rows[0].team_id };
}

app.get("/check", async (_req, res) => {
  try {
    const r = await pool.query("SELECT 1 AS ok");
    res.json({ ok: true, service: "task-api", env: process.env.NODE_ENV || "unknown", db: r.rows[0].ok === 1 ? "up" : "unknown" });
  } catch {
    res.status(500).json({ ok: false, service: "task-api", db: "down" });
  }
});

app.post("/auth/register", async (req, res) => {
  const { email, password, name } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: "email_password_required" });
  const hash = await bcrypt.hash(password, 10);
  const r = await pool.query(
    "INSERT INTO users(email,password_hash,name) VALUES($1,$2,$3) ON CONFLICT(email) DO NOTHING RETURNING id,email",
    [email, hash, name || null]
  );
  if (r.rowCount === 0) return res.status(409).json({ error: "email_exists" });
  res.status(201).json({ ok: true });
});
app.post("/auth/login", async (req, res) => {
  const { email, password } = req.body || {};
  const u = await pool.query("SELECT id,email,password_hash FROM users WHERE email=$1", [email]);
  if (u.rowCount === 0) return res.status(401).json({ error: "bad_credentials" });
  const ok = await bcrypt.compare(password, u.rows[0].password_hash);
  if (!ok) return res.status(401).json({ error: "bad_credentials" });
  req.session.user = { id: u.rows[0].id, email: u.rows[0].email };
  res.json({ ok: true, id: u.rows[0].id, email: u.rows[0].email });
});
app.post("/auth/logout", requireAuth, (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

app.post("/teams", requireAuth, async (req, res) => {
  const { name } = req.body || {};
  if (!name) return res.status(400).json({ error: "name_required" });
  const t = await pool.query("INSERT INTO teams(name) VALUES($1) RETURNING id,name", [name]);
  await pool.query(
    "INSERT INTO team_memberships(user_id,team_id,role) VALUES($1,$2,'Admin') ON CONFLICT DO NOTHING",
    [req.session.user.id, t.rows[0].id]
  );
  res.status(201).json(t.rows[0]);
});
app.post("/teams/:id/members", requireAuth, async (req, res) => {
  const teamId = Number(req.params.id);
  const { user_id, role } = req.body || {};
  if (!teamId || !user_id || !["Admin", "Member"].includes(role)) {
    return res.status(400).json({ error: "bad_request" });
  }
  const myRole = await userRoleInTeam(req.session.user.id, teamId);
  if (myRole !== "Admin") return res.status(403).json({ error: "forbidden" });
  await pool.query(
    "INSERT INTO team_memberships(user_id,team_id,role) VALUES($1,$2,$3) ON CONFLICT DO NOTHING",
    [user_id, teamId, role]
  );
  res.json({ ok: true });
});
app.post("/projects", requireAuth, async (req, res) => {
  const { team_id, name } = req.body || {};
  if (!team_id || !name) return res.status(400).json({ error: "team_id_name_required" });
  const role = await userRoleInTeam(req.session.user.id, team_id);
  if (!role) return res.status(403).json({ error: "not_in_team" });
  const p = await pool.query("INSERT INTO projects(team_id,name) VALUES($1,$2) RETURNING id,team_id,name", [team_id, name]);
  res.status(201).json(p.rows[0]);
});

const ALLOWED = new Set(["To-Do", "In Progress", "Done"]);

app.post("/tasks", requireAuth, async (req, res) => {
  const { project_id, title, description = "", assignees = [] } = req.body || {};
  if (!project_id || !title) return res.status(400).json({ error: "project_id_title_required" });

  const p = await pool.query("SELECT team_id FROM projects WHERE id=$1", [project_id]);
  if (p.rowCount === 0) return res.status(404).json({ error: "project_not_found" });
  const role = await userRoleInTeam(req.session.user.id, p.rows[0].team_id);
  if (!role) return res.status(403).json({ error: "not_in_team" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const t = await client.query(
      "INSERT INTO tasks(project_id,title,description,created_by) VALUES($1,$2,$3,$4) RETURNING *",
      [project_id, title, description, req.session.user.id]
    );
    const task = t.rows[0];

    if (Array.isArray(assignees) && assignees.length > 0) {
      await client.query(
        "INSERT INTO task_assignees(task_id,user_id) SELECT $1, UNNEST($2::int[]) ON CONFLICT DO NOTHING",
        [task.id, assignees]
      );
      await client.query(
        "INSERT INTO task_activity_log(task_id,actor_id,type,details) VALUES($1,$2,'assigned',$3::jsonb)",
        [task.id, req.session.user.id, JSON.stringify({ user_ids: assignees })]
      );
    }
    await client.query(
      "INSERT INTO task_activity_log(task_id,actor_id,type) VALUES($1,$2,'created')",
      [task.id, req.session.user.id]
    );
    await client.query("COMMIT");

    // 实时：广播 task_created
    emitAll("task_created", { id: task.id, title: task.title, project_id, status: task.status });

    res.status(201).json(task);
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("create task error:", e.message);
    res.status(500).json({ error: "server_error" });
  } finally {
    client.release();
  }
});

app.post("/tasks/:id/assignees", requireAuth, async (req, res) => {
  const id = Number(req.params.id);
  const { user_ids = [] } = req.body || {};
  if (!id || !Array.isArray(user_ids)) return res.status(400).json({ error: "bad_request" });

  const vis = await ensureTaskVisibleToUser(id, req.session.user.id);
  if (!vis.ok) return res.status(vis.code).end();

  await pool.query(
    "INSERT INTO task_assignees(task_id,user_id) SELECT $1, UNNEST($2::int[]) ON CONFLICT DO NOTHING",
    [id, user_ids]
  );
  await pool.query(
    "INSERT INTO task_activity_log(task_id,actor_id,type,details) VALUES($1,$2,'assigned',$3::jsonb)",
    [id, req.session.user.id, JSON.stringify({ user_ids })]
  );

  emitAll("task_assigned", { id, user_ids });

  res.json({ ok: true, added: user_ids });
});

app.patch("/tasks/:id/status", requireAuth, async (req, res) => {
  const id = Number(req.params.id);
  const { status } = req.body || {};
  if (!id || !ALLOWED.has(status)) return res.status(400).json({ error: "bad_status" });

  const vis = await ensureTaskVisibleToUser(id, req.session.user.id);
  if (!vis.ok) return res.status(vis.code).end();

  const cur = await pool.query("SELECT status FROM tasks WHERE id=$1", [id]);
  if (cur.rowCount === 0) return res.status(404).end();

  const r = await pool.query(
    "UPDATE tasks SET status=$1, updated_at=now() WHERE id=$2 RETURNING *",
    [status, id]
  );
  await pool.query(
    "INSERT INTO task_activity_log(task_id,actor_id,type,details) VALUES($1,$2,'status_changed',$3::jsonb)",
    [id, req.session.user.id, JSON.stringify({ from: cur.rows[0].status, to: status })]
  );

  emitAll("task_status_changed", { id, status });

  res.json(r.rows[0]);
});

app.get("/tasks", requireAuth, async (req, res) => {
  try {
    const userId = req.session.user.id;
    const { query, assignee_id } = req.query;

    let sql = `
      SELECT DISTINCT t.*
      FROM tasks t
      JOIN projects p ON t.project_id = p.id
      JOIN team_memberships m ON m.team_id = p.team_id
      LEFT JOIN task_assignees ta ON ta.task_id = t.id
      WHERE m.user_id = $1
    `;
    const params = [userId];
    let idx = 2;

    if (query && query.trim() !== "") {
      sql += ` AND (t.title ILIKE $${idx} OR t.description ILIKE $${idx})`;
      params.push(`%${query.trim()}%`);
      idx++;
    }

    if (assignee_id) {
      sql += ` AND ta.user_id = $${idx}`;
      params.push(Number(assignee_id));
      idx++;
    }

    sql += " ORDER BY t.id DESC";

    const r = await pool.query(sql, params);
    res.json(r.rows);
  } catch (e) {
    console.error("GET /tasks error:", e.message);
    res.status(500).json({ error: "server_error" });
  }
});

app.get("/tasks/:id/activity", requireAuth, async (req, res) => {
  const vis = await ensureTaskVisibleToUser(Number(req.params.id), req.session.user.id);
  if (!vis.ok) return res.status(vis.code).end();
  const r = await pool.query(
    "SELECT type,details,at FROM task_activity_log WHERE task_id=$1 ORDER BY id",
    [req.params.id]
  );
  res.json(r.rows);
});

const port = Number(process.env.PORT || 3000);

if (process.env.NODE_ENV !== "test") {
  server.listen(port, () =>
    console.log(`[task-api] listening on http://localhost:${port}`)
  );
}

export { app, server };
export default app;

