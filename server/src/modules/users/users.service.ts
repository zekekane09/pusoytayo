import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { id } });
  }

  async findByFirebaseUid(firebaseUid: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { firebaseUid } });
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { username } });
  }

  async createPasswordUser(data: {
    username: string;
    passwordHash: string;
    displayName: string;
    deviceId?: string | null;
    signupIp?: string | null;
    bonusClaimed?: boolean;
  }): Promise<User> {
    const user = this.userRepo.create({
      firebaseUid: `pwd_${data.username}_${Date.now()}`,
      username: data.username,
      passwordHash: data.passwordHash,
      displayName: data.displayName,
      authProvider: 'password',
      isGuest: false,
      deviceId: data.deviceId ?? null,
      signupIp: data.signupIp ?? null,
      bonusClaimed: data.bonusClaimed ?? false,
    });
    return this.userRepo.save(user);
  }

  /** Has this device already claimed the free sign-up bonus? */
  async deviceHasAccount(deviceId: string): Promise<boolean> {
    if (!deviceId) return false;
    const n = await this.userRepo.count({ where: { deviceId } });
    return n > 0;
  }

  /** Has an account from this IP already claimed the free bonus? */
  async ipHasBonus(ip: string): Promise<boolean> {
    if (!ip) return false;
    const n = await this.userRepo.count({
      where: { signupIp: ip, bonusClaimed: true },
    });
    return n > 0;
  }

  async upsertFromFirebase(data: {
    firebaseUid: string;
    displayName: string;
    email?: string;
    phoneNumber?: string;
    avatarUrl?: string;
    authProvider: string;
    isGuest: boolean;
  }): Promise<User> {
    let user = await this.findByFirebaseUid(data.firebaseUid);

    if (user) {
      user.displayName = data.displayName || user.displayName;
      user.avatarUrl = data.avatarUrl || user.avatarUrl;
      user.email = data.email || user.email;
      user.phoneNumber = data.phoneNumber || user.phoneNumber;
      return this.userRepo.save(user);
    }

    user = this.userRepo.create({
      firebaseUid: data.firebaseUid,
      displayName: data.displayName || `Player${Date.now().toString(36)}`,
      email: data.email,
      phoneNumber: data.phoneNumber,
      avatarUrl: data.avatarUrl,
      authProvider: data.authProvider,
      isGuest: data.isGuest,
    });

    return this.userRepo.save(user);
  }

  async updateProfile(
    id: string,
    data: Partial<Pick<User, 'displayName' | 'avatarUrl'>>,
  ): Promise<User> {
    await this.userRepo.update(id, data);
    return this.userRepo.findOneOrFail({ where: { id } });
  }
}
