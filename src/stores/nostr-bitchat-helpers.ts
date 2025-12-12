import { hexToBytes } from "@noble/hashes/utils";

export function normalizePeerId(peerId: string): string {
  const hex = peerId.toLowerCase().replace(/[^0-9a-f]/g, "");
  if (hex.length >= 16) {
    return hex.substring(0, 16);
  }
  return hex.padEnd(16, "0");
}

function toBase64(bytes: Uint8Array): string {
  if (typeof btoa !== "undefined") {
    let binary = "";
    bytes.forEach((b) => (binary += String.fromCharCode(b)));
    return btoa(binary);
  }
  if (typeof Buffer !== "undefined") {
    return Buffer.from(bytes).toString("base64");
  }
  throw new Error("Base64 encoding not available");
}

function fromBase64(input: string): Uint8Array {
  if (typeof atob !== "undefined") {
    const decoded = atob(input);
    const bytes = new Uint8Array(decoded.length);
    for (let i = 0; i < decoded.length; i++) {
      bytes[i] = decoded.charCodeAt(i);
    }
    return bytes;
  }
  if (typeof Buffer !== "undefined") {
    return new Uint8Array(Buffer.from(input, "base64"));
  }
  throw new Error("Base64 decoding not available");
}

export function base64UrlEncode(bytes: Uint8Array): string {
  const b64 = toBase64(bytes);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64UrlDecode(input: string): Uint8Array | null {
  try {
    const padded =
      input.replace(/-/g, "+").replace(/_/g, "/") +
      "=".repeat((4 - (input.length % 4)) % 4);
    return fromBase64(padded);
  } catch (e) {
    console.error("Failed to base64url decode", e);
    return null;
  }
}

export function encodePrivateMessageTLV(
  messageID: string,
  content: string
): Uint8Array | null {
  const msgBytes = new TextEncoder().encode(messageID);
  const contentBytes = new TextEncoder().encode(content);
  if (msgBytes.length > 255 || contentBytes.length > 255) {
    console.warn("BitChat TLV field too large");
    return null;
  }
  const result = new Uint8Array(2 + msgBytes.length + 2 + contentBytes.length);
  let offset = 0;
  result[offset++] = 0x00;
  result[offset++] = msgBytes.length;
  result.set(msgBytes, offset);
  offset += msgBytes.length;
  result[offset++] = 0x01;
  result[offset++] = contentBytes.length;
  result.set(contentBytes, offset);
  return result;
}

export function decodePrivateMessageTLV(
  data: Uint8Array
): { messageID: string; content: string } | null {
  let offset = 0;
  let messageID: string | null = null;
  let content: string | null = null;
  const decoder = new TextDecoder();
  while (offset + 2 <= data.length) {
    const type = data[offset++];
    const len = data[offset++];
    if (offset + len > data.length) return null;
    const value = data.slice(offset, offset + len);
    offset += len;
    if (type === 0x00) {
      messageID = decoder.decode(value);
    } else if (type === 0x01) {
      content = decoder.decode(value);
    }
  }
  if (!messageID || !content) return null;
  return { messageID, content };
}

export function buildBitChatPacket(
  payload: Uint8Array,
  senderPeerIdHex: string,
  recipientPeerIdHex?: string
): string | null {
  try {
    const version = 1;
    const type = 0x11; // NOISE_ENCRYPTED
    const ttl = 7; // match BitChat AppConstants.MESSAGE_TTL_HOPS
    const timestamp = BigInt(Math.floor(Date.now()));
    const hasRecipient = !!recipientPeerIdHex;
    const flags = hasRecipient ? 0x01 : 0x00; // HAS_RECIPIENT

    const payloadLength = payload.length;
    // version(1)+type(1)+ttl(1)+timestamp(8)+flags(1)+payloadLen(2) = 14
    const headerLength = 14;
    const senderBytes = hexToBytes(normalizePeerId(senderPeerIdHex)).slice(
      0,
      8
    );
    const recipientBytes = hasRecipient
      ? hexToBytes(normalizePeerId(recipientPeerIdHex!)).slice(0, 8)
      : new Uint8Array(0);

    const totalLength =
      headerLength + 8 + recipientBytes.length + payloadLength;
    const buffer = new ArrayBuffer(totalLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset++, version);
    view.setUint8(offset++, type);
    view.setUint8(offset++, ttl);
    // timestamp 8 bytes big-endian
    view.setBigUint64(offset, timestamp);
    offset += 8;
    view.setUint8(offset++, flags);
    view.setUint16(offset, payloadLength, false);
    offset += 2;
    new Uint8Array(buffer, offset, 8).set(senderBytes);
    offset += 8;
    if (hasRecipient) {
      new Uint8Array(buffer, offset, 8).set(recipientBytes);
      offset += 8;
    }
    new Uint8Array(buffer, offset, payloadLength).set(payload);

    const bytes = new Uint8Array(buffer);
    return "bitchat1:" + base64UrlEncode(bytes);
  } catch (e) {
    console.error("Failed to build BitChat packet", e);
    return null;
  }
}

export function parseBitChatPacket(encoded: string): string | null {
  if (!encoded.startsWith("bitchat1:")) return null;
  const b64 = encoded.replace("bitchat1:", "");
  const data = base64UrlDecode(b64);
  if (!data || data.length < 13 + 8) return null;
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  let offset = 0;
  const version = view.getUint8(offset++);
  const type = view.getUint8(offset++);
  const ttl = view.getUint8(offset++);
  offset += 8; // timestamp
  const flags = view.getUint8(offset++);
  const payloadLen = view.getUint16(offset, false);
  offset += 2;
  offset += 8; // sender
  const hasRecipient = (flags & 0x01) === 0x01;
  if (hasRecipient) offset += 8;
  if (type !== 0x11 || version === 0 || data.length < offset + payloadLen)
    return null;
  const payload = data.slice(offset, offset + payloadLen);
  if (payload.length === 0) return null;
  const payloadType = payload[0];
  const payloadBody = payload.slice(1);
  if (payloadType === 0x01) {
    const pm = decodePrivateMessageTLV(payloadBody);
    return pm?.content ?? null;
  }
  // Ignore ACK/file types for now
  return null;
}
