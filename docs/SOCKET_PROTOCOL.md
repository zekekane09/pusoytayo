# Socket.IO Protocol

## Connection

Connect to `ws://localhost:3000` with JWT in handshake:

```javascript
const socket = io('http://localhost:3000', {
  auth: { token: 'your-jwt-token' }
});
```

## Lobby Events

| Direction | Event | Payload |
|-----------|-------|---------|
| C→S | `lobby:list` | `{}` |
| S→C | `lobby:rooms_list` | `{ rooms: Room[] }` |
| C→S | `lobby:create` | `{ gameMode, betAmount, currency }` |
| S→C | `lobby:room_created` | `{ code, status, gameMode, betAmount }` |
| C→S | `lobby:join` | `{ roomCode }` |
| S→C | `lobby:joined` | `{ roomCode, seat }` |
| C→S | `lobby:leave` | `{ roomCode }` |
| S→C | `lobby:left` | `{ roomCode }` |
| S→C | `lobby:room_updated` | `{ code, players[], currentPlayers }` |
| S→C | `lobby:error` | `{ message }` |

## Game Events

| Direction | Event | Payload |
|-----------|-------|---------|
| C→S | `game:ready` | `{ roomCode }` |
| S→C | `game:start` | `{ countdown }` |
| S→C | `game:deal` | `{ cards: Card[] }` (private to each player) |
| S→C | `game:arrange_phase` | `{ timeLimit: 90 }` |
| C→S | `game:arrange` | `{ roomCode, front[], middle[], back[] }` |
| S→C | `game:arranged` | `{ userId }` |
| S→C | `game:timer` | `{ phase, secondsLeft }` |
| S→C | `game:finished` | `{ scores, winnerId }` |
| S→C | `game:error` | `{ message }` |

## Card Encoding

```typescript
interface Card {
  rank: number;  // 3-15 (15 = 2, the highest)
  suit: 'S' | 'H' | 'D' | 'C';
}
```

## Game Flow

1. Players join room via `lobby:join`
2. All players send `game:ready`
3. Server sends `game:start` with 3-second countdown
4. Server deals 13 cards to each player via `game:deal`
5. Server sends `game:arrange_phase` with 90-second timer
6. Players arrange cards and submit via `game:arrange`
7. Server validates arrangement (back >= middle >= front)
8. When all players submit (or timer expires), server calculates scores
9. Server sends `game:finished` with scores and winner
