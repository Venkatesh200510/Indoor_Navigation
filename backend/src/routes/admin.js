
// Admin routes — add rooms, paths, and images without editing code.

const express = require('express');

const router = express.Router();

const {
  getDB,
  generateQRCode
} = require('../db/database');


// ================================================================
// POST /admin/add-room
// ================================================================
//
// Adds a new room.
//
// QR CODE IS GENERATED AUTOMATICALLY.
//
// Example:
//
// Room ID:
//     LH109
//
// Automatically generated QR value:
//     QR_LH109
//
// The admin does NOT need to enter a QR code.
// ================================================================

router.post('/add-room', (req, res) => {

  const {
    id,
    name,
    floor,
    type,
    description,
    x_pos,
    y_pos
  } = req.body;


  // --------------------------------------------------------------
  // Validate required fields
  // --------------------------------------------------------------

  if (!id || !name || !floor || !type) {

    return res.status(400).json({
      success: false,
      message: 'id, name, floor and type are required.'
    });

  }


  // --------------------------------------------------------------
  // Clean Room ID
  // --------------------------------------------------------------

  const roomId = id.trim();


  // Room ID cannot contain spaces

  if (roomId.includes(' ')) {

    return res.status(400).json({
      success: false,
      message: 'Room ID cannot contain spaces.'
    });

  }


  try {

    const db = getDB();


    // ------------------------------------------------------------
    // Check duplicate room ID
    // ------------------------------------------------------------

    if (
      db
        .prepare('SELECT id FROM rooms WHERE id = ?')
        .get(roomId)
    ) {

      return res.status(409).json({
        success: false,
        message:
          'Room ID already exists: ' +
          roomId
      });

    }


    // ------------------------------------------------------------
    // AUTOMATIC QR CODE GENERATION
    // ------------------------------------------------------------

    const qr_code =
      generateQRCode(roomId);


    console.log(
      `[QR] Generated ${qr_code} for ${roomId}`
    );


    // ------------------------------------------------------------
    // Insert room
    // ------------------------------------------------------------

    db.prepare(`
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
    `)
    .run(

      roomId,

      name.trim(),

      parseInt(floor),

      type.trim(),

      (description || '').trim(),

      qr_code,

      parseFloat(x_pos) || 0,

      parseFloat(y_pos) || 0

    );


    // ------------------------------------------------------------
    // Return newly created room
    // ------------------------------------------------------------

    res.json({

      success: true,

      message:
        'Room added: ' +
        name,

      room: {

        id: roomId,

        name: name.trim(),

        floor: parseInt(floor),

        type: type.trim(),

        description:
          (description || '').trim(),

        qr_code,

        x_pos:
          parseFloat(x_pos) || 0,

        y_pos:
          parseFloat(y_pos) || 0

      }

    });


  } catch (err) {

    console.error(
      '[ADD ROOM ERROR]',
      err
    );


    if (
      err.message &&
      err.message.includes('UNIQUE')
    ) {

      return res.status(409).json({

        success: false,

        message:
          'QR code already exists: ' +
          roomId

      });

    }


    res.status(500).json({

      success: false,

      message: err.message

    });

  }

});


// ================================================================
// POST /admin/add-path
// ================================================================

// ================================================================
// POST /admin/add-path
//
// Adds a path in BOTH directions automatically.
//
// Example:
//
// LH108 -> LH107
//
// automatically creates:
//
// LH108 -> LH107
// LH107 -> LH108
//
// So the admin only needs to enter the connection once.
// ================================================================

router.post('/add-path', (req, res) => {

  const {
    from_node,
    to_node,
    distance,
    direction
  } = req.body;


  // --------------------------------------------------------------
  // Validate required fields
  // --------------------------------------------------------------

  if (
    !from_node ||
    !to_node ||
    !distance ||
    !direction
  ) {
    return res.status(400).json({
      success: false,
      message: 'All fields required.'
    });
  }


  // --------------------------------------------------------------
  // Cannot connect room to itself
  // --------------------------------------------------------------

  if (from_node === to_node) {
    return res.status(400).json({
      success: false,
      message:
        'From and To cannot be the same room.'
    });
  }


  // --------------------------------------------------------------
  // Validate distance
  // --------------------------------------------------------------

  const dist = parseFloat(distance);

  if (isNaN(dist) || dist <= 0) {
    return res.status(400).json({
      success: false,
      message:
        'Distance must be a positive number.'
    });
  }


  try {

    const db = getDB();


    // ------------------------------------------------------------
    // Check FROM room
    // ------------------------------------------------------------

    if (
      !db
        .prepare(
          'SELECT id FROM rooms WHERE id = ?'
        )
        .get(from_node)
    ) {

      return res.status(404).json({
        success: false,
        message:
          'From room not found: ' +
          from_node
      });

    }


    // ------------------------------------------------------------
    // Check TO room
    // ------------------------------------------------------------

    if (
      !db
        .prepare(
          'SELECT id FROM rooms WHERE id = ?'
        )
        .get(to_node)
    ) {

      return res.status(404).json({
        success: false,
        message:
          'To room not found: ' +
          to_node
      });

    }


    // ------------------------------------------------------------
    // Check whether either direction already exists
    // ------------------------------------------------------------

    const existingForward = db
      .prepare(`
        SELECT id
        FROM paths
        WHERE from_node = ?
        AND to_node = ?
      `)
      .get(from_node, to_node);


    const existingReverse = db
      .prepare(`
        SELECT id
        FROM paths
        WHERE from_node = ?
        AND to_node = ?
      `)
      .get(to_node, from_node);


    if (existingForward || existingReverse) {

      return res.status(409).json({
        success: false,
        message:
          'A path already exists between ' +
          from_node +
          ' and ' +
          to_node
      });

    }


    // ------------------------------------------------------------
    // Insert BOTH directions in one transaction
    // ------------------------------------------------------------

    const insertPath = db.prepare(`
      INSERT INTO paths (
        from_node,
        to_node,
        distance,
        direction
      )
      VALUES (?, ?, ?, ?)
    `);


    const addBothDirections = db.transaction(() => {

      // Forward
      insertPath.run(
        from_node,
        to_node,
        dist,
        direction.trim()
      );


      // Reverse
      insertPath.run(
        to_node,
        from_node,
        dist,
        direction.trim()
      );

    });


    addBothDirections();


    // ------------------------------------------------------------
    // Success response
    // ------------------------------------------------------------

    res.json({

      success: true,

      message:
        'Path added in both directions: ' +
        from_node +
        ' ↔ ' +
        to_node,

      paths: [

        {
          from_node: from_node,
          to_node: to_node,
          distance: dist,
          direction: direction.trim()
        },

        {
          from_node: to_node,
          to_node: from_node,
          distance: dist,
          direction: direction.trim()
        }

      ]

    });


  } catch (err) {

    console.error(
      '[ADD PATH ERROR]',
      err
    );

    res.status(500).json({
      success: false,
      message: err.message
    });

  }

});


// ================================================================
// POST /admin/add-image
// ================================================================

router.post('/add-image', (req, res) => {

  const {
    node_id,
    image_file,
    caption
  } = req.body;


  if (
    !node_id ||
    !image_file
  ) {

    return res.status(400).json({

      success: false,

      message:
        'node_id and image_file required.'

    });

  }


  try {

    const db = getDB();


    // Check room

    if (
      !db
        .prepare(
          'SELECT id FROM rooms WHERE id = ?'
        )
        .get(node_id)
    ) {

      return res.status(404).json({

        success: false,

        message:
          'Room not found: ' +
          node_id

      });

    }


    // Insert / replace image

    db.prepare(`
      INSERT OR REPLACE INTO pathway_images (
        node_id,
        image_file,
        caption
      )
      VALUES (?, ?, ?)
    `)
    .run(

      node_id,

      image_file.trim(),

      (caption || node_id).trim()

    );


    res.json({

      success: true,

      message:
        'Image entry saved for: ' +
        node_id

    });


  } catch (err) {

    res.status(500).json({

      success: false,

      message: err.message

    });

  }

});


// ================================================================
// GET /admin/rooms
// Live table + dropdowns
// ================================================================

router.get('/rooms', (req, res) => {

  try {

    const rooms =
      getDB()
        .prepare(`
          SELECT *
          FROM rooms
          ORDER BY floor, name
        `)
        .all();


    res.json({

      success: true,

      rooms

    });


  } catch (err) {

    res.status(500).json({

      success: false,

      message: err.message

    });

  }

});


// ================================================================
// GET /admin/paths
// Live paths table
// ================================================================

router.get('/paths', (req, res) => {

  try {

    const paths =
      getDB()
        .prepare(`
          SELECT *
          FROM paths
          ORDER BY from_node
        `)
        .all();


    res.json({

      success: true,

      paths

    });


  } catch (err) {

    res.status(500).json({

      success: false,

      message: err.message

    });

  }

});


// ================================================================
// DELETE /admin/delete-room/:id
// ================================================================

router.delete(
  '/delete-room/:id',
  (req, res) => {

    const { id } =
      req.params;


    try {

      const db = getDB();


      // Delete paths

      db.prepare(`
        DELETE FROM paths
        WHERE from_node = ?
        OR to_node = ?
      `)
      .run(id, id);


      // Delete pathway images

      db.prepare(`
        DELETE FROM pathway_images
        WHERE node_id = ?
      `)
      .run(id);


      // Delete room

      const result =
        db.prepare(`
          DELETE FROM rooms
          WHERE id = ?
        `)
        .run(id);


      if (result.changes === 0) {

        return res.status(404).json({

          success: false,

          message:
            'Room not found: ' +
            id

        });

      }


      res.json({

        success: true,

        message:
          'Room deleted: ' +
          id

      });


    } catch (err) {

      res.status(500).json({

        success: false,

        message: err.message

      });

    }

  }
);


module.exports = router;