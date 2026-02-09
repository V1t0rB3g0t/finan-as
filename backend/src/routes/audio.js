const express = require('express');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { authRequired } = require('./middleware');
const { getPool } = require('../db');
const { saveFile } = require('../services/storage');
const { createTranscriptionJob } = require('../services/elevenlabs');

const router = express.Router();

const tmpDir = path.join(__dirname, '..', '..', 'tmp');
require('fs').mkdirSync(tmpDir, { recursive: true });

const upload = multer({
  dest: tmpDir,
  limits: { fileSize: 100 * 1024 * 1024 }
});

router.post('/upload', authRequired, upload.single('file'), async (req, res, next) => {
  let jobId;
  try {
    const file = req.file;
    if (!file) {
      return res.status(400).json({ error: 'File required' });
    }

    const pool = getPool();
    jobId = uuidv4();

    await pool.query(
      `INSERT INTO audio_jobs (
        id, user_id, status, original_filename, mime_type, duration_seconds,
        audio_storage_url, audio_storage_key, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())`,
      [
        jobId,
        req.user.userId,
        'UPLOADING',
        file.originalname,
        file.mimetype,
        null,
        null,
        null
      ]
    );

    const webhookUrl = `${process.env.PUBLIC_BASE_URL}/webhooks/elevenlabs`;
    const { elevenJobId } = await createTranscriptionJob({
      filePath: file.path,
      mimeType: file.mimetype,
      jobId,
      webhookUrl
    });

    const { url, storageKey } = await saveFile(file);

    await pool.query(
      'UPDATE audio_jobs SET status = $1, audio_storage_url = $2, audio_storage_key = $3, eleven_job_id = $4, updated_at = NOW() WHERE id = $5',
      ['TRANSCRIBING', url, storageKey, elevenJobId, jobId]
    );

    return res.json({ job_id: jobId });
  } catch (error) {
    if (req?.file?.path) {
      require('fs').promises.unlink(req.file.path).catch(() => {});
    }
    if (jobId) {
      const pool = getPool();
      await pool.query(
        'UPDATE audio_jobs SET status = $1, error_message = $2, updated_at = NOW() WHERE id = $3',
        ['ERROR', error.message, jobId]
      );
    }
    return next(error);
  }
});

module.exports = router;
