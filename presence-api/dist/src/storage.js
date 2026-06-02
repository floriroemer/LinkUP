import { Redis } from '@upstash/redis';
const hasRedisConfig = Boolean(process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN);
const redis = hasRedisConfig ? Redis.fromEnv() : null;
function peerStorageKey(peerId) {
    return `presence:peer:${peerId}`;
}
function pruneRecords(records) {
    const now = Date.now();
    return records.filter((record) => Date.parse(record.expiresAt) > now);
}
export class PresenceStore {
    memory = new Map();
    get mode() {
        return hasRedisConfig ? 'redis' : 'memory';
    }
    async upsert(record) {
        const current = await this.readPeerRecords(record.peerId);
        const next = pruneRecords(current.filter((item) => item.deviceId !== record.deviceId).concat(record));
        await this.writePeerRecords(record.peerId, next);
        return next;
    }
    async remove(peerId, deviceId) {
        const current = await this.readPeerRecords(peerId);
        const next = current.filter((item) => item.deviceId !== deviceId);
        await this.writePeerRecords(peerId, next);
    }
    async get(peerId) {
        const records = pruneRecords(await this.readPeerRecords(peerId));
        await this.writePeerRecords(peerId, records);
        return records;
    }
    async lookup(peerIds) {
        const entries = await Promise.all(peerIds.map(async (peerId) => [peerId, await this.get(peerId)]));
        return Object.fromEntries(entries);
    }
    async readPeerRecords(peerId) {
        if (this.mode === 'redis') {
            const value = await redis.get(peerStorageKey(peerId));
            return Array.isArray(value) ? value : [];
        }
        return this.memory.get(peerId) ?? [];
    }
    async writePeerRecords(peerId, records) {
        if (this.mode === 'redis') {
            if (records.length === 0) {
                await redis.del(peerStorageKey(peerId));
                return;
            }
            await redis.set(peerStorageKey(peerId), records);
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
