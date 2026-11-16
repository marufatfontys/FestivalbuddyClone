const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Log incoming requests for debugging mobile/web sync
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Configure Multer with Memory Storage (works on Vercel Serverless & locally)
// Converts uploaded images to Base64 Data URLs stored directly in SQLite / Turso
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 } // 5 MB limit
});

// Serve legacy local uploads if running locally
const uploadsDir = path.join(__dirname, 'uploads');
if (!process.env.VERCEL && fs.existsSync(uploadsDir)) {
  app.use('/uploads', express.static(uploadsDir));
}

// ============================================================================
// UNIFIED SQLITE ADAPTER (Turso Cloud libSQL on Vercel OR Local SQLite3 on Mac)
// ============================================================================
let libsqlClient = null;
let localSqliteDb = null;
let dbInitialized = false;
let dbInitPromise = null;

function initDatabaseDriver() {
  if (process.env.TURSO_DATABASE_URL) {
    const { createClient } = require('@libsql/client');
    libsqlClient = createClient({
      url: process.env.TURSO_DATABASE_URL,
      authToken: process.env.TURSO_AUTH_TOKEN,
    });
    console.log('🌐 Connected to Turso Cloud SQLite:', process.env.TURSO_DATABASE_URL);
  } else {
    try {
      const { createClient } = require('@libsql/client');
      const dbPath = path.join(__dirname, 'festivalbuddy.db');
      libsqlClient = createClient({
        url: `file:${dbPath}`,
      });
      console.log('💾 Connected to Local SQLite via @libsql/client at', dbPath);
    } catch (_) {
      const sqlite3 = require('sqlite3').verbose();
      const dbPath = path.join(__dirname, 'festivalbuddy.db');
      localSqliteDb = new sqlite3.Database(dbPath);
      console.log('💾 Connected to Local SQLite via sqlite3 at', dbPath);
    }
  }
}

initDatabaseDriver();

// Unified async query helpers (work identically for Turso Cloud & Local SQLite)
async function dbAll(sql, args = []) {
  if (libsqlClient) {
    const rs = await libsqlClient.execute({ sql, args });
    return rs.rows;
  }
  return new Promise((resolve, reject) => {
    localSqliteDb.all(sql, args, (err, rows) => {
      if (err) reject(err);
      else resolve(rows || []);
    });
  });
}

async function dbGet(sql, args = []) {
  const rows = await dbAll(sql, args);
  return rows[0] || null;
}

async function dbRun(sql, args = []) {
  if (libsqlClient) {
    const rs = await libsqlClient.execute({ sql, args });
    return { changes: rs.rowsAffected || 0 };
  }
  return new Promise((resolve, reject) => {
    localSqliteDb.run(sql, args, function (err) {
      if (err) reject(err);
      else resolve({ changes: this.changes || 0 });
    });
  });
}

// ============================================================================
// AUTOMATIC SCHEMA CREATION & INITIAL SEEDING
// ============================================================================
async function ensureDbInitialized() {
  if (dbInitialized) return;
  if (dbInitPromise) return dbInitPromise;

  dbInitPromise = (async () => {
    try {
      // 1. Festivals Table
      await dbRun(`
        CREATE TABLE IF NOT EXISTS festivals (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          tagline TEXT,
          categoryLabel TEXT,
          dates TEXT,
          city TEXT,
          venueAddress TEXT,
          distanceKm INTEGER,
          priceEur REAL,
          ticketsSoldInApp INTEGER,
          capacity INTEGER,
          genres TEXT,
          howToGetThere TEXT,
          publicTransportInfo TEXT,
          festivalTransportOffer TEXT,
          organizerName TEXT,
          ecoCommitments TEXT,
          primaryColor INTEGER,
          secondaryColor INTEGER,
          isApprovedByAdmin INTEGER,
          latitude REAL,
          longitude REAL,
          coverImageLabel TEXT,
          bannerImagePath TEXT,
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 2. Users / Organizers Table
      await dbRun(`
        CREATE TABLE IF NOT EXISTS users (
          email TEXT PRIMARY KEY,
          name TEXT,
          role TEXT,
          profilePhotoUrl TEXT,
          isApproved INTEGER DEFAULT 0,
          kvkNumber TEXT,
          companyName TEXT,
          phone TEXT,
          businessAddress TEXT,
          govIdType TEXT,
          govIdNumber TEXT,
          status TEXT DEFAULT 'Pending Review',
          registeredAt DATETIME DEFAULT CURRENT_TIMESTAMP,
          updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 3. Announcements Table
      await dbRun(`
        CREATE TABLE IF NOT EXISTS announcements (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          category TEXT DEFAULT 'Important Notice',
          isActive INTEGER DEFAULT 1,
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Seed default announcement if empty
      const annCount = await dbGet('SELECT COUNT(*) AS count FROM announcements');
      if (!annCount || Number(annCount.count) === 0) {
        await dbRun(
          `INSERT INTO announcements (id, title, message, category, isActive)
           VALUES (?, ?, ?, ?, ?)`,
          [
            'ann_welcome_2027',
            '🚀 Welcome to Festival Buddy!',
            'New SDG Water refill stations and zero-emission transit shuttles are now live across all 2027 Netherlands events.',
            'Update',
            1
          ]
        );
      }

      // Seed default organizers if empty
      const orgCount = await dbGet("SELECT COUNT(*) AS count FROM users WHERE role = 'organizer'");
      if (!orgCount || Number(orgCount.count) === 0) {
        const defaultOrganizers = [
          ['organizer@greenpulse.nl', 'Brabant Sustainable Events', 'organizer', 1, '17283940', 'GreenPulse Events B.V.', '+31 40 123 4567', 'Torenallee 20, 5617 BC Eindhoven', 'Dutch Passport', 'NT1928374', 'Approved'],
          ['pending.organizer@festivals.nl', 'Daan van Dijk', 'organizer', 0, '84920194', 'Solar Vibe Productions B.V.', '+31 20 892 1100', 'Keizersgracht 421, Amsterdam', 'EU National ID Card', 'NL99283411', 'Pending Review'],
          ['rave.holland@events.nl', 'Sophie Meijer', 'organizer', 0, '99102834', 'Neon Nights NL', '+31 10 334 9921', 'Coolsingel 104, Rotterdam', 'Driver License', 'DR-8812903', 'Pending Review']
        ];
        for (const org of defaultOrganizers) {
          await dbRun(
            `INSERT OR REPLACE INTO users (email, name, role, isApproved, kvkNumber, companyName, phone, businessAddress, govIdType, govIdNumber, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            org
          );
        }
      }

      // Seed initial festivals if empty
      const festCount = await dbGet('SELECT COUNT(*) AS count FROM festivals');
      if (!festCount || Number(festCount.count) === 0) {
        const defaultEco = JSON.stringify({
          freeDrinkingWater: true,
          firstAidAndQuietZone: true,
          publicTransportIncluded: true,
          bicycleParking: true,
          reusableCupsOnly: true,
          recyclingStations: true,
          renewableEnergy: true,
          safeSpaceStewards: true,
          localEcoPartners: true
        });
        const initialFestivals = [
          [
            'fest_greenpulse', 'GreenPulse Open Air', 'Solar-Powered Electronic & Indie Weekend',
            'Electronic • Indie', '18–20 Jul', 'Eindhoven', 'Strijp-S & Karpendonkse Plas, Eindhoven',
            4, 79.0, 3420, 4000, JSON.stringify(['Electronic & Techno', 'Indie & Alternative', 'Pop & Dance']),
            '12-min walk or 4-min bike ride from Eindhoven Centraal.',
            'NS Trains every 10 mins to Eindhoven Centraal.',
            'Free electric shuttle bus included with ticket.',
            'Pulse Live Events', defaultEco, 0xFF7C3AED, 0xFFFF2E93, 1, 51.4508, 5.4560, 'Neon Laser Mainstage Cover', null
          ],
          [
            'fest_neon_horizon', 'Horizon Beats Festival', 'Zero-Waste Waterfront Bass & Hip-Hop',
            'Hip-Hop • Dance', '02–03 Aug', 'Rotterdam', 'Zuiderpark Festival Grounds, Rotterdam',
            58, 69.0, 4150, 5000, JSON.stringify(['Hip-Hop & R&B', 'Pop & Dance', 'Electronic & Techno']),
            'Take Metro Line D or E from Rotterdam Centraal to Zuidplein.',
            'RET Metro & Night Buses run until 02:30.',
            '20% NS Group Ticket discount code + Free OV-fiets bike lockup.',
            'MaasLive Entertainment', defaultEco, 0xFFFF512F, 0xFFDD2476, 1, 51.8860, 4.4886, 'Sunset Harbor Stage Cover', null
          ],
          [
            'fest_canal_roots', 'Dommel Sunset Sessions', 'Acoustic, Folk & World Music by the River',
            'Acoustic • World', '15–16 Aug', 'Tilburg', 'Spoorpark Amphitheatre, Tilburg',
            22, 48.0, 1890, 2500, JSON.stringify(['Acoustic & Folk', 'World & Jazz', 'Indie & Alternative']),
            '8-minute walk from Tilburg Centraal Station via Westpoint exit.',
            'NS Sprinters & Intercities every 15 mins toward Eindhoven, Breda & Den Bosch.',
            'Free guarded bicycle garage & organic welcome drink for cyclists.',
            'Brabant Cultural Collective', defaultEco, 0xFF10B981, 0xFF059669, 1, 51.5606, 5.0761, 'Botanical Park Stage Cover', null
          ],
          [
            'fest_veluwe_bloom', 'Veluwe Night Bloom', 'Immersive Forest Art, Jazz & Ambient Electronic',
            'Jazz • Electronic', '29–31 Aug', 'Arnhem', 'Park Sonsbeek Amphitheatre, Arnhem',
            68, 84.0, 2100, 3000, JSON.stringify(['World & Jazz', 'Electronic & Techno', 'Acoustic & Folk']),
            '10-minute scenic walk from Arnhem Centraal.',
            'Direct Intercity trains from Utrecht, Nijmegen & Zutphen.',
            'Zero-emission trolleybus pass included in festival wristband.',
            'Sonsbeek Eco Arts', defaultEco, 0xFF00E5FF, 0xFF7C3AED, 1, 51.9922, 5.9038, 'Bioluminescent Forest Cover', null
          ]
        ];

        for (const f of initialFestivals) {
          await dbRun(
            `INSERT OR REPLACE INTO festivals (
              id, name, tagline, categoryLabel, dates, city, venueAddress,
              distanceKm, priceEur, ticketsSoldInApp, capacity, genres,
              howToGetThere, publicTransportInfo, festivalTransportOffer,
              organizerName, ecoCommitments, primaryColor, secondaryColor,
              isApprovedByAdmin, latitude, longitude, coverImageLabel, bannerImagePath
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            f
          );
        }
      }

      dbInitialized = true;
    } catch (err) {
      console.error('Database initialization error:', err);
    }
  })();

  return dbInitPromise;
}

// Middleware to ensure DB tables exist before handling any API request
app.use(async (req, res, next) => {
  await ensureDbInitialized();
  next();
});

// ---------------------- API ROUTES ----------------------

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    mode: process.env.TURSO_DATABASE_URL ? 'turso-cloud-sqlite' : 'local-sqlite',
    time: new Date().toISOString()
  });
});

// Image Upload Endpoint (Converts to Base64 Data URL for serverless & SQLite persistence)
app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const mimeType = req.file.mimetype || 'image/jpeg';
  const base64Data = req.file.buffer.toString('base64');
  const dataUrl = `data:${mimeType};base64,${base64Data}`;

  res.json({
    message: 'File encoded and ready for SQLite storage',
    filename: req.file.originalname,
    url: dataUrl
  });
});

// GET all festivals
app.get('/api/festivals', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM festivals ORDER BY createdAt DESC');
    const festivals = rows.map(row => ({
      ...row,
      genres: row.genres ? JSON.parse(row.genres) : [],
      ecoCommitments: row.ecoCommitments ? JSON.parse(row.ecoCommitments) : null,
      isApprovedByAdmin: Boolean(row.isApprovedByAdmin)
    }));
    res.json(festivals);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST / publish festival
app.post('/api/festivals', async (req, res) => {
  try {
    const f = req.body;
    const query = `
      INSERT OR REPLACE INTO festivals (
        id, name, tagline, categoryLabel, dates, city, venueAddress,
        distanceKm, priceEur, ticketsSoldInApp, capacity, genres,
        howToGetThere, publicTransportInfo, festivalTransportOffer,
        organizerName, ecoCommitments, primaryColor, secondaryColor,
        isApprovedByAdmin, latitude, longitude, coverImageLabel, bannerImagePath
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      f.id,
      f.name,
      f.tagline || '',
      f.categoryLabel || 'Live Festival',
      f.dates || 'Summer 2027',
      f.city || 'Netherlands',
      f.venueAddress || '',
      f.distanceKm ?? 25,
      f.priceEur ?? 65.0,
      f.ticketsSoldInApp ?? 1,
      f.capacity ?? 5000,
      JSON.stringify(f.genres || []),
      f.howToGetThere || '',
      f.publicTransportInfo || '',
      f.festivalTransportOffer || '',
      f.organizerName || 'Organizer',
      JSON.stringify(f.ecoCommitments || {}),
      f.primaryColor || 0xFF7C3AED,
      f.secondaryColor || 0xFFFF2E93,
      f.isApprovedByAdmin ? 1 : 0,
      f.latitude || 51.4416,
      f.longitude || 5.4697,
      f.coverImageLabel || 'Custom Cover',
      f.bannerImagePath || null
    ];

    await dbRun(query, values);
    res.status(201).json({ message: 'Festival created/updated', id: f.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT / update festival
app.put('/api/festivals/:id', async (req, res) => {
  try {
    const festivalId = req.params.id;
    const f = req.body;
    const query = `
      UPDATE festivals SET
        name = COALESCE(?, name),
        tagline = COALESCE(?, tagline),
        categoryLabel = COALESCE(?, categoryLabel),
        dates = COALESCE(?, dates),
        city = COALESCE(?, city),
        venueAddress = COALESCE(?, venueAddress),
        distanceKm = COALESCE(?, distanceKm),
        priceEur = COALESCE(?, priceEur),
        capacity = COALESCE(?, capacity),
        genres = COALESCE(?, genres),
        howToGetThere = COALESCE(?, howToGetThere),
        publicTransportInfo = COALESCE(?, publicTransportInfo),
        festivalTransportOffer = COALESCE(?, festivalTransportOffer),
        organizerName = COALESCE(?, organizerName),
        ecoCommitments = COALESCE(?, ecoCommitments),
        isApprovedByAdmin = COALESCE(?, isApprovedByAdmin),
        latitude = COALESCE(?, latitude),
        longitude = COALESCE(?, longitude),
        bannerImagePath = COALESCE(?, bannerImagePath)
      WHERE id = ?
    `;

    const values = [
      f.name ?? null,
      f.tagline ?? null,
      f.categoryLabel ?? null,
      f.dates ?? null,
      f.city ?? null,
      f.venueAddress ?? null,
      f.distanceKm ?? null,
      f.priceEur ?? null,
      f.capacity ?? null,
      f.genres ? JSON.stringify(f.genres) : null,
      f.howToGetThere ?? null,
      f.publicTransportInfo ?? null,
      f.festivalTransportOffer ?? null,
      f.organizerName ?? null,
      f.ecoCommitments ? JSON.stringify(f.ecoCommitments) : null,
      f.isApprovedByAdmin !== undefined ? (f.isApprovedByAdmin ? 1 : 0) : null,
      f.latitude ?? null,
      f.longitude ?? null,
      f.bannerImagePath ?? null,
      festivalId
    ];

    const result = await dbRun(query, values);
    res.json({ message: 'Festival updated successfully', id: festivalId, changes: result.changes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE festival
app.delete('/api/festivals/:id', async (req, res) => {
  try {
    const festivalId = req.params.id;
    const result = await dbRun('DELETE FROM festivals WHERE id = ?', [festivalId]);
    res.json({ message: 'Festival deleted successfully', id: festivalId, changes: result.changes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET all organizers (for Admin Web Dashboard approval queue)
app.get('/api/organizers', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM users WHERE role = ? ORDER BY registeredAt DESC', ['organizer']);
    const organizers = rows.map(r => ({
      ...r,
      isApproved: Boolean(r.isApproved)
    }));
    res.json(organizers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/organizers/:email/approve
app.post('/api/organizers/:email/approve', async (req, res) => {
  try {
    const email = req.params.email;
    const { approved, statusNote } = req.body;
    const isApprovedInt = approved ? 1 : 0;
    const statusStr = approved ? 'Approved' : (statusNote || 'Rejected');

    await dbRun(
      'UPDATE users SET isApproved = ?, status = ?, updatedAt = CURRENT_TIMESTAMP WHERE email = ?',
      [isApprovedInt, statusStr, email]
    );
    res.json({ message: `Organizer ${email} updated`, approved: Boolean(isApprovedInt), status: statusStr });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST / register or update user/organizer
app.post('/api/organizers/register', async (req, res) => {
  try {
    const o = req.body;
    const query = `
      INSERT OR REPLACE INTO users (
        email, name, role, isApproved, kvkNumber, companyName, phone,
        businessAddress, govIdType, govIdNumber, status
      ) VALUES (?, ?, 'organizer', ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    const values = [
      o.email,
      o.name,
      o.isApproved ? 1 : 0,
      o.kvkNumber || '',
      o.companyName || o.name,
      o.phone || '',
      o.businessAddress || '',
      o.govIdType || 'Dutch Passport',
      o.govIdNumber || '',
      o.status || 'Pending Review'
    ];

    await dbRun(query, values);
    res.json({ message: 'Organizer registered', email: o.email });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---------------------- ANNOUNCEMENT ROUTES ----------------------

// GET active announcements
app.get('/api/announcements', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM announcements WHERE isActive = 1 ORDER BY createdAt DESC');
    const announcements = rows.map(r => ({
      ...r,
      isActive: Boolean(r.isActive)
    }));
    res.json(announcements);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST create/update announcement
app.post('/api/announcements', async (req, res) => {
  try {
    const a = req.body;
    const id = a.id || `ann_${Date.now()}`;
    const query = `
      INSERT OR REPLACE INTO announcements (id, title, message, category, isActive)
      VALUES (?, ?, ?, ?, ?)
    `;
    const values = [
      id,
      a.title || 'Important Notice',
      a.message || '',
      a.category || 'Update',
      a.isActive !== undefined ? (a.isActive ? 1 : 0) : 1
    ];

    await dbRun(query, values);
    res.status(201).json({ message: 'Announcement published', id: id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE announcement
app.delete('/api/announcements/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const result = await dbRun('DELETE FROM announcements WHERE id = ?', [id]);
    res.json({ message: 'Announcement deleted', id: id, changes: result.changes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Export the Express app for Vercel Serverless Functions (api/index.js)
module.exports = app;

// Only call app.listen when running directly on Mac / local server (not inside Vercel Serverless)
if (require.main === module && !process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(`🚀 Festival Buddy SQLite API server running!`);
    console.log(`Local Access:   http://localhost:${PORT}`);
    console.log(`Mode:           ${process.env.TURSO_DATABASE_URL ? 'Turso Cloud SQLite' : 'Local SQLite File'}`);
    console.log(`====================================================`);
  });
}
