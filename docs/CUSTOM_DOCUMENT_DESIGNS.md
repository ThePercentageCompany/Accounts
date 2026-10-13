# Invoice and quotation HTML designs

Admins save company HTML designs online in Settings. Authorized employees and later sessions use the same source. No local fallback or Modern/Classic selector remains.

Print / Save PDF renders saved record values in the HTML. Upload the resulting PDF to private Supabase Storage.

Placeholders: `{{title}}`, `{{endDate}}`, `{{items}}`, `{{company.FIELD}}`, `{{customer.FIELD}}`, `{{record.FIELD}}`. Include `{{items}}` in a table body and `{{record.total}}`. Source is limited to 100 KB. Values are escaped; a content security policy blocks scripts and external resources.
