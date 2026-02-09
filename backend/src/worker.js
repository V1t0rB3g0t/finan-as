require('dotenv').config();

const { Worker } = require('bullmq');
const IORedis = require('ioredis');
const { getPool } = require('./db');
const { deleteFile } = require('./services/storage');
const OpenAI = require('openai');

const connection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379');

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const promptTemplate = `Você é um assistente especialista em transcrições. Receba a transcrição bruta e produza JSON estrito.

Regras:
- Mantenha o sentido original e corrija pontuação, parágrafos e marcas de fala quando possível.
- Não invente conteúdo.
- Use português brasileiro.
- Retorne JSON válido conforme o schema solicitado.\n`;

async function processJob(jobId) {
  const pool = getPool();
  const result = await pool.query('SELECT * FROM audio_jobs WHERE id = $1', [jobId]);
  if (!result.rows.length) {
    throw new Error('Job not found');
  }
  const job = result.rows[0];
  if (!job.transcript_raw) {
    throw new Error('Transcript missing');
  }

  const response = await openai.responses.create({
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    input: [
      {
        role: 'system',
        content: promptTemplate
      },
      {
        role: 'user',
        content: `Transcrição bruta:\n${job.transcript_raw}`
      }
    ],
    response_format: {
      type: 'json_schema',
      json_schema: {
        name: 'transcript_analysis',
        strict: true,
        schema: {
          type: 'object',
          additionalProperties: false,
          properties: {
            transcript_clean: { type: 'string' },
            executive_summary: { type: 'string' },
            key_topics: { type: 'array', items: { type: 'string' } },
            decisions: {
              type: 'array',
              items: {
                type: 'object',
                additionalProperties: false,
                properties: {
                  decision: { type: 'string' },
                  evidence: { type: 'string' }
                },
                required: ['decision', 'evidence']
              }
            },
            action_items: {
              type: 'array',
              items: {
                type: 'object',
                additionalProperties: false,
                properties: {
                  task: { type: 'string' },
                  owner: { type: 'string' },
                  due_date: { type: 'string' },
                  priority: { type: 'string', enum: ['low', 'medium', 'high'] }
                },
                required: ['task', 'owner', 'due_date', 'priority']
              }
            },
            open_questions: { type: 'array', items: { type: 'string' } },
            insights: { type: 'array', items: { type: 'string' } },
            next_steps: { type: 'array', items: { type: 'string' } },
            tags: { type: 'array', items: { type: 'string' } }
          },
          required: [
            'transcript_clean',
            'executive_summary',
            'key_topics',
            'decisions',
            'action_items',
            'open_questions',
            'insights',
            'next_steps',
            'tags'
          ]
        }
      }
    }
  });

  const content = response.output_text || '';
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (error) {
    throw new Error(`OpenAI returned invalid JSON: ${content}`);
  }

  await pool.query(
    'UPDATE audio_jobs SET transcript_clean = $1, analysis_json = $2, status = $3, updated_at = NOW() WHERE id = $4',
    [parsed.transcript_clean, parsed, 'DONE', jobId]
  );

  if (process.env.DELETE_AFTER_PROCESSING === 'true') {
    await deleteFile(job.audio_storage_key, job.audio_storage_url);
  }
}

const worker = new Worker(
  'analysis',
  async job => {
    const jobId = job.data.jobId;
    await processJob(jobId);
  },
  { connection }
);

worker.on('failed', async (job, err) => {
  console.error('Job failed', err);
  if (job?.data?.jobId) {
    const pool = getPool();
    await pool.query(
      'UPDATE audio_jobs SET status = $1, error_message = $2, updated_at = NOW() WHERE id = $3',
      ['ERROR', err.message, job.data.jobId]
    );
  }
});

console.log('Worker started');
