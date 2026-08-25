import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
export const theme = readFileSync(resolve(skillRoot, "assets", "theme.css"), "utf8");

export function embeddedJson(value) {
  return JSON.stringify(value)
    .replaceAll("&", "\\u0026")
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
}

export function replaceOnce(template, marker, value) {
  const parts = template.split(marker);
  if (parts.length !== 2) throw new Error(`template must contain exactly one ${marker}`);
  return `${parts[0]}${value}${parts[1]}`;
}

export function renderPage(path, template, replacements) {
  let document = replaceOnce(template, "__REVIEW_CHANGE_THEME__", theme);
  for (const [marker, value] of Object.entries(replacements)) document = replaceOnce(document, marker, value);
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${randomUUID()}.tmp`;
  writeFileSync(temporary, document);
  renameSync(temporary, path);
  return path;
}
