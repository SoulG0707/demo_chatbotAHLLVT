import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const sourcePath = resolve(root, "src", "index.html")
const outputDir = resolve(root, "public")
const outputPath = resolve(outputDir, "index.html")

const apiBaseUrl = process.env.API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || ""
const escapedApiBaseUrl = apiBaseUrl.replaceAll("\\", "\\\\").replaceAll('"', '\\"')
const html = readFileSync(sourcePath, "utf8").replaceAll("__API_BASE_URL__", escapedApiBaseUrl)

mkdirSync(outputDir, { recursive: true })
writeFileSync(outputPath, html, "utf8")

console.log(`Built ${outputPath}`)
if (apiBaseUrl) {
  console.log(`API_BASE_URL=${apiBaseUrl}`)
} else {
  console.log("API_BASE_URL is empty; frontend will call same-origin /api endpoints.")
}
