// Pure validation/money functions; also exercised by Node tests.
function requireValue_(ok, message) { if (!ok) throw new Error(message); }
function scaled_(value, decimals) {
  const s = String(value).trim();
  requireValue_(new RegExp('^\\d+(\\.\\d{1,' + decimals + '})?$').test(s), 'Invalid decimal number');
  const p = s.split('.');
  const n = Number(p[0]) * Math.pow(10, decimals) + Number((p[1] || '').padEnd(decimals, '0'));
  requireValue_(Number.isSafeInteger(n) && n <= (decimals === 3 ? 1000000 : 100000000), 'Number too large');
  return n;
}
function totals_(i) {
  requireValue_(Array.isArray(i.items) && i.items.length > 0 && i.items.length <= 30, 'Add 1 to 30 items');
  const subtotal = i.items.reduce((sum, item) => {
    textField_(item.description, 500, true);
    const qty = scaled_(item.quantity, 3);
    requireValue_(qty > 0, 'Quantity must be greater than zero');
    return sum + Math.floor((qty * scaled_(item.rate, 2) + 500) / 1000);
  }, 0);
  requireValue_(subtotal<=1000000000,'Invoice total exceeds AED 10 million');
  const discount = scaled_(i.discount, 2), rate = scaled_(i.taxRate, 2);
  requireValue_(discount <= subtotal && rate <= 10000, 'Invalid discount or tax');
  const tax = Math.floor(((subtotal-discount)*rate+5000)/10000);
  const total = subtotal-discount+tax;
  const paid = (i.payments || []).reduce((sum,p) => {
    requireValue_(Number.isSafeInteger(p.cents) && p.cents > 0, 'Invalid payment');
    return sum+p.cents;
  },0);
  requireValue_(paid <= total, 'Payment exceeds balance');
  return {subtotal,discount,tax,total,paid,balance:total-paid};
}
function textField_(v, max, required) {
  requireValue_(typeof v === 'string' && v.length <= max && (!required || v.trim().length > 0), 'Missing or overlong text');
  return v.trim();
}
function validId_(id) { requireValue_(typeof id === 'string' && /^[a-zA-Z0-9_-]{1,80}$/.test(id), 'Invalid ID'); return id; }
function dateField_(date) {
  requireValue_(typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date), 'Use YYYY-MM-DD');
  requireValue_(new Date(date+'T00:00:00Z').toISOString().slice(0,10) === date, 'Invalid date'); return date;
}
function customerValue_(d) {
  return {id:validId_(d.id), name:textField_(d.name,200,true), email:textField_(d.email,200),phone:textField_(d.phone,80),address:textField_(d.address,600),trn:textField_(d.trn,80),version:d.version || 0};
}
function companyValue_(d) {
  const result={};
  for(const key of ['name','address','phone','email','trn','prefix','accountHolder','bank','accountNumber','iban','notes','terms']) {
    result[key]=textField_(d[key], key === 'notes' ? 1000 : 600, key==='name'||key==='prefix');
  }
  requireValue_(/^[A-Z0-9]{1,12}$/.test(result.prefix),'Prefix must be 1-12 uppercase letters or digits');
  result.logo=textField_(d.logo,2000000);
  if(result.logo) requireValue_(/^[A-Za-z0-9+/]+={0,2}$/.test(result.logo),'Invalid logo data');
  result.version=d.version || 0;
  return result;
}
function checkVersion_(current, expected) {
  requireValue_((current ? current.version : 0) === expected, 'Record changed on another device. Refresh and try again.');
}
function invoiceNumber_(prefix, year, sequence) { return prefix+'-'+year+'-'+String(sequence).padStart(6,'0'); }
