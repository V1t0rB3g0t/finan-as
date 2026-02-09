const fs = require('fs');
const path = require('path');
const { S3Client } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');

const storageMode = (process.env.STORAGE_MODE || 'local').toLowerCase();
const localRoot = process.env.LOCAL_STORAGE_PATH || path.join(__dirname, '..', '..', 'storage');

function ensureLocalRoot() {
  if (!fs.existsSync(localRoot)) {
    fs.mkdirSync(localRoot, { recursive: true });
  }
}

async function saveLocal(file) {
  ensureLocalRoot();
  const filename = `${Date.now()}-${file.originalname}`.replace(/\s+/g, '_');
  const destination = path.join(localRoot, filename);
  await fs.promises.rename(file.path, destination);
  return { url: destination, storageKey: filename };
}

async function saveS3(file) {
  const client = new S3Client({
    region: process.env.S3_REGION,
    endpoint: process.env.S3_ENDPOINT,
    credentials: {
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
    },
    forcePathStyle: process.env.S3_FORCE_PATH_STYLE === 'true'
  });

  const key = `${Date.now()}-${file.originalname}`.replace(/\s+/g, '_');
  const upload = new Upload({
    client,
    params: {
      Bucket: process.env.S3_BUCKET,
      Key: key,
      Body: fs.createReadStream(file.path),
      ContentType: file.mimetype
    }
  });

  await upload.done();
  await fs.promises.unlink(file.path);
  const url = `${process.env.S3_PUBLIC_URL || ''}/${key}`.replace(/\/+$/, '');
  return { url, storageKey: key };
}

async function deleteFile(storageKey, url) {
  if (!storageKey && !url) {
    return;
  }
  if (storageMode === 's3') {
    const client = new S3Client({
      region: process.env.S3_REGION,
      endpoint: process.env.S3_ENDPOINT,
      credentials: {
        accessKeyId: process.env.S3_ACCESS_KEY_ID,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
      },
      forcePathStyle: process.env.S3_FORCE_PATH_STYLE === 'true'
    });
    const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
    await client.send(
      new DeleteObjectCommand({
        Bucket: process.env.S3_BUCKET,
        Key: storageKey
      })
    );
    return;
  }
  const target = url || path.join(localRoot, storageKey);
  if (fs.existsSync(target)) {
    await fs.promises.unlink(target);
  }
}

async function saveFile(file) {
  if (storageMode === 's3') {
    return saveS3(file);
  }
  return saveLocal(file);
}

module.exports = {
  saveFile,
  deleteFile
};
