// Renders Assets/AppIcon.svg → Assets/AppIcon-1024.png (transparent background) using Chromium.
// Usage: node Scripts/render-icon.mjs   (needs the `playwright` package)
import { chromium } from 'playwright';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = process.env.CLIPMANAGER_ROOT ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const svg = await readFile(path.join(root, 'Assets/AppIcon.svg'), 'utf8');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
await page.locator('svg').screenshot({ path: path.join(root, 'Assets/AppIcon-1024.png'), omitBackground: true });
await browser.close();
console.log('✓ Assets/AppIcon-1024.png');
