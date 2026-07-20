import { describe, expect, test } from 'bun:test';
import {
  CLIPBOARD_MESSAGE_PREFIX,
  createOsc52Parser,
  encodeClipboardMessage,
} from '../demo/bin/osc52.js';

describe('demo OSC 52 parser', () => {
  test('decodes BEL-terminated clipboard writes', () => {
    const events: Array<{ selection: string; text: string }> = [];
    const parser = createOsc52Parser((event: { selection: string; text: string }) => {
      events.push(event);
    });

    parser.push('before\x1b]52;c;aGVsbG8gd29ybGQ=\x07after');

    expect(events).toEqual([{ selection: 'c', text: 'hello world' }]);
  });

  test('handles sequences split across PTY chunks', () => {
    const events: Array<{ selection: string; text: string }> = [];
    const parser = createOsc52Parser((event: { selection: string; text: string }) => {
      events.push(event);
    });

    parser.push('text\x1b]5');
    parser.push('2;c;c3BsaXQ=\x1b');
    parser.push('\\tail');

    expect(events).toEqual([{ selection: 'c', text: 'split' }]);
  });

  test('ignores clipboard read requests and invalid payloads', () => {
    const events: Array<{ selection: string; text: string }> = [];
    const parser = createOsc52Parser((event: { selection: string; text: string }) => {
      events.push(event);
    });

    parser.push('\x1b]52;c;?\x07\x1b]52;c;not base64!\x07');

    expect(events).toEqual([]);
  });
});

describe('demo clipboard control message', () => {
  test('encodes text for the browser without losing Unicode', () => {
    const message = encodeClipboardMessage('remote 👻 clipboard');

    expect(message.startsWith(CLIPBOARD_MESSAGE_PREFIX)).toBe(true);
    expect(JSON.parse(message.slice(CLIPBOARD_MESSAGE_PREFIX.length))).toBe('remote 👻 clipboard');
  });
});
