// Vercel Serverless Function Entrypoint
// Routes all /api/* requests to our Express + SQLite/Turso application
const app = require('../server/index.js');

module.exports = app;
