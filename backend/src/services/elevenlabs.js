const fetch = require('node-fetch');
const FormData = require('form-data');
const fs = require('fs');

const apiKey = process.env.ELEVENLABS_API_KEY;
const baseUrl = process.env.ELEVENLABS_BASE_URL || 'https://api.elevenlabs.io/v1';

async function createTranscriptionJob({ filePath, mimeType, jobId, webhookUrl }) {
  if (!apiKey) {
    throw new Error('Missing ELEVENLABS_API_KEY');
  }
  const form = new FormData();
  form.append('file', fs.createReadStream(filePath), { contentType: mimeType });
  form.append('model_id', process.env.ELEVENLABS_MODEL_ID || 'scribe_v1');
  form.append('webhook_url', webhookUrl);
  form.append('metadata', JSON.stringify({ job_id: jobId }));

  const response = await fetch(`${baseUrl}/speech-to-text/async`, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey
    },
    body: form
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs STT error: ${errorText}`);
  }

  const data = await response.json();
  return {
    elevenJobId: data.job_id || data.id
  };
}

module.exports = {
  createTranscriptionJob
};
