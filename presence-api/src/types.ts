export interface PresenceCapabilities {
  historySync: boolean;
  directRelay: boolean;
}

export interface PresenceRecord {
  peerId: string;
  deviceId: string;
  address: string;
  callbackUrl?: string;
  lastSeenAt: string;
  expiresAt: string;
  capabilities: PresenceCapabilities;
  metadata?: Record<string, string>;
}

export interface AvailabilitySignal {
  kind: 'availability' | 'history_request';
  fromPeerId: string;
  fromDeviceId?: string;
  fromAddress: string;
  fromContactKey?: string;
  note?: string;
  sentAt: string;
}