const express             = require('express');
const router              = express.Router();
const { getDB }           = require('../db/database');
const { aStar, buildGraph } = require('../algorithms/astar');

// GET /api/rooms — returns all rooms for destination dropdown
router.get('/rooms', (req, res) => {
  try {
    const rooms = getDB().prepare('SELECT id, name, floor, type FROM rooms ORDER BY floor, name').all();
    res.json({ success:true, rooms });
  } catch (err) { res.status(500).json({ success:false, message:err.message }); }
});

// POST /api/rooms — add a new room and automatically generate QR code
router.post('/rooms', (req, res) => {
  try {
    const {
      id,
      name,
      floor,
      type,
      description,
      x_pos,
      y_pos
    } = req.body;

    // Validate required fields
    if (!id || !name || !type) {
      return res.status(400).json({
        success: false,
        message: 'Room ID, name and type are required'
      });
    }

    const db = getDB();

    // Automatically generate QR code
    // Example: LH109 -> QR_LH109
    const qr_code = generateQRCode(id);

    // Insert room
    const stmt = db.prepare(`
      INSERT INTO rooms (
        id,
        name,
        floor,
        type,
        description,
        qr_code,
        x_pos,
        y_pos
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      id,
      name,
      floor || 1,
      type,
      description || '',
      qr_code,
      x_pos || 0,
      y_pos || 0
    );

    // Return newly created room
    res.status(201).json({
      success: true,
      message: 'Room added successfully',
      room: {
        id,
        name,
        floor: floor || 1,
        type,
        description: description || '',
        qr_code,
        x_pos: x_pos || 0,
        y_pos: y_pos || 0
      }
    });

  } catch (err) {
    console.error('[ROOM ADD]', err);

    // Duplicate room ID / QR code
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(409).json({
        success: false,
        message: 'Room ID already exists'
      });
    }

    res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// GET /api/find-route?from=Lab01&to=Class101
router.get('/find-route', (req, res) => {
  const { from, to } = req.query;
  if (!from || !to) return res.status(400).json({ success:false, message:'from and to are required' });
  if (from === to) return res.json({
    success:true, path:[], nodeIds:[], directions:['You are already here.'],
    voiceScript:['You are already at your destination.'], totalDistance:0
  });

  try {
    const db       = getDB();
    const fromRoom = db.prepare('SELECT * FROM rooms WHERE id = ?').get(from);
    const toRoom   = db.prepare('SELECT * FROM rooms WHERE id = ?').get(to);
    if (!fromRoom) return res.status(404).json({ success:false, message:'Room not found: '+from });
    if (!toRoom)   return res.status(404).json({ success:false, message:'Room not found: '+to   });

    const edges  = db.prepare('SELECT * FROM paths').all();
    const allRms = db.prepare('SELECT id, x_pos, y_pos FROM rooms').all();
    const graph  = buildGraph(edges);
    const coords = {};
    for (const r of allRms) coords[r.id] = { x:r.x_pos, y:r.y_pos };

    const result = aStar(graph, from, to, coords);
    if (!result.found) return res.status(404).json({ success:false, message:'No route found from '+from+' to '+to });

    const path = result.path.map(id =>
      db.prepare('SELECT id, name, floor, type FROM rooms WHERE id = ?').get(id)
      || { id, name:id, floor:1, type:'unknown' }
    );

    const voiceScript = buildVoice(fromRoom, toRoom, path, result.directions);

    res.json({
      success:true, from:fromRoom, to:toRoom,
      path, nodeIds:result.path,
      directions:result.directions,
      totalDistance:result.totalCost,
      voiceScript,
    });
  } catch (err) { res.status(500).json({ success:false, message:err.message }); }
});

function buildVoice(from, to, path, dirs) {
  const s = [];
  s.push('You are in ' + from.name + ' on floor ' + from.floor + '.');
  s.push('Your destination is ' + to.name + ' on floor ' + to.floor + '.');
  dirs.forEach((d, i) => {
    s.push(path[i+1] && path[i+1].type === 'stairs' ? 'Proceed to the staircase. ' + d : d);
  });
  return s;
}

module.exports = router;
