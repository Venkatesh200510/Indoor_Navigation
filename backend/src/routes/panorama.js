// Returns image URLs for all rooms on a route.
// Flutter calls this after getting the route to show photos.
const express   = require('express');
const router    = express.Router();
const { getDB } = require('../db/database');

router.get('/get-pathway-images', (req, res) => {
  const { nodes } = req.query;
  if (!nodes) return res.status(400).json({ success:false, message:'nodes param required' });

  try {
    const db   = getDB();
    const BASE = process.env.BASE_URL || 'http://localhost:5000';

    const images = nodes.split(',').map(rawId => {
      const id   = rawId.trim();
      const room = db.prepare('SELECT name FROM rooms WHERE id = ?').get(id);
      const img  = db.prepare('SELECT image_file, caption FROM pathway_images WHERE node_id = ?').get(id);
      return {
        nodeId:   id,
        name:     room ? room.name : id,
        imageUrl: img
          ? BASE + '/pathway-images/' + img.image_file
          : BASE + '/pathway-images/placeholder.jpg',
        caption:  img ? img.caption : id,
      };
    });

    res.json({ success:true, images });
  } catch (err) { res.status(500).json({ success:false, message:err.message }); }
});

module.exports = router;

