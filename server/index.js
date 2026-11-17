const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Load .env file automatically if present locally
const envPaths = [path.join(__dirname, '..', '.env'), path.join(__dirname, '.env')];
for (const envPath of envPaths) {
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
        const idx = trimmed.indexOf('=');
        const key = trimmed.substring(0, idx).trim();
        const val = trimmed.substring(idx + 1).trim();
        if (!process.env[key]) {
          process.env[key] = val;
        }
      }
    }
  }
}

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Log incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Configure Multer with Memory Storage (works on Vercel Serverless & locally)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }
});

// Serve legacy local uploads if running locally
const uploadsDir = path.join(__dirname, 'uploads');
if (!process.env.VERCEL && fs.existsSync(uploadsDir)) {
  app.use('/uploads', express.static(uploadsDir));
}

// Serve the built Flutter Web Admin Panel static files from ../public
const publicWebDir = path.join(__dirname, '..', 'public');
if (fs.existsSync(publicWebDir)) {
  app.use(express.static(publicWebDir));
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
// 5 DEDICATED DATABASES / TABLES:
// 1. visitor_accounts           (Auto-approved visitor accounts)
// 2. organizer_accounts         (Approved organizer accounts)
// 3. pending_organizer_accounts (Pending organizer applications awaiting admin approval)
// 4. published_events           (Approved public festivals)
// 5. pending_event_approvals    (Pending organizer events awaiting admin approval)
// + announcements               (System-wide admin announcements)
// ============================================================================
async function ensureDbInitialized() {
  if (dbInitialized) return;
  if (dbInitPromise) return dbInitPromise;

  dbInitPromise = (async () => {
    try {
      // 1. Visitor Accounts Database
      await dbRun(`
        CREATE TABLE IF NOT EXISTS visitor_accounts (
          email TEXT PRIMARY KEY,
          name TEXT,
          username TEXT,
          authMethod TEXT,
          phone TEXT,
          address TEXT,
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 2. Approved Organizer Accounts Database
      await dbRun(`
        CREATE TABLE IF NOT EXISTS organizer_accounts (
          email TEXT PRIMARY KEY,
          name TEXT,
          companyName TEXT,
          kvkNumber TEXT,
          vatNumber TEXT,
          phone TEXT,
          businessAddress TEXT,
          govIdType TEXT,
          govIdNumber TEXT,
          status TEXT DEFAULT 'Approved',
          registeredAt DATETIME DEFAULT CURRENT_TIMESTAMP,
          approvedAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 3. Pending Organizer Account Approvals Database
      await dbRun(`
        CREATE TABLE IF NOT EXISTS pending_organizer_accounts (
          email TEXT PRIMARY KEY,
          name TEXT,
          companyName TEXT,
          kvkNumber TEXT,
          vatNumber TEXT,
          phone TEXT,
          businessAddress TEXT,
          govIdType TEXT,
          govIdNumber TEXT,
          status TEXT DEFAULT 'Pending Approval',
          registeredAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 4. Published Events Database (Approved Festivals)
      await dbRun(`
        CREATE TABLE IF NOT EXISTS published_events (
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
          isApprovedByAdmin INTEGER DEFAULT 1,
          latitude REAL,
          longitude REAL,
          coverImageLabel TEXT,
          bannerImagePath TEXT,
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // 5. Pending Event Approvals Database (Awaiting Admin Approval)
      await dbRun(`
        CREATE TABLE IF NOT EXISTS pending_event_approvals (
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
          isApprovedByAdmin INTEGER DEFAULT 0,
          latitude REAL,
          longitude REAL,
          coverImageLabel TEXT,
          bannerImagePath TEXT,
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Auto-repair any legacy octet-stream image data URLs to valid image/jpeg
      try {
        await dbRun(`
          UPDATE pending_event_approvals 
          SET bannerImagePath = REPLACE(bannerImagePath, 'data:application/octet-stream;', 'data:image/jpeg;')
          WHERE bannerImagePath LIKE 'data:application/octet-stream;%'
        `);
        await dbRun(`
          UPDATE published_events 
          SET bannerImagePath = REPLACE(bannerImagePath, 'data:application/octet-stream;', 'data:image/jpeg;')
          WHERE bannerImagePath LIKE 'data:application/octet-stream;%'
        `);
      } catch (_) {}

      // 6. Announcements Table
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

      // Seed default Approved Organizer if empty
      const approvedOrgCount = await dbGet('SELECT COUNT(*) AS count FROM organizer_accounts');
      if (!approvedOrgCount || Number(approvedOrgCount.count) === 0) {
        await dbRun(
          `INSERT OR REPLACE INTO organizer_accounts (email, name, companyName, kvkNumber, vatNumber, phone, businessAddress, govIdType, govIdNumber, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          ['organizer@greenpulse.nl', 'Brabant Sustainable Events', 'GreenPulse Events B.V.', '17283940', 'NL863421098B01', '+31 40 123 4567', 'Torenallee 20, 5617 BC Eindhoven', 'Dutch Passport', 'NT1928374', 'Approved']
        );
      }

      // Seed default Pending Organizers if both pending and approved only have the 1 default
      const pendingOrgCount = await dbGet('SELECT COUNT(*) AS count FROM pending_organizer_accounts');
      if ((!pendingOrgCount || Number(pendingOrgCount.count) === 0) && (!approvedOrgCount || Number(approvedOrgCount.count) === 0)) {
        const defaultPendingOrgs = [
          ['pending.organizer@festivals.nl', 'Daan van Dijk', 'Solar Vibe Productions B.V.', '84920194', 'NL81239012B01', '+31 20 892 1100', 'Keizersgracht 421, Amsterdam', 'EU National ID Card', 'NL99283411', 'Pending Approval'],
          ['rave.holland@events.nl', 'Sophie Meijer', 'Neon Nights NL', '99102834', 'NL89910283B01', '+31 10 334 9921', 'Coolsingel 104, Rotterdam', 'Driver License', 'DR-8812903', 'Pending Approval']
        ];
        for (const org of defaultPendingOrgs) {
          await dbRun(
            `INSERT OR REPLACE INTO pending_organizer_accounts (email, name, companyName, kvkNumber, vatNumber, phone, businessAddress, govIdType, govIdNumber, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            org
          );
        }
      }

      // Seed initial 4 approved festivals into published_events if empty
      const pubFestCount = await dbGet('SELECT COUNT(*) AS count FROM published_events');
      if (!pubFestCount || Number(pubFestCount.count) === 0) {
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
            `INSERT OR REPLACE INTO published_events (
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

app.use(async (req, res, next) => {
  await ensureDbInitialized();
  next();
});

function formatEventRow(row, isApproved) {
  return {
    ...row,
    genres: row.genres ? JSON.parse(row.genres) : [],
    ecoCommitments: row.ecoCommitments ? JSON.parse(row.ecoCommitments) : null,
    isApprovedByAdmin: isApproved
  };
}

// ---------------------- API ROUTES ----------------------

// Health check showing all 5 tables
app.get('/api/health', async (req, res) => {
  res.json({
    status: 'ok',
    mode: process.env.TURSO_DATABASE_URL ? 'turso-cloud-sqlite' : 'local-sqlite',
    databases: [
      'visitor_accounts',
      'organizer_accounts',
      'pending_organizer_accounts',
      'published_events',
      'pending_event_approvals'
    ],
    time: new Date().toISOString()
  });
});

// Image Upload Endpoint (Converts to Base64 Data URL for SQLite storage)
app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  let mimeType = req.file.mimetype || 'image/jpeg';
  if (mimeType === 'application/octet-stream' || !mimeType.startsWith('image/')) {
    mimeType = 'image/jpeg';
  }
  const base64Data = req.file.buffer.toString('base64');
  const dataUrl = `data:${mimeType};base64,${base64Data}`;

  res.json({
    message: 'File encoded and ready for SQLite storage',
    filename: req.file.originalname,
    url: dataUrl
  });
});

// ============================================================================
// 1. VISITOR ACCOUNTS DATABASE ROUTES (`visitor_accounts`)
// ============================================================================
app.get('/api/visitors', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM visitor_accounts ORDER BY createdAt DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/visitors/register', async (req, res) => {
  try {
    const v = req.body;
    await dbRun(
      `INSERT OR REPLACE INTO visitor_accounts (email, name, username, authMethod, phone, address)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        v.email,
        v.name || 'Festival Visitor',
        v.username || '@visitor',
        v.authMethod || 'Email',
        v.phone || '',
        v.address || ''
      ]
    );
    res.status(201).json({ message: 'Visitor saved to visitor_accounts database', email: v.email });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 2 & 3. ORGANIZER ACCOUNTS & PENDING ORGANIZER APPROVALS ROUTES
// (`organizer_accounts` AND `pending_organizer_accounts`)
// ============================================================================

// GET combined or separated organizers for Admin Panel & App
app.get('/api/organizers', async (req, res) => {
  try {
    const approvedRows = await dbAll('SELECT * FROM organizer_accounts ORDER BY registeredAt DESC');
    const pendingRows = await dbAll('SELECT * FROM pending_organizer_accounts ORDER BY registeredAt DESC');

    const approvedList = approvedRows.map(r => ({
      ...r,
      isApproved: true,
      status: 'Approved'
    }));
    const pendingList = pendingRows.map(r => ({
      ...r,
      isApproved: false,
      status: r.status || 'Pending Approval'
    }));

    res.json([...pendingList, ...approvedList]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/organizers/approved', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM organizer_accounts ORDER BY registeredAt DESC');
    res.json(rows.map(r => ({ ...r, isApproved: true, status: 'Approved' })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/organizers/pending', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM pending_organizer_accounts ORDER BY registeredAt DESC');
    res.json(rows.map(r => ({ ...r, isApproved: false, status: 'Pending Approval' })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/organizers/register -> Always goes into `pending_organizer_accounts`!
app.post('/api/organizers/register', async (req, res) => {
  try {
    const o = req.body;
    // Remove from approved if re-registering
    await dbRun('DELETE FROM organizer_accounts WHERE email = ?', [o.email]);

    await dbRun(
      `INSERT OR REPLACE INTO pending_organizer_accounts (
        email, name, companyName, kvkNumber, vatNumber, phone,
        businessAddress, govIdType, govIdNumber, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending Approval')`,
      [
        o.email,
        o.name || o.companyName,
        o.companyName || o.name,
        o.kvkNumber || '',
        o.vatNumber || '',
        o.phone || '',
        o.businessAddress || '',
        o.govIdType || 'Dutch Passport',
        o.govIdNumber || ''
      ]
    );
    res.status(201).json({ message: 'Organizer staged in pending_organizer_accounts', email: o.email });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/organizers/:email/approve
// If approved == true: moves record from `pending_organizer_accounts` -> `organizer_accounts`
// If approved == false (Rejected): deletes from both tables immediately!
app.post('/api/organizers/:email/approve', async (req, res) => {
  try {
    const email = req.params.email;
    const { approved } = req.body;

    if (approved) {
      const pending = await dbGet('SELECT * FROM pending_organizer_accounts WHERE email = ?', [email]);
      if (pending) {
        await dbRun(
          `INSERT OR REPLACE INTO organizer_accounts (
            email, name, companyName, kvkNumber, vatNumber, phone,
            businessAddress, govIdType, govIdNumber, status, registeredAt
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Approved', ?)`,
          [
            pending.email,
            pending.name,
            pending.companyName,
            pending.kvkNumber,
            pending.vatNumber || '',
            pending.phone,
            pending.businessAddress,
            pending.govIdType,
            pending.govIdNumber,
            pending.registeredAt
          ]
        );
        await dbRun('DELETE FROM pending_organizer_accounts WHERE email = ?', [email]);
      }
      res.json({ message: `Organizer ${email} approved and moved to organizer_accounts`, approved: true, status: 'Approved' });
    } else {
      // Rejected or deleted: remove completely from both tables
      await dbRun('DELETE FROM pending_organizer_accounts WHERE email = ?', [email]);
      await dbRun('DELETE FROM organizer_accounts WHERE email = ?', [email]);
      res.json({ message: `Organizer ${email} rejected and deleted from databases`, approved: false, deleted: true });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/organizers/:email
app.delete('/api/organizers/:email', async (req, res) => {
  try {
    const email = req.params.email;
    await dbRun('DELETE FROM pending_organizer_accounts WHERE email = ?', [email]);
    await dbRun('DELETE FROM organizer_accounts WHERE email = ?', [email]);
    res.json({ message: `Organizer ${email} permanently deleted` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 4 & 5. PUBLISHED EVENTS & PENDING EVENT APPROVALS ROUTES
// (`published_events` AND `pending_event_approvals`)
// ============================================================================

// GET all festivals (combines published_events + pending_event_approvals)
app.get('/api/festivals', async (req, res) => {
  try {
    const publishedRows = await dbAll('SELECT * FROM published_events ORDER BY createdAt DESC');
    const pendingRows = await dbAll('SELECT * FROM pending_event_approvals ORDER BY createdAt DESC');

    const published = publishedRows.map(r => formatEventRow(r, true));
    const pending = pendingRows.map(r => formatEventRow(r, false));

    res.json([...pending, ...published]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/festivals/published', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM published_events ORDER BY createdAt DESC');
    res.json(rows.map(r => formatEventRow(r, true)));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/festivals/pending', async (req, res) => {
  try {
    const rows = await dbAll('SELECT * FROM pending_event_approvals ORDER BY createdAt DESC');
    res.json(rows.map(r => formatEventRow(r, false)));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/festivals -> Inserts into `pending_event_approvals` (or moves to `published_events` if approved by Admin)
app.post('/api/festivals', async (req, res) => {
  try {
    const f = req.body;
    const isApproved = Boolean(f.isApprovedByAdmin);
    const targetTable = isApproved ? 'published_events' : 'pending_event_approvals';

    // If it is being approved, remove it from pending_event_approvals
    if (isApproved) {
      await dbRun('DELETE FROM pending_event_approvals WHERE id = ?', [f.id]);
    }

    const query = `
      INSERT OR REPLACE INTO ${targetTable} (
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
      isApproved ? 1 : 0,
      f.latitude || 51.4416,
      f.longitude || 5.4697,
      f.coverImageLabel || 'Custom Cover',
      f.bannerImagePath || null
    ];

    await dbRun(query, values);
    res.status(201).json({ message: `Festival saved in ${targetTable}`, id: f.id, table: targetTable });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/festivals/:id/approve -> Moves from `pending_event_approvals` to `published_events`
app.post('/api/festivals/:id/approve', async (req, res) => {
  try {
    const festivalId = req.params.id;
    const pending = await dbGet('SELECT * FROM pending_event_approvals WHERE id = ?', [festivalId]);
    if (pending) {
      await dbRun(
        `INSERT OR REPLACE INTO published_events (
          id, name, tagline, categoryLabel, dates, city, venueAddress,
          distanceKm, priceEur, ticketsSoldInApp, capacity, genres,
          howToGetThere, publicTransportInfo, festivalTransportOffer,
          organizerName, ecoCommitments, primaryColor, secondaryColor,
          isApprovedByAdmin, latitude, longitude, coverImageLabel, bannerImagePath
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)`,
        [
          pending.id, pending.name, pending.tagline, pending.categoryLabel,
          pending.dates, pending.city, pending.venueAddress, pending.distanceKm,
          pending.priceEur, pending.ticketsSoldInApp, pending.capacity, pending.genres,
          pending.howToGetThere, pending.publicTransportInfo, pending.festivalTransportOffer,
          pending.organizerName, pending.ecoCommitments, pending.primaryColor,
          pending.secondaryColor, pending.latitude, pending.longitude,
          pending.coverImageLabel, pending.bannerImagePath
        ]
      );
      await dbRun('DELETE FROM pending_event_approvals WHERE id = ?', [festivalId]);
    }
    res.json({ message: 'Festival approved and moved to published_events', id: festivalId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT / update festival in whichever table it resides
app.put('/api/festivals/:id', async (req, res) => {
  try {
    const festivalId = req.params.id;
    const f = req.body;

    for (const table of ['published_events', 'pending_event_approvals']) {
      await dbRun(
        `UPDATE ${table} SET
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
          latitude = COALESCE(?, latitude),
          longitude = COALESCE(?, longitude),
          bannerImagePath = COALESCE(?, bannerImagePath)
        WHERE id = ?`,
        [
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
          f.latitude ?? null,
          f.longitude ?? null,
          f.bannerImagePath ?? null,
          festivalId
        ]
      );
    }

    res.json({ message: 'Festival updated successfully', id: festivalId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE festival (Reject or Delete removes from both pending_event_approvals and published_events)
app.delete('/api/festivals/:id', async (req, res) => {
  try {
    const festivalId = req.params.id;
    await dbRun('DELETE FROM pending_event_approvals WHERE id = ?', [festivalId]);
    await dbRun('DELETE FROM published_events WHERE id = ?', [festivalId]);
    res.json({ message: 'Festival deleted from databases', id: festivalId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---------------------- ANNOUNCEMENT ROUTES ----------------------

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

app.post('/api/announcements', async (req, res) => {
  try {
    const a = req.body;
    const id = a.id || `ann_${Date.now()}`;
    await dbRun(
      `INSERT OR REPLACE INTO announcements (id, title, message, category, isActive)
       VALUES (?, ?, ?, ?, ?)`,
      [
        id,
        a.title || 'Important Notice',
        a.message || '',
        a.category || 'Update',
        a.isActive !== undefined ? (a.isActive ? 1 : 0) : 1
      ]
    );
    res.status(201).json({ message: 'Announcement published', id: id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/announcements/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const result = await dbRun('DELETE FROM announcements WHERE id = ?', [id]);
    res.json({ message: 'Announcement deleted', id: id, changes: result.changes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = app;

if (require.main === module && !process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(`🚀 Festival Buddy 5-Database SQLite API Server running!`);
    console.log(`Local Access:   http://localhost:${PORT}`);
    console.log(`Mode:           ${process.env.TURSO_DATABASE_URL ? 'Turso Cloud SQLite' : 'Local SQLite File'}`);
    console.log(`====================================================`);
  });
}
