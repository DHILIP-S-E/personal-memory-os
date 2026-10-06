import { AxiosError } from 'axios';
import { describe, expect, it } from 'vitest';
import { apiErrorMessage } from './apiError';

function failure(status: number | null, data?: unknown): AxiosError {
  const response = status === null ? undefined : ({ status, data } as never);
  return new AxiosError('Request failed', 'ERR_BAD_REQUEST', undefined, undefined, response);
}

describe('apiErrorMessage', () => {
  it('says the server cannot be reached when there was no response', () => {
    expect(apiErrorMessage(failure(null))).toMatch(/Can't reach the server/);
  });

  it("uses the backend's own explanation", () => {
    expect(apiErrorMessage(failure(400, { detail: 'Invalid email or password' }))).toBe('Invalid email or password');
  });

  it('reads the first pydantic validation message and drops the "Value error" prefix', () => {
    const data = { detail: [{ msg: 'Value error, Title cannot be empty', loc: ['body', 'title'] }] };
    expect(apiErrorMessage(failure(422, data))).toBe('Title cannot be empty');
  });

  it('maps statuses without a detail to something actionable', () => {
    expect(apiErrorMessage(failure(401, {}))).toMatch(/sign in again/);
    expect(apiErrorMessage(failure(500, {}))).toMatch(/server had a problem/);
    expect(apiErrorMessage(failure(404, {}), 'Not found.')).toBe('Not found.');
  });

  it('never leaks axios text or a stack for unknown values', () => {
    expect(apiErrorMessage('boom')).toBe('Something went wrong. Please try again.');
    expect(apiErrorMessage(null, 'Custom')).toBe('Custom');
    expect(apiErrorMessage(new Error('x'.repeat(300)))).toBe('Something went wrong. Please try again.');
  });
});
