// PRIVACY POLICY: Only derived metadata stored. No raw values.

export interface ComponentDiscovery {
  type: string
  tech: string
  source: string
  variable_name?: string
}

export interface ConnectionMetadata {
  host?:   string | null
  url?:    string | null
  dbName?: string | null
}

// Suppress discovery emission when the SDK is detecting NurseAndrea's
// own infrastructure. Match the connection's host / url / database
// name against a small list of self-identifiers. Customer apps don't
// typically embed any of these strings.
const SELF_INDICATORS = ["nurseandrea", "nurse-andrea", "nurse_andrea"]

export function selfReferential(meta?: ConnectionMetadata | null): boolean {
  if (!meta) return false
  const haystack: string[] = []
  if (meta.host)   haystack.push(String(meta.host).toLowerCase())
  if (meta.url)    haystack.push(String(meta.url).toLowerCase())
  if (meta.dbName) haystack.push(String(meta.dbName).toLowerCase())
  if (haystack.length === 0) return false
  return SELF_INDICATORS.some(ind => haystack.some(h => h.includes(ind)))
}

const _discoveries: ComponentDiscovery[] = []
const _seen = new Set<string>()

export function registerDiscovery(
  d: Omit<ComponentDiscovery, "variable_name"> & { variable_name?: string },
  metadata?: ConnectionMetadata | null,
): void {
  if (selfReferential(metadata)) return

  const key = `${d.type}:${d.tech}`
  if (_seen.has(key)) return
  _seen.add(key)
  _discoveries.push({
    type: d.type,
    tech: d.tech,
    source: d.source,
    ...(d.variable_name ? { variable_name: d.variable_name } : {}),
  })
}

export function discoveries(): readonly ComponentDiscovery[] {
  return _discoveries
}

export function flushDiscoveries(): ComponentDiscovery[] {
  const copy = [..._discoveries]
  _discoveries.length = 0
  return copy
}

export function clearDiscoveries(): void {
  _discoveries.length = 0
  _seen.clear()
}
