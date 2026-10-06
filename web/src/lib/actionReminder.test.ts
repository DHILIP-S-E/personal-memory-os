import { describe, expect, it } from 'vitest';
import { actionTitle, dueMorning, reminderFromAction } from './actionReminder';

describe('dueMorning', () => {
  it('is 9:00 on the stated day in local time, whatever the timezone', () => {
    const d = dueMorning('2026-10-20')!;
    expect([d.getFullYear(), d.getMonth(), d.getDate(), d.getHours()]).toEqual([2026, 9, 20, 9]);
  });

  it('is null without a usable date', () => {
    for (const v of [null, undefined, '', 'next friday', '20-10-2026']) expect(dueMorning(v)).toBeNull();
  });
});

describe('reminderFromAction', () => {
  it('turns { title, due_at } into a timed reminder in the given timezone', () => {
    const r = reminderFromAction({ title: 'Submit the prototype', due_at: '2026-10-20' }, 'Asia/Kolkata')!;
    expect(r.title).toBe('Submit the prototype');
    expect(r.timezone).toBe('Asia/Kolkata');
    expect(new Date(r.scheduled_at!).getHours()).toBe(9);
  });

  it('keeps an action without a date as an untimed reminder, never inventing one', () => {
    const r = reminderFromAction({ title: 'Call the vendor', due_at: null }, 'UTC')!;
    expect(r.scheduled_at).toBeNull();
  });

  it('accepts a plain string action', () => {
    expect(reminderFromAction('Send the invoice', 'UTC')!.title).toBe('Send the invoice');
  });

  it('refuses an action with no title, and caps a very long one', () => {
    expect(reminderFromAction({ title: '  ', due_at: '2026-10-20' }, 'UTC')).toBeNull();
    expect(reminderFromAction('x'.repeat(900), 'UTC')!.title).toHaveLength(500);
    expect(actionTitle({ title: null })).toBe('');
  });
});
