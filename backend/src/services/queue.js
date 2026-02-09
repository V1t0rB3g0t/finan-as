const { Queue } = require('bullmq');
const IORedis = require('ioredis');

const connection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379');

const analysisQueue = new Queue('analysis', { connection });

module.exports = {
  analysisQueue,
  connection
};
