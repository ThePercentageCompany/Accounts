// Called under the existing workspace business-write lock. Deleted entries still
// reserve their numbers, and existing records retain their original references.
export function assignJournalNumbers(writes, journals) {
  let sequence = Math.max(journals.length, ...journals.map(journal => {
    const match = /^JE(\d+)$/.exec(journal.number || '');
    return match ? Number(match[1]) : 0;
  }));
  const assigned = new Map(journals.map(j => [j.recordId, j.number]));
  for (const write of writes) {
    if (write.table !== 'Journals') continue;
    const id = write.values.recordId;
    if (assigned.has(id)) continue;
    const number = `JE${String(++sequence).padStart(4, '0')}`;
    write.values.number = number;
    assigned.set(id, number);
  }
}
