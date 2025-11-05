/**
 * Generate a default username with format "anonXXXX" where XXXX are random alphanumeric characters
 */
export function generateDefaultUsername(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const randomPart = Array.from(
    { length: 4 },
    () => chars[Math.floor(Math.random() * chars.length)]
  ).join("");
  return `anon${randomPart}`;
}
