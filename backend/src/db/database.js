const Database = require('better-sqlite3');
const path     = require('path');
const fs       = require('fs');

const dataDir = path.join(__dirname, '../../data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const DB_PATH = path.join(dataDir, 'navigation.db');
let db;

function initDB() {
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  // TABLE: rooms — every location in the building
  db.exec(`CREATE TABLE IF NOT EXISTS rooms (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    floor       INTEGER NOT NULL DEFAULT 1,
    type        TEXT NOT NULL,
    description TEXT,
    qr_code     TEXT UNIQUE NOT NULL,
    x_pos       REAL DEFAULT 0,
    y_pos       REAL DEFAULT 0
  )`);

  // TABLE: paths — directed walking connections between rooms
  db.exec(`CREATE TABLE IF NOT EXISTS paths (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    from_node TEXT NOT NULL REFERENCES rooms(id),
    to_node   TEXT NOT NULL REFERENCES rooms(id),
    distance  REAL NOT NULL CHECK(distance > 0),
    direction TEXT NOT NULL
  )`);

  // TABLE: pathway_images — photos shown during navigation
  db.exec(`CREATE TABLE IF NOT EXISTS pathway_images (
    node_id    TEXT PRIMARY KEY REFERENCES rooms(id),
    image_file TEXT NOT NULL,
    caption    TEXT
  )`);

  console.log('[DB] Ready. Use Admin Panel at /admin.html to add data.');
  return db;
}

function getDB() {
  if (!db) initDB();
  return db;
}

function generateQRCode(roomId) {
    if (!roomId) {
        throw new Error('Room ID is required');
    }

    return `QR_${roomId}`;
}

module.exports = {
    initDB,
    getDB,
    generateQRCode
};

