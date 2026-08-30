require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const path       = require('path');
const { initDB,getDB, generateQRCode } = require('./db/database');

const app  = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Serve the admin panel HTML page
app.use(express.static(path.join(__dirname, '../public')));

// Serve pathway images so phones can download them
// e.g. http://192.168.1.100:5000/pathway-images/lab01.jpg
app.use('/pathway-images', express.static(path.join(__dirname, '../pathway-images')));

// Health check — open this on the phone browser to test connectivity
app.get('/health', (req, res) => {
  res.json({ status: 'ok', server: 'Indoor Navigation API', time: new Date().toISOString() });
});

// All API routes
app.use('/api', require('./routes/scan'));
app.use('/api', require('./routes/route'));
app.use('/api', require('./routes/panorama'));
app.use('/admin', require('./routes/admin'));

// 404 handler
app.use((req, res) => res.status(404).json({ success:false, message:'Not found: ' + req.path }));

// Error handler
app.use((err, req, res, _next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ success:false, message:'Server error: ' + err.message });
});

initDB();
app.listen(PORT, '0.0.0.0', () => {
  console.log('[SERVER] Running on port ' + PORT);
  console.log('[SERVER] Admin panel: http://localhost:' + PORT + '/admin.html');
  console.log('[SERVER] Health check: http://localhost:' + PORT + '/health');
});

