# Financial reports

Supabase Edge Functions derive dashboard, ledger, trial balance, profit and loss, and balance sheet reports from posted company journals. Admins save versioned settings; employee reports require the company-wide Reports grant. Source records, balanced journals and retry markers commit in one Postgres transaction. Saved exchange rates determine accounting-currency values. Realtime changes invalidate cached reports.
