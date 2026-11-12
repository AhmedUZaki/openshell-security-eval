// Reads one agent session out of a copy of the OpenClaw session database and
// writes what the agent actually did: its tool calls (the exact commands) and
// what each tool returned (output, exit code, error text).
//
// Usage:  node extract-transcript.mjs <database-file> <session-id> <output-prefix>
// Writes: <output-prefix>.txt    readable transcript
//         <output-prefix>.jsonl  the raw events, one JSON object per line
//
// Needs Node 22.5+ (built-in node:sqlite). The database is opened read-only.
// Called by 3-run-attempts.sh; it can also be run by hand on any copy of
// /sandbox/.openclaw/agents/main/agent/openclaw-agent.sqlite (with its -wal
// and -shm files next to it).

import { DatabaseSync } from 'node:sqlite';
import { writeFileSync } from 'node:fs';

const [dbPath, sessionId, outPrefix] = process.argv.slice(2);
if (!dbPath || !sessionId || !outPrefix) {
  console.error('usage: node extract-transcript.mjs <database-file> <session-id> <output-prefix>');
  process.exit(2);
}

const db = new DatabaseSync(dbPath, { readOnly: true });
const rows = db
  .prepare('select seq, event_json from transcript_events where session_id = ? order by seq')
  .all(sessionId);

if (rows.length === 0) {
  console.error(`no events found for session ${sessionId}`);
  process.exit(3);
}

const oneLine = (s) => String(s ?? '').replace(/\r?\n/g, ' ⏎ ');
const time = (iso) => (iso ? String(iso).slice(11, 23) : '            ');

const lines = [];
for (const r of rows) {
  let e;
  try { e = JSON.parse(r.event_json); } catch { lines.push(`[seq ${r.seq}] (unparseable event)`); continue; }
  if (e.type !== 'message' || !e.message) continue;
  const m = e.message;
  const t = time(e.timestamp);
  const hidden = m.display === false ? ' (hidden internal turn)' : '';

  if (m.role === 'user') {
    const text = typeof m.content === 'string' ? m.content : (m.content || []).map((c) => c.text ?? '').join(' ');
    lines.push(`[${t}] USER${hidden}: ${oneLine(text)}`);
  } else if (m.role === 'assistant') {
    for (const c of m.content || []) {
      if (c.type === 'text' && c.text) lines.push(`[${t}] ASSISTANT SAYS${hidden}: ${oneLine(c.text)}`);
      if (c.type === 'toolCall') lines.push(`[${t}] TOOL CALL${hidden}: ${c.name} ${oneLine(JSON.stringify(c.arguments))}`);
    }
  } else if (m.role === 'toolResult') {
    const text = (m.content || []).map((c) => c.text ?? '').join(' ');
    const d = m.details || {};
    const exit = d.exitCode !== undefined ? ` exit=${d.exitCode}` : '';
    lines.push(`[${t}] TOOL RESULT${hidden}: ${m.toolName} error=${m.isError === true}${exit} -> ${oneLine(text)}`);
  }
}

writeFileSync(`${outPrefix}.txt`, `session: ${sessionId}\nevents: ${rows.length}\n\n${lines.join('\n')}\n`);
writeFileSync(`${outPrefix}.jsonl`, rows.map((r) => r.event_json).join('\n') + '\n');
console.log(`wrote ${outPrefix}.txt and ${outPrefix}.jsonl (${rows.length} events, ${lines.length} readable lines)`);
