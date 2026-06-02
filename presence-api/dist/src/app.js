import cors from 'cors';
import express from 'express';
import { presenceStore } from './storage.js';
function normalizeCapabilities(input) {
    const capabilities = (typeof input === 'object' && input !== null ? input : {});
    return {
        historySync: capabilities.historySync ?? true,
        directRelay: capabilities.directRelay ?? true,
    };
}
function normalizeMetadata(input) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        return undefined;
    }
    const entries = Object.entries(input).filter(([, value]) => typeof value === 'string');
    return entries.length > 0 ? Object.fromEntries(entries) : undefined;
}
function isNonEmptyString(value) {
    return typeof value === 'string' && value.trim().length > 0;
}
function createPresenceRecord(body) {
    if (!isNonEmptyString(body.peerId)) {
        throw new Error('peerId is required');
    }
    if (!isNonEmptyString(body.deviceId)) {
        throw new Error('deviceId is required');
    }
    if (!isNonEmptyString(body.address)) {
        throw new Error('address is required');
    }
    const ttlSeconds = typeof body.ttlSeconds === 'number'
        ? Math.max(30, Math.min(body.ttlSeconds, 86400))
        : 120;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);
    return {
        peerId: body.peerId.trim(),
        deviceId: body.deviceId.trim(),
        address: body.address.trim(),
        callbackUrl: isNonEmptyString(body.callbackUrl) ? body.callbackUrl.trim() : undefined,
        lastSeenAt: now.toISOString(),
        expiresAt: expiresAt.toISOString(),
        capabilities: normalizeCapabilities(body.capabilities),
        metadata: normalizeMetadata(body.metadata),
    };
}
function createSignal(body) {
    if (!isNonEmptyString(body.toPeerId)) {
        throw new Error('toPeerId is required');
    }
    if (!isNonEmptyString(body.fromPeerId)) {
        throw new Error('fromPeerId is required');
    }
    if (!isNonEmptyString(body.fromAddress)) {
        throw new Error('fromAddress is required');
    }
    const kind = body.kind === 'history_request' ? 'history_request' : 'availability';
    return {
        toPeerId: body.toPeerId.trim(),
        signal: {
            kind,
            fromPeerId: body.fromPeerId.trim(),
            fromDeviceId: isNonEmptyString(body.fromDeviceId) ? body.fromDeviceId.trim() : undefined,
            fromAddress: body.fromAddress.trim(),
            fromContactKey: isNonEmptyString(body.fromContactKey) ? body.fromContactKey.trim() : undefined,
            note: isNonEmptyString(body.note) ? body.note.trim() : undefined,
            sentAt: new Date().toISOString(),
        },
    };
}
async function forwardSignal(callbackUrl, signal) {
    try {
        const response = await fetch(callbackUrl, {
            method: 'POST',
            headers: {
                'content-type': 'application/json',
            },
            body: JSON.stringify(signal),
        });
        return {
            ok: response.ok,
            status: response.status,
            error: response.ok ? undefined : `Remote endpoint responded with ${response.status}`,
        };
    }
    catch (error) {
        return {
            ok: false,
            error: error instanceof Error ? error.message : 'Unknown relay error',
        };
    }
}
export function createApp() {
    const app = express();
    app.use(cors());
    app.use(express.json({ limit: '1mb' }));
    app.get('/', (_request, response) => {
        response.json({
            service: 'LinkUP Presence API',
            mode: presenceStore.mode,
            purpose: 'Stores live peer rendezvous addresses and relays availability/history-sync signals without storing messages.',
            endpoints: {
                health: 'GET /api/health',
                upsertPresence: 'POST /api/presence/upsert',
                removePresence: 'DELETE /api/presence/:peerId/:deviceId',
                peerStatus: 'GET /api/presence/:peerId',
                bulkLookup: 'POST /api/presence/lookup',
                relaySignal: 'POST /api/notify/direct'
            }
        });
    });
    app.get('/api/health', (_request, response) => {
        response.json({
            ok: true,
            mode: presenceStore.mode,
            timestamp: new Date().toISOString(),
            baseUrl: process.env.PUBLIC_BASE_URL ?? null,
        });
    });
    app.post('/api/presence/upsert', async (request, response) => {
        try {
            const record = createPresenceRecord(request.body);
            const records = await presenceStore.upsert(record);
            response.status(200).json({
                ok: true,
                online: true,
                peerId: record.peerId,
                devices: records,
            });
        }
        catch (error) {
            response.status(400).json({
                ok: false,
                error: error instanceof Error ? error.message : 'Invalid presence payload',
            });
        }
    });
    app.delete('/api/presence/:peerId/:deviceId', async (request, response) => {
        await presenceStore.remove(request.params.peerId, request.params.deviceId);
        response.status(200).json({
            ok: true,
            peerId: request.params.peerId,
            deviceId: request.params.deviceId,
        });
    });
    app.get('/api/presence/:peerId', async (request, response) => {
        const devices = await presenceStore.get(request.params.peerId);
        response.json({
            ok: true,
            peerId: request.params.peerId,
            online: devices.length > 0,
            devices,
        });
    });
    app.post('/api/presence/lookup', async (request, response) => {
        const peerIds = Array.isArray(request.body?.peerIds)
            ? request.body.peerIds
                .filter((value) => isNonEmptyString(value))
                .map((value) => value.trim())
            : [];
        if (peerIds.length === 0) {
            response.status(400).json({ ok: false, error: 'peerIds must be a non-empty string array' });
            return;
        }
        const peers = await presenceStore.lookup(peerIds);
        response.json({ ok: true, peers });
    });
    app.post('/api/notify/direct', async (request, response) => {
        try {
            const { toPeerId, signal } = createSignal(request.body);
            const devices = await presenceStore.get(toPeerId);
            const routableDevices = devices.filter((device) => isNonEmptyString(device.callbackUrl) && device.capabilities.directRelay);
            const deliveries = await Promise.all(routableDevices.map(async (device) => ({
                deviceId: device.deviceId,
                callbackUrl: device.callbackUrl,
                result: await forwardSignal(device.callbackUrl, signal),
            })));
            response.json({
                ok: true,
                toPeerId,
                online: devices.length > 0,
                routed: deliveries.filter((entry) => entry.result.ok).length,
                deliveries,
            });
        }
        catch (error) {
            response.status(400).json({
                ok: false,
                error: error instanceof Error ? error.message : 'Invalid relay request',
            });
        }
    });
    return app;
}
