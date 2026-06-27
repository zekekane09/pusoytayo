# Pusoy Tayo

Online Multiplayer Competitive 13-Card Pusoy Game

## Tech Stack

- **Frontend**: Flutter (Riverpod, GoRouter, Material 3, flutter_animate)
- **Backend**: NestJS (Socket.IO, TypeORM, Passport JWT)
- **Database**: PostgreSQL
- **Cache**: Redis
- **Auth**: Firebase Authentication
- **Payments**: GCash integration (stub)

## Project Structure

```
pusoy_tayo/
├── client/          # Flutter mobile app
├── server/          # NestJS backend
├── docs/            # Documentation
└── README.md
```

## Quick Start

### Prerequisites

- Flutter SDK (latest stable)
- Node.js 18+
- Docker & Docker Compose
- Firebase project

### Backend Setup

```bash
cd server

# Start PostgreSQL and Redis
docker-compose up -d

# Install dependencies
npm install

# Copy environment config
cp .env.example .env

# Start development server
npm run start:dev
```

Server runs at `http://localhost:3000`
API docs at `http://localhost:3000/api/docs`

### Frontend Setup

```bash
cd client

# Install dependencies
flutter pub get

# Run on device/simulator
flutter run
```

### Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Authentication providers: Google, Facebook, Apple, Phone
3. Download `google-services.json` to `client/android/app/`
4. Download `GoogleService-Info.plist` to `client/ios/Runner/`
5. Set Firebase Admin credentials in `server/.env`

## Game Rules

Pusoy (Chinese Poker) with Filipino rules:

- 4 players, 13 cards each
- Arrange cards into 3 hands:
  - **Front**: 3 cards (weakest)
  - **Middle**: 5 cards
  - **Back**: 5 cards (strongest)
- Back hand must beat middle, middle must beat front
- Card ranking: 3 (lowest) → A → **2 (highest)**
- Suit ranking: Diamonds < Clubs < Hearts < Spades
- **2♠ is the strongest single card**
- Scoop bonus: Win all 3 rows vs an opponent = double points

## Hand Rankings (5-card)

1. Royal Flush
2. Straight Flush
3. Four of a Kind
4. Full House
5. Flush
6. Straight
7. High Card

## Ranking Tiers

| Tier | Points | Win Bonus | Loss Penalty |
|------|--------|-----------|--------------|
| Bronze | 0-999 | +25 | -10 |
| Silver | 1000-2499 | +20 | -12 |
| Gold | 2500-4999 | +18 | -15 |
| Platinum | 5000-7999 | +15 | -15 |
| Diamond | 8000-11999 | +12 | -18 |
| Legend | 12000+ | +10 | -20 |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/auth/login | Login with Firebase token |
| POST | /api/auth/refresh | Refresh JWT |
| GET | /api/auth/profile | Get current user |
| GET | /api/wallet | Get wallet balance |
| GET | /api/wallet/transactions | Transaction history |
| GET | /api/rankings | Get player ranking |
| GET | /api/rankings/leaderboard | Top 100 players |
| GET | /api/health | Health check |

## Socket.IO Events

See [docs/SOCKET_PROTOCOL.md](docs/SOCKET_PROTOCOL.md)

## Deployment

### Android

```bash
cd client
flutter build appbundle --release
```

### iOS

```bash
cd client
flutter build ipa --release
```

### Backend

```bash
cd server
npm run build
docker build -t pusoy-tayo-server .
```

## License

Proprietary - All rights reserved
