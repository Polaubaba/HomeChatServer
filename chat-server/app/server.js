const express = require("express");
const cors = require("cors");
const http = require("http");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const { Pool } = require("pg");
const { Server } = require("socket.io");

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret";
const CORS_ORIGIN = process.env.CORS_ORIGIN || "http://localhost:3000";
const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error("Missing DATABASE_URL");
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });

async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      username TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

// ---- Express API ----
const app = express();
app.use(express.static("public"));
app.use(express.json());
app.use(cors({ origin: CORS_ORIGIN }));

app.get("/health", (_, res) => res.json({ ok: true }));

function signToken(user) {
  return jwt.sign({ sub: user.id, username: user.username }, JWT_SECRET, {
    expiresIn: "7d",
  });
}

// OPTIONAL: Disable this endpoint in production if you want only pre-created users.
// app.post("/api/register", ... )  <-- you can comment it out later.
app.post("/api/register", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password || password.length < 8) {
    return res.status(400).json({ error: "username and strong password required (8+ chars)" });
  }

  const password_hash = await bcrypt.hash(password, 12);

  try {
    const result = await pool.query(
      "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id, username",
      [username, password_hash]
    );
    const user = result.rows[0];
    return res.json({ token: signToken(user), user });
  } catch (e) {
    if (String(e).includes("unique")) {
      return res.status(409).json({ error: "username already exists" });
    }
    console.error(e);
    return res.status(500).json({ error: "server error" });
  }
});

app.post("/api/login", async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: "missing credentials" });

  const result = await pool.query(
    "SELECT id, username, password_hash FROM users WHERE username=$1",
    [username]
  );
  const user = result.rows[0];
  if (!user) return res.status(401).json({ error: "invalid credentials" });

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return res.status(401).json({ error: "invalid credentials" });

  return res.json({ token: signToken(user), user: { id: user.id, username: user.username } });
});

app.get("/api/messages/recent", async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || "50", 10), 200);
  const result = await pool.query(
    "SELECT id, username, text, created_at FROM messages ORDER BY id DESC LIMIT $1",
    [limit]
  );
  res.json({ messages: result.rows.reverse() });
});

// ---- Socket.IO ----
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: CORS_ORIGIN },
});

// Socket auth middleware: require JWT token in handshake
io.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error("missing token"));
    const payload = jwt.verify(token, JWT_SECRET);
    socket.user = { id: payload.sub, username: payload.username };
    next();
  } catch {
    next(new Error("invalid token"));
  }
});

io.on("connection", (socket) => {
  const username = socket.user.username;
  console.log("connected:", username);

  socket.on("chat:send", async (text, ack) => {
    try {
      if (typeof text !== "string" || !text.trim() || text.length > 2000) {
        return ack?.({ ok: false, error: "invalid message" });
      }
      const clean = text.trim();

      const result = await pool.query(
        "INSERT INTO messages (user_id, username, text) VALUES ($1, $2, $3) RETURNING id, created_at",
        [socket.user.id, username, clean]
      );

      const msg = {
        id: result.rows[0].id,
        username,
        text: clean,
        created_at: result.rows[0].created_at,
      };

      io.emit("chat:new", msg);
      ack?.({ ok: true, msg });
    } catch (e) {
      console.error(e);
      ack?.({ ok: false, error: "server error" });
    }
  });

  socket.on("disconnect", () => console.log("disconnected:", username));
});

initDb()
  .then(() => server.listen(PORT, () => console.log(`Server listening on :${PORT}`)))
  .catch((e) => {
    console.error("DB init failed:", e);
    process.exit(1);
  });
