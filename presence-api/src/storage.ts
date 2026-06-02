import { Redis } from '@upstash/redis';

import type { PresenceRecord } from './types.js';

const hasRedisConfig = Boolean(process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN);
const redis = hasRedisConfig ? Redis.fromEnv() : null;

function peerStorageKey(peerId: string): string {
  return `presence:peer:${peerId}`;
}

function pruneRecords(records: PresenceRecord[]): PresenceRecord[] {
  const now = Date.now();
  return records.filter((record) => Date.parse(record.expiresAt) > now);
}

export class PresenceStore {
  private readonly memory = new Map<string, PresenceRecord[]>();

  get mode(): 'redis' | 'memory' {
    return hasRedisConfig ? 'redis' : 'memory';
  }

  async upsert(record: PresenceRecord): Promise<PresenceRecord[]> {
    const current = await this.readPeerRecords(record.peerId);
    const next = pruneRecords(
      current.filter((item) => item.deviceId !== record.deviceId).concat(record),
    );
    await this.writePeerRecords(record.peerId, next);
    return next;
  }

  async remove(peerId: string, deviceId: string): Promise<void> {
    const current = await this.readPeerRecords(peerId);
    const next = current.filter((item) => item.deviceId !== deviceId);
    await this.writePeerRecords(peerId, next);
  }

  async get(peerId: string): Promise<PresenceRecord[]> {
    const records = pruneRecords(await this.readPeerRecords(peerId));
    await this.writePeerRecords(peerId, records);
    return records;
  }

  async lookup(peerIds: string[]): Promise<Record<string, PresenceRecord[]>> {
    const entries = await Promise.all(
      peerIds.map(async (peerId) => [peerId, await this.get(peerId)] as const),
    );
    return Object.fromEntries(entries);
  }

  private async readPeerRecords(peerId: string): Promise<PresenceRecord[]> {
    if (this.mode === 'redis') {
      const value = await redis!.get<PresenceRecord[]>(peerStorageKey(peerId));
      return Array.isArray(value) ? value : [];
    }

    return this.memory.get(peerId) ?? [];
  }

  private async writePeerRecords(peerId: string, records: PresenceRecord[]): Promise<void> {
    if (this.mode === 'redis') {
      if (records.length === 0) {
        await redis!.del(peerStorageKey(peerId));
        return;
      }

      await redis!.set(peerStorageKey(peerId), records);
      return;
    }

    if (records.length === 0) {
      this.memory.delete(peerId);
      return;
    }

    this.memory.set(peerId, records);
  }
}

export const presenceStore = new PresenceStore();