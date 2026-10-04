# Custom invoice and quotation HTML designs

Open an invoice or quotation's **Record documents** dialog. Use the code icon:

- **Edit HTML design** edits HTML/CSS, imports an HTML file, resets the editor source, previews using the saved record, exports the source, and saves the design.
- **Export custom HTML** downloads the current record populated into the saved design. Open this file in a browser and use Print / Save as PDF.

Designs are stored on the current browser/device, scoped by API origin, workspace ID and document type. They are not cloud-synchronized. Export the source as a backup; import it to another browser. Closing without saving leaves the stored design unchanged. Reset source also requires Save design to replace the stored design.

Supported placeholders are `{{title}}`, `{{endDate}}`, `{{items}}`, and `{{company.FIELD}}`, `{{customer.FIELD}}`, `{{record.FIELD}}` for actual saved fields. Missing fields render empty. `{{items}}` emits table rows for description, quantity, unit price, discount, VAT percentage and saved line total. Include it inside a table body. `{{items}}` and `{{record.total}}` are required. Source is limited to 100 KB.

Exports load current saved records and totals from the authorized API, with invoice/quotation and company version checks. Text values are HTML escaped. Inline CSS and data-embedded images/fonts are supported. The exported document includes a content security policy restricting scripts, external resources, forms and embedded pages. Templates are never rendered in the authenticated application.

This is an owner document export option. It does not modify issued invoices, accounting entries, stored attachments or the existing invoice_kit PDF templates. Custom HTML PDFs are produced through browser printing; **Create and attach PDF** continues to generate the existing Modern/Classic PDF. This feature currently uses the web download mechanism.
