//
//  SplitChainAnchorTests.swift
//  ScaboCoreTests
//
//  Le annotazioni attraverso il FRAZIONAMENTO delle note lunghe (giro «costruzione della linea Mac», 2026-10-16,
//  revisione indipendente). La lettura preparata dal Mac divide le note lunghe in più segmenti consecutivi (il primo
//  NOTE, gli altri NOTE_CONTINUATION, `fractionLongNoteSegments`); dalla build 55 anche l'iPad, quando elabora da sé
//  (il ritorno a note intere resta quello verso una lettura precedente). Andata: le
//  annotazioni fatte sulla nota intera si ritrovano nei pezzi (anche a cavallo di due pezzi). Ritorno: quelle fatte sui
//  pezzi si ritrovano nella nota intera (anche i pezzi di mezzo). Prove al contrario: nessuna ricollocazione su un testo
//  diverso. Testi SINTETICI e neutri: nessun frammento di volume.
//

import XCTest
@testable import ScaboCore

final class SplitChainAnchorTests: XCTestCase {

    private func seg(_ id: String, _ text: String, role: String = "BODY", page: Int? = 3) -> ContentSegment {
        ContentSegment(id: id, role: role, text: text, lengthCategory: "", acousticIntro: "", sourcePage: page)
    }

    /// Una nota lunga: una frase breve in testa (il primo pezzo sarà corto) e frasi lunghe e distinte dopo.
    private let longNote = "(7) Si veda oltre. " + (1...14).map { i in
        "La frase numero \(i) della nota descrive con calma il paesaggio numero \(i) della valle, il ponte di pietra "
            + "numero \(i) e il sentiero che sale al rifugio numero \(i) passando per il bosco di castagni."
    }.joined(separator: " ")

    private func ipadFlow(note: String? = nil) -> [ContentSegment] {
        [
            seg("node_0", "Il paragrafo che precede la nota racconta il mercato del paese, le bancarelle e le voci dei venditori al mattino."),
            seg("node_1", note ?? longNote, role: "NOTE"),
            seg("node_2", "Il paragrafo che segue la nota parla della sera, dei lumi accesi alle finestre e del silenzio della piazza."),
        ]
    }

    /// La stessa lettura con la nota frazionata come la prepara il Mac.
    private func macFlow(note: String? = nil) -> [ContentSegment] {
        fractionLongNoteSegments(ipadFlow(note: note), target: 400)
    }

    private func wordCount(_ s: ContentSegment) -> Int { WordTokenizer.words(s.text).count }

    // MARK: - Andata (nota intera → pezzi)

    func test_laNotaVieneDavveroDivisa_inPiuPezzi_conIlPrimoCorto() {
        let mac = macFlow()
        let pieces = mac.filter { $0.role == "NOTE" || $0.role == "NOTE_CONTINUATION" }
        XCTAssertGreaterThanOrEqual(pieces.count, 3)
        XCTAssertEqual(pieces.first?.role, "NOTE")
        XCTAssertTrue(pieces.dropFirst().allSatisfy { $0.role == "NOTE_CONTINUATION" })
    }

    func test_andata_segnalibroSullaNota_vaSulPrimoPezzo_esatto() throws {
        let a = try XCTUnwrap(ContentAnchorIndex(segments: ipadFlow()).anchor(forIndex: 1))
        let mac = macFlow()
        let r = ContentAnchorIndex(segments: mac).resolve(a)
        XCTAssertEqual(r.level, .exact)
        XCTAssertEqual(r.index.map { mac[$0].role }, "NOTE")
        XCTAssertEqual(r.index, 1)
    }

    func test_andata_citazioneInUnPezzoLontano_siRitrova_nelPezzoGiusto() throws {
        let ipad = ContentAnchorIndex(segments: ipadFlow())
        let n = wordCount(ipadFlow()[1])
        let q = try XCTUnwrap(ipad.quoteAnchor(forIndex: 1, startWord: n - 6, endWord: n - 4))
        let mac = macFlow()
        let index = ContentAnchorIndex(segments: mac)
        let r = try XCTUnwrap(index.resolve(q), "una citazione dentro un solo pezzo torna in uno span")
        XCTAssertEqual(mac[r.segmentIndex].role, "NOTE_CONTINUATION")
        // Le parole ritrovate sono proprio quelle (stesse lettere normalizzate).
        let found = WordTokenizer.words(mac[r.segmentIndex].text)[r.startWord...r.endWord].joined(separator: " ")
        let wanted = WordTokenizer.words(ipadFlow()[1].text)[(n - 6)...(n - 4)].joined(separator: " ")
        XCTAssertEqual(TextFingerprint.normalize(found), TextFingerprint.normalize(wanted))
    }

    func test_andata_citazioneACavalloDiDuePezzi_diventaDueSpan() throws {
        let ipadSegs = ipadFlow()
        let mac = macFlow()
        let first = try XCTUnwrap(mac.first { $0.role == "NOTE" })
        let k = wordCount(first)   // la prima parola del secondo pezzo, nella nota intera, ha indice k
        let ipad = ContentAnchorIndex(segments: ipadSegs)
        let q = try XCTUnwrap(ipad.quoteAnchor(forIndex: 1, startWord: k - 2, endWord: k + 1))
        let index = ContentAnchorIndex(segments: mac)
        XCTAssertNil(index.resolve(q), "uno span solo non basta: resolve dice nil, resolveSpans li dà tutti")
        let spans = try XCTUnwrap(index.resolveSpans(q))
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(mac[spans[0].segmentIndex].role, "NOTE")
        XCTAssertEqual(spans[0].endWord, k - 1)
        XCTAssertEqual(spans[1].startWord, 0)
        XCTAssertEqual(spans[1].endWord, 1)
        // Nel riancoraggio la sottolineatura diventa di due span, ognuno con la sua ancora, e non è orfana.
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "node_1", startWord: k - 2, endWord: k + 1, anchor: q)],
                          preview: "", createdAt: Date())
        let out = AnnotationReanchoring.reanchor(bookmarks: [], underlines: [u], readingPosition: 0, readingAnchor: nil, in: index)
        XCTAssertNil(out.underlines[0].isOrphan)
        XCTAssertEqual(out.underlines[0].spans.count, 2)
        XCTAssertEqual(out.underlines[0].spans.map { $0.segmentId }, [mac[spans[0].segmentIndex].id, mac[spans[1].segmentIndex].id])
        XCTAssertTrue(out.underlines[0].spans.allSatisfy { $0.anchor != nil })
    }

    func test_andata_gemelli_siDistinguonoPerRango() throws {
        // Due note identiche sulla stessa pagina (i codici ripetono le note alla lettera): il rango decide.
        let twin = ipadFlow()[1].text
        let ipad = [ipadFlow()[0], seg("node_1", twin, role: "NOTE"), seg("node_x", "Un paragrafo in mezzo alle due note gemelle della pagina, con il racconto del fiume.", page: 3),
                    seg("node_2", twin, role: "NOTE")]
        let ipadIndex = ContentAnchorIndex(segments: ipad)
        let second = try XCTUnwrap(ipadIndex.anchor(forIndex: 3))
        XCTAssertEqual(second.windowCount, 2)
        let mac = fractionLongNoteSegments(ipad, target: 400)
        let r = ContentAnchorIndex(segments: mac).resolve(second)
        XCTAssertEqual(r.level, .exact)
        let secondStart = try XCTUnwrap(mac.firstIndex { $0.id == "node_2#0" })
        XCTAssertEqual(r.index, secondStart, "il secondo gemello, non il primo")
        // Sparito un gemello, il superstite potrebbe essere l'altro: orfana.
        let one = fractionLongNoteSegments(Array(ipad.prefix(3)), target: 400)
        XCTAssertEqual(ContentAnchorIndex(segments: one).resolve(second).level, .orphan)
    }

    // MARK: - Prove al contrario (andata)

    func test_alContrario_unaNotaDiversaConLaStessaTesta_nonVieneMaiPresaPerEsatta() throws {
        let a = try XCTUnwrap(ContentAnchorIndex(segments: ipadFlow()).anchor(forIndex: 1))
        // Stessa testa, una frase in fondo diversa: i pezzi NON ricompongono il vecchio testo.
        let altered = longNote.replacingOccurrences(of: "numero 14 passando per il bosco di castagni",
                                                    with: "numero 14 lungo la riva del torrente gelato")
        let r = ContentAnchorIndex(segments: macFlow(note: altered)).resolve(a)
        XCTAssertNotEqual(r.level, .exact)
        XCTAssertNotEqual(r.level, .contained)
    }

    func test_alContrario_citazioneSparita_restaOrfana_eLaSottolineaturaLoDice() throws {
        let ipad = ContentAnchorIndex(segments: ipadFlow())
        let n = wordCount(ipadFlow()[1])
        let q = try XCTUnwrap(ipad.quoteAnchor(forIndex: 1, startWord: n - 3, endWord: n - 1))
        let altered = longNote.replacingOccurrences(of: "il bosco di castagni.", with: "la vecchia segheria.")
        let index = ContentAnchorIndex(segments: macFlow(note: altered))
        XCTAssertNil(index.resolveSpans(q))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: "node_1", startWord: n - 3, endWord: n - 1, anchor: q)],
                          preview: "", createdAt: Date())
        let out = AnnotationReanchoring.reanchor(bookmarks: [], underlines: [u], readingPosition: 0, readingAnchor: nil, in: index)
        XCTAssertEqual(out.underlines[0].isOrphan, true)
    }

    // MARK: - Ritorno (pezzi → nota intera)

    func test_ritorno_segnalibroSuUnPezzoDiMezzo_siRitrovaNellaNotaIntera() throws {
        let mac = macFlow()
        let macIndex = ContentAnchorIndex(segments: mac)
        let middle = try XCTUnwrap(mac.indices.filter { mac[$0].role == "NOTE_CONTINUATION" }.dropLast().first)
        let a = try XCTUnwrap(macIndex.anchor(forIndex: middle))
        let r = ContentAnchorIndex(segments: ipadFlow()).resolve(a)
        XCTAssertEqual(r.level, .contained)
        XCTAssertEqual(r.index, 1)
    }

    func test_ritorno_sottolineaturaACavalloDiDuePezzi_tornaUnoSpanSolo() throws {
        let mac = macFlow()
        let macIndex = ContentAnchorIndex(segments: mac)
        let pieces = mac.indices.filter { mac[$0].role == "NOTE" || mac[$0].role == "NOTE_CONTINUATION" }
        let p0 = pieces[1], p1 = pieces[2]
        let n0 = wordCount(mac[p0])
        let q0 = try XCTUnwrap(macIndex.quoteAnchor(forIndex: p0, startWord: n0 - 2, endWord: n0 - 1))
        let q1 = try XCTUnwrap(macIndex.quoteAnchor(forIndex: p1, startWord: 0, endWord: 1))
        let u = Underline(id: "u", spans: [UnderlineSpan(segmentId: mac[p0].id, startWord: n0 - 2, endWord: n0 - 1, anchor: q0),
                                           UnderlineSpan(segmentId: mac[p1].id, startWord: 0, endWord: 1, anchor: q1)],
                          preview: "", createdAt: Date())
        let ipad = ipadFlow()
        let out = AnnotationReanchoring.reanchor(bookmarks: [], underlines: [u], readingPosition: 0, readingAnchor: nil,
                                                 in: ContentAnchorIndex(segments: ipad))
        XCTAssertNil(out.underlines[0].isOrphan)
        XCTAssertEqual(out.underlines[0].spans.count, 1, "le due parti contigue nella nota intera diventano uno span")
        let s = out.underlines[0].spans[0]
        XCTAssertEqual(s.segmentId, "node_1")
        XCTAssertEqual(s.endWord - s.startWord, 3)
        XCTAssertNotNil(s.anchor)
    }

    func test_alContrario_ritorno_pezzoRipetutoInDueNote_restaOrfano() throws {
        // Lo stesso pezzo dentro DUE note della finestra: ambiguo, orfano (mai indovinare).
        let mac = macFlow()
        let macIndex = ContentAnchorIndex(segments: mac)
        let middle = try XCTUnwrap(mac.indices.filter { mac[$0].role == "NOTE_CONTINUATION" }.dropLast().first)
        let a = try XCTUnwrap(macIndex.anchor(forIndex: middle))
        let other = "(8) Un'altra nota che riprende un passo: " + mac[middle].text + " E poi conclude diversamente, con il lago."
        let ipad = ipadFlow() + [seg("node_9", other, role: "NOTE")]
        XCTAssertEqual(ContentAnchorIndex(segments: ipad).resolve(a).level, .orphan)
    }

    func test_alContrario_ritorno_pezzoDiNotaNonVaMaiNelCorpo() throws {
        // Il testo di un pezzo di nota citato dentro un paragrafo di corpo: non è la nota, orfano.
        let mac = macFlow()
        let macIndex = ContentAnchorIndex(segments: mac)
        let middle = try XCTUnwrap(mac.indices.filter { mac[$0].role == "NOTE_CONTINUATION" }.dropLast().first)
        let a = try XCTUnwrap(macIndex.anchor(forIndex: middle))
        let ipad = [ipadFlow()[0], seg("node_b", "Nel corpo si cita: " + mac[middle].text + " E il corpo prosegue.", role: "BODY")]
        XCTAssertEqual(ContentAnchorIndex(segments: ipad).resolve(a).level, .orphan)
    }

    func test_alContrario_fusione_citazioneSulBordo_nonFinisceSulBordoDelSegmentoNuovo() throws {
        // Due paragrafi fusi in uno; la citazione stava all'INIZIO del secondo (nessuna lettera prima) e le stesse parole
        // aprono anche il primo: deve restare nel tratto del secondo, non andare all'inizio del segmento fuso.
        let first = "Il vento della sera porta il profumo del fieno dai campi fino alle case del borgo vecchio sulla collina."
        let second = "Il vento della notte invece scende freddo dal ghiacciaio e fa tremare i vetri delle finestre della locanda."
        let old = [seg("node_0", first), seg("node_1", second)]
        let q = try XCTUnwrap(ContentAnchorIndex(segments: old).quoteAnchor(forIndex: 1, startWord: 0, endWord: 2))
        XCTAssertNil(q.prefix, "la citazione è sul bordo del vecchio segmento")
        let fused = [seg("node_0", first + " " + second)]
        let r = try XCTUnwrap(ContentAnchorIndex(segments: fused).resolve(q))
        let offset = WordTokenizer.words(first).count
        XCTAssertEqual(r.startWord, offset, "le parole del secondo paragrafo, non quelle uguali in testa al primo")
        XCTAssertEqual(r.endWord, offset + 2)
    }

    // MARK: - Il percorso dell'app: adottare la lettura del Mac su un libro annotato (AnnotationMerge)

    func test_adottareLaLetturaDelMac_suUnLibroAnnotatoNelleNote_nessunaAnnotazionePersa() throws {
        // Lo scenario della revisione indipendente: annotazioni dell'iPad dentro una nota lunga, lettura del Mac con la
        // nota divisa in pezzi; la fusione (riancoraggio delle locali, nessuna in arrivo) non deve perderne nessuna.
        let ipad = ipadFlow()
        let ipadIndex = ContentAnchorIndex(segments: ipad)
        let n = wordCount(ipad[1])
        var underlines: [Underline] = []
        var wanted: [String: String] = [:]
        for (k, f) in [0.05, 0.25, 0.45, 0.65, 0.85, 0.97].enumerated() {
            let st = Int(Double(n) * f), en = min(n - 1, st + 3)
            let q = try XCTUnwrap(ipadIndex.quoteAnchor(forIndex: 1, startWord: st, endWord: en))
            let id = "u\(k)"
            underlines.append(Underline(id: id, spans: [UnderlineSpan(segmentId: "node_1", startWord: st, endWord: en, anchor: q)],
                                        preview: "", createdAt: Date()))
            wanted[id] = WordTokenizer.words(ipad[1].text)[st...en].joined(separator: " ")
        }
        let bookmark = Bookmark(id: "b", anchorSegmentId: "node_1", orderIndexHint: 1, preview: "", createdAt: Date(),
                                anchor: ipadIndex.anchor(forIndex: 1))
        let mac = macFlow()
        let out = AnnotationMerge.merge(localBookmarks: [bookmark], localUnderlines: underlines, readingPosition: 0, readingAnchor: nil,
                                        incomingBookmarks: [], incomingUnderlines: [], in: ContentAnchorIndex(segments: mac))
        XCTAssertEqual(out.bookmarks.filter { $0.isOrphan == true }.count, 0)
        XCTAssertEqual(out.bookmarks.first?.anchorSegmentId, mac.first { $0.role == "NOTE" }?.id)
        XCTAssertEqual(out.underlines.count, underlines.count, "nessuna sottolineatura persa né raddoppiata")
        for u in out.underlines {
            XCTAssertNil(u.isOrphan, "\(u.id) è al suo posto")
            let got = u.spans.map { span -> String in
                let seg = try! XCTUnwrap(mac.first { $0.id == span.segmentId })
                return WordTokenizer.words(seg.text)[span.startWord...span.endWord].joined(separator: " ")
            }.joined(separator: " ")
            XCTAssertEqual(TextFingerprint.normalize(got), TextFingerprint.normalize(wanted[u.id]!), "\(u.id): le stesse parole")
        }
    }

    // MARK: - Risorse visive frapposte

    func test_andata_unaRisorsaVisivaFraIPezzi_siScavalca() throws {
        let a = try XCTUnwrap(ContentAnchorIndex(segments: ipadFlow()).anchor(forIndex: 1))
        var mac = macFlow()
        let firstPiece = try XCTUnwrap(mac.firstIndex { $0.role == "NOTE" })
        mac.insert(seg("vr_0", "Risorsa visiva. Tabella: il raccolto", role: VISUAL_RESOURCE_ROLE), at: firstPiece + 1)
        let r = ContentAnchorIndex(segments: mac).resolve(a)
        XCTAssertEqual(r.level, .exact)
        XCTAssertEqual(r.index, firstPiece)
    }
}
