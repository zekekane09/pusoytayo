import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as admin from 'firebase-admin';
import * as bcrypt from 'bcryptjs';
import * as fs from 'fs';
import { UsersService } from '../users/users.service';
import { WalletService } from '../wallet/wallet.service';
import { RankingService } from '../ranking/ranking.service';

@Injectable()
export class AuthService {
  private firebaseApp: admin.app.App | null = null;

  constructor(
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService,
    private readonly walletService: WalletService,
    private readonly rankingService: RankingService,
  ) {
    this.initFirebase();
  }

  private initFirebase() {
    // Service account can come from FIREBASE_SERVICE_ACCOUNT (the JSON itself —
    // handy on cloud hosts) or GOOGLE_APPLICATION_CREDENTIALS (a file path). We
    // intentionally do NOT fall back to gcloud Application Default Credentials,
    // which can silently pick up an unrelated project. None => DEV MODE.
    try {
      const saJson = process.env.FIREBASE_SERVICE_ACCOUNT;
      const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
      let credential: admin.credential.Credential | null = null;
      if (saJson && saJson.trim().startsWith('{')) {
        credential = admin.credential.cert(JSON.parse(saJson));
      } else if (saPath && fs.existsSync(saPath)) {
        credential = admin.credential.cert(saPath);
      }
      if (!credential) {
        console.warn(
          '[auth] No Firebase service account (FIREBASE_SERVICE_ACCOUNT or ' +
            'GOOGLE_APPLICATION_CREDENTIALS) — DEV MODE: Firebase ID tokens are ' +
            'decoded but NOT cryptographically verified.',
        );
        return;
      }
      this.firebaseApp = admin.apps.length
        ? admin.apps[0]!
        : admin.initializeApp({ credential });
      console.log('[auth] Firebase Admin initialized — verifying ID tokens.');
    } catch (e: any) {
      console.warn(
        '[auth] Firebase Admin init failed, falling back to DEV MODE:',
        e?.message,
      );
    }
  }

  /** Decode a JWT payload without verifying its signature (DEV MODE only). */
  private decodeJwtNoVerify(token: string): any | null {
    try {
      const part = token.split('.')[1];
      if (!part) return null;
      const json = Buffer.from(part, 'base64').toString('utf8');
      return JSON.parse(json);
    } catch {
      return null;
    }
  }

  async login(dto: {
    firebaseToken: string;
    displayName?: string;
    email?: string;
    phoneNumber?: string;
    avatarUrl?: string;
    isGuest?: boolean;
  }) {
    let firebaseUid: string;
    let authProvider = 'unknown';

    if (dto.isGuest && dto.firebaseToken?.startsWith('guest_')) {
      // Guest sessions are not Firebase-backed — trust the unique guest id so
      // anyone can play without any auth-provider configuration.
      firebaseUid = dto.firebaseToken;
      authProvider = 'guest';
    } else if (this.firebaseApp) {
      try {
        const decoded = await admin.auth().verifyIdToken(dto.firebaseToken);
        firebaseUid = decoded.uid;
        authProvider = decoded.firebase?.sign_in_provider || 'unknown';
      } catch (e) {
        throw new UnauthorizedException('Invalid Firebase token');
      }
    } else {
      // DEV MODE: trust the client, but still extract the real uid/provider by
      // decoding the (unverified) token so multiple accounts don't collide.
      const decoded = this.decodeJwtNoVerify(dto.firebaseToken);
      firebaseUid =
        decoded?.user_id ||
        decoded?.sub ||
        `dev_${dto.firebaseToken.substring(0, 24)}`;
      authProvider = decoded?.firebase?.sign_in_provider || 'dev';
    }

    const user = await this.usersService.upsertFromFirebase({
      firebaseUid,
      displayName: dto.displayName || 'Player',
      email: dto.email,
      phoneNumber: dto.phoneNumber,
      avatarUrl: dto.avatarUrl,
      authProvider,
      isGuest: dto.isGuest || false,
    });

    await this.walletService.ensureWallet(user.id);
    await this.rankingService.ensureRanking(user.id);

    const payload = { sub: user.id, uid: user.firebaseUid };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });

    return { accessToken, refreshToken, user };
  }

  /**
   * Self sign-up with username + password. New players get 100 free coins that
   * are locked (non-withdrawable) until wagered & won.
   */
  async registerWithUsername(
    username: string,
    password: string,
    displayName?: string,
    deviceId?: string,
  ) {
    const uname = (username || '').trim().toLowerCase();
    if (uname.length < 3 || (password || '').length < 4) {
      throw new BadRequestException(
        'Username (3+) and password (4+) are required',
      );
    }
    if (await this.usersService.findByUsername(uname)) {
      throw new BadRequestException('Username already taken');
    }
    // One free bonus per device: if this device already made an account, the
    // new account starts at 0 coins.
    const alreadyClaimed = deviceId
      ? await this.usersService.deviceHasAccount(deviceId)
      : false;
    const bonus = alreadyClaimed ? 0 : 100;

    const user = await this.usersService.createPasswordUser({
      username: uname,
      passwordHash: await bcrypt.hash(password, 10),
      displayName: (displayName || '').trim() || uname,
      deviceId: deviceId ?? null,
    });
    // Free coins (locked until won) — only for the first account on a device.
    await this.walletService.ensureWallet(user.id, bonus, bonus);
    await this.rankingService.ensureRanking(user.id);

    const payload = { sub: user.id, uid: user.firebaseUid };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });
    return { accessToken, refreshToken, user };
  }

  /** Username + password login for accounts created by the admin. */
  async loginWithUsername(username: string, password: string) {
    const user = await this.usersService.findByUsername(
      (username || '').trim().toLowerCase(),
    );
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid username or password');
    }
    const ok = await bcrypt.compare(password || '', user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid username or password');

    await this.walletService.ensureWallet(user.id);
    await this.rankingService.ensureRanking(user.id);

    const payload = { sub: user.id, uid: user.firebaseUid };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, { expiresIn: '30d' });
    return { accessToken, refreshToken, user };
  }

  async refreshToken(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken);
      const newToken = this.jwtService.sign({
        sub: payload.sub,
        uid: payload.uid,
      });
      return { accessToken: newToken };
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }
}
