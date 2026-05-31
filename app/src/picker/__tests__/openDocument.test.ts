/**
 * Tests for the document picker wrapper. The native picker is mocked at the
 * jest setup level; this file replaces the mock per-scenario.
 */

import { errorCodes, pick } from '@react-native-documents/picker';
import { openDocumentFromPicker } from '../openDocument';

describe('openDocumentFromPicker', () => {
  beforeEach(() => {
    (pick as jest.Mock).mockReset();
  });

  test('returns null when the user cancels the picker', async () => {
    const cancelError = Object.assign(new Error('cancelled'), {
      code: errorCodes.OPERATION_CANCELED,
    });
    (pick as jest.Mock).mockRejectedValueOnce(cancelError);

    expect(await openDocumentFromPicker()).toBeNull();
  });

  test('returns null when the picker returns no results', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([]);
    expect(await openDocumentFromPicker()).toBeNull();
  });

  test('returns the file contents on the happy path', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/doc.scabopdf.json', name: 'doc.scabopdf.json' },
    ]);
    const fetchSpy = jest
      .spyOn(global, 'fetch')
      // The text() method on the fake response returns a JSON string.
      .mockResolvedValueOnce({
        text: () => Promise.resolve('{"schema_version":"0.7.0"}'),
      } as unknown as Response);

    const picked = await openDocumentFromPicker();
    expect(picked).not.toBeNull();
    expect(picked?.name).toBe('doc.scabopdf.json');
    expect(picked?.content).toBe('{"schema_version":"0.7.0"}');
    expect(fetchSpy).toHaveBeenCalledWith('file:///tmp/doc.scabopdf.json');

    fetchSpy.mockRestore();
  });

  test('re-throws a non-cancel picker error', async () => {
    (pick as jest.Mock).mockRejectedValueOnce(
      Object.assign(new Error('io failure'), { code: 'IO_ERROR' }),
    );
    await expect(openDocumentFromPicker()).rejects.toThrow('io failure');
  });

  test('falls back to a default name when the picker omits one', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/x.json', name: undefined },
    ]);
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
      text: () => Promise.resolve('{}'),
    } as unknown as Response);

    const picked = await openDocumentFromPicker();
    expect(picked?.name).toBe('documento.scabopdf.json');

    fetchSpy.mockRestore();
  });

  test('routes a .scabopdf.json to the JSON path with its content', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/doc.scabopdf.json', name: 'doc.scabopdf.json' },
    ]);
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValueOnce({
      text: () => Promise.resolve('{"schema_version":"0.7.0"}'),
    } as unknown as Response);

    const picked = await openDocumentFromPicker();
    expect(picked?.kind).toBe('scabopdf');
    expect(picked?.content).toBe('{"schema_version":"0.7.0"}');

    fetchSpy.mockRestore();
  });

  test('detects a PDF by extension and does not read its text', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/Manuale.pdf', name: 'Manuale.pdf' },
    ]);
    const fetchSpy = jest.spyOn(global, 'fetch');

    const picked = await openDocumentFromPicker();
    expect(picked?.kind).toBe('pdf');
    expect(picked?.uri).toBe('file:///tmp/Manuale.pdf');
    expect(picked?.content).toBeNull();
    // The PDF is read natively from the URI, never via fetch().
    expect(fetchSpy).not.toHaveBeenCalled();

    fetchSpy.mockRestore();
  });

  test('detects a PDF by MIME type when the name has no .pdf suffix', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/scan', name: 'scan', type: 'application/pdf' },
    ]);
    const picked = await openDocumentFromPicker();
    expect(picked?.kind).toBe('pdf');
    expect(picked?.content).toBeNull();
  });
});
