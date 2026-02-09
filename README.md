# Finan-as (Base44)

Aplicativo Android para gravação/importação de áudio, transcrição via ElevenLabs e análise avançada via OpenAI. O app Flutter conversa somente com o backend, sem armazenar chaves no mobile.

## Estrutura de pastas
```
backend/   # API Node.js + BullMQ worker
mobile/    # Flutter Android
postman/   # Coleção Postman
```

## Backend

### Requisitos
- Node.js 18+
- PostgreSQL
- Redis

### Setup
```bash
cd backend
cp .env.example .env
npm install
```

Crie o banco e aplique o schema:
```bash
psql $DATABASE_URL -f src/sql/schema.sql
```

### Rodar API
```bash
npm run dev
```

### Rodar Worker
```bash
npm run worker
```

### Variáveis principais
- `DATABASE_URL`
- `JWT_SECRET`
- `ELEVENLABS_API_KEY`
- `OPENAI_API_KEY`
- `REDIS_URL`
- `STORAGE_MODE=local|s3`

## Mobile (Flutter)

### Setup
```bash
cd mobile
cp .env.example .env
flutter pub get
```

### Rodar no Android
```bash
flutter run
```

### Build APK release
```bash
flutter build apk --release
```

## API

Endpoints principais:
- `POST /auth/register`
- `POST /auth/login`
- `POST /audio/upload`
- `GET /jobs` (lista últimos 20)
- `GET /jobs/:id`
- `POST /jobs/:id/reanalyze`
- `POST /webhooks/elevenlabs`

A coleção Postman está em `postman/finan-as.postman_collection.json`.

## Notas de segurança
- As chaves de API ficam somente no backend.
- O app mobile usa apenas o JWT e chama o backend.
