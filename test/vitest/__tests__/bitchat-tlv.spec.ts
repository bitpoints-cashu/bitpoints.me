import { describe, expect, it } from "vitest";
import {
  encodePrivateMessageTLV,
  decodePrivateMessageTLV,
  buildBitChatPacket,
  parseBitChatPacket,
} from "src/stores/nostr-bitchat-helpers";

describe("BitChat TLV and packet helpers", () => {
  it("encodes and decodes PrivateMessage TLV roundtrip", () => {
    const tlv = encodePrivateMessageTLV("msg123", "hello world");
    expect(tlv).toBeInstanceOf(Uint8Array);
    const decoded = decodePrivateMessageTLV(tlv as Uint8Array);
    expect(decoded?.messageID).toBe("msg123");
    expect(decoded?.content).toBe("hello world");
  });

  it("builds and parses bitchat1 packet roundtrip", () => {
    const tlv = encodePrivateMessageTLV("msg123", "hello world");
    const payload = new Uint8Array(1 + (tlv as Uint8Array).length);
    payload[0] = 0x01; // NoisePayloadType.PRIVATE_MESSAGE
    payload.set(tlv as Uint8Array, 1);

    const packet = buildBitChatPacket(
      payload,
      "0011223344556677",
      "8899aabbccddeeff"
    );

    expect(packet).toBeTruthy();
    expect(packet as string).toMatch(/^bitchat1:/);
    const parsed = parseBitChatPacket(packet as string);
    expect(parsed).toBe("hello world");
  });
});
