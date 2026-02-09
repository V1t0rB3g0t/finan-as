require('dotenv').config();

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { Pool } = require('pg');
const authRoutes = require('./routes/auth');
const audioRoutes = require('./routes/audio');
const jobRoutes = require('./routes/jobs');
const webhookRoutes = require('./routes/webhook');

const app = express();
const port = process.env.PORT || 4000;

app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '2mb' }));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

app.set('db', pool);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/auth', authRoutes);
app.use('/audio', audioRoutes);
app.use('/jobs', jobRoutes);
app.use('/webhooks', webhookRoutes);

app.use((err, req, res, next) => {
  console.error('Unhandled error', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(port, () => {
  console.log(`API running on port ${port}`);
});
