const express = require('express');
const crypto = require('crypto');
const { getPool } = require('../db');
const { analysisQueue } = require('../services/queue');

const router = express.Router();

router.post('/elevenlabs', express.json({ limit: '2mb' }), async (req, res, next) => {
  try {
    const secret = process.env.ELEVENLABS_WEBHOOK_SECRET;
    if (secret) {
      const signature = req.headers['x-elevenlabs-signature'];
      const digest = crypto
        .createHmac('sha256', secret)
        .update(JSON.stringify(req.body))
        .digest('hex');
      if (!signature || signature !== digest) {
        return res.status(401).json({ error: 'Invalid signature' });
      }
    }

    const payload = req.body || {};
    const metadata = payload.metadata || {};
    const jobId = metadata.job_id || payload.job_id || payload.id;
    if (!jobId) {
      return res.status(400).json({ error: 'Missing job_id' });
    }

    const transcriptRaw = payload.text || payload.transcript || payload.transcription || '';
    const pool = getPool();

    await pool.query(
      'UPDATE audio_jobs SET transcript_raw = $1, status = $2, updated_at = NOW() WHERE id = $3',
      [transcriptRaw, 'ANALYZING', jobId]
    );

    await analysisQueue.add('analyze', { jobId });

    return res.json({ status: 'ok' });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
