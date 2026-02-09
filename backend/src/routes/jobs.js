const express = require('express');
const { authRequired } = require('./middleware');
const { getPool } = require('../db');
const { analysisQueue } = require('../services/queue');

const router = express.Router();

router.get('/', authRequired, async (req, res, next) => {
  try {
    const pool = getPool();
    const result = await pool.query(
      'SELECT id, status, original_filename, created_at, updated_at FROM audio_jobs WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20',
      [req.user.userId]
    );
    return res.json({ jobs: result.rows });
  } catch (error) {
    return next(error);
  }
});

router.get('/:id', authRequired, async (req, res, next) => {
  try {
    const pool = getPool();
    const result = await pool.query('SELECT * FROM audio_jobs WHERE id = $1 AND user_id = $2', [req.params.id, req.user.userId]);
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Job not found' });
    }
    return res.json({ job: result.rows[0] });
  } catch (error) {
    return next(error);
  }
});

router.post('/:id/reanalyze', authRequired, async (req, res, next) => {
  try {
    const pool = getPool();
    const result = await pool.query('SELECT * FROM audio_jobs WHERE id = $1 AND user_id = $2', [req.params.id, req.user.userId]);
    if (!result.rows.length) {
      return res.status(404).json({ error: 'Job not found' });
    }
    const job = result.rows[0];
    if (!job.transcript_raw) {
      return res.status(400).json({ error: 'No transcript to analyze yet' });
    }

    await pool.query('UPDATE audio_jobs SET status = $1, updated_at = NOW() WHERE id = $2', ['ANALYZING', job.id]);
    await analysisQueue.add('analyze', { jobId: job.id });

    return res.json({ status: 'queued' });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
