import test from 'node:test';
import assert from 'node:assert/strict';
import {assignJournalNumbers} from '../src/journal-number.js';
test('journal numbers cover automatic postings and manual drafts without recycling references', () => {
  const journals = [{recordId:'old',number:'AUTO-old'},
    {recordId:'deleted',number:'JE0012',isDeleted:true}];
  const writes = [
    {table:'Journals',values:{recordId:'draft',number:'user-input'}},
    {table:'JournalLines',values:{recordId:'line'}},
    {table:'Journals',values:{recordId:'generated',number:'AUTO-generated'}},
    {table:'Journals',values:{recordId:'old',number:'AUTO-old'}}];
  assignJournalNumbers(writes,journals);
  assert.equal(writes[0].values.number,'JE0013');
  assert.equal(writes[2].values.number,'JE0014');
  assert.equal(writes[3].values.number,'AUTO-old');
  const fresh = [{table:'Journals',values:{recordId:'first'}}];
  assignJournalNumbers(fresh,[]);
  assert.equal(fresh[0].values.number,'JE0001');
});
