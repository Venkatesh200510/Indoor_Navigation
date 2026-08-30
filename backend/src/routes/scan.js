// Receives QR code text, returns the matching room from the database.
const express   = require('express');
const router    = express.Router();
const { getDB } = require('../db/database');

router.post('/scan-location', (req, res) => {
  const { qr_code } = req.body;
  if (!qr_code) return res.status(400).json({ success:false, message:'qr_code is required' });

  try {
    const room = getDB()
      .prepare('SELECT id, name, floor, type, description FROM rooms WHERE qr_code = ?')
      .get(qr_code.trim());
    if (!room) return res.status(404).json({ success:false, message:'Unknown QR: ' + qr_code });
    res.json({ success:true, room });
  } catch (err) {
    res.status(500).json({ success:false, message:err.message });
  }
});

module.exports = router;
