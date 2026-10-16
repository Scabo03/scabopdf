//
//  GlmOcr.swift
//  ScaboMacOCR
//
//  IL LETTORE DI PAGINE GLM-OCR DENTRO L'APP (giro «costruzione della linea Mac», 2026-10-16). Pesi `GLM-OCR-Q8_0.gguf`
//  e proiettore `mmproj-GLM-OCR-Q8_0.gguf` (ggml-org/GLM-OCR-GGUF, licenza MIT) scaricati dal pannello dei modelli nel
//  contenitore dell'app; motore llama.cpp (release ufficiale b11429, verificata) collegato all'app: nessun server, nessun
//  processo separato, niente rete. Le impostazioni sono quelle del banco del laboratorio OCR (richiesta «Text
//  Recognition:», immagine prima del testo, generazione deterministica, penalità di ripetizione 1,05).
//
//  Stato: il tasto «Verifica» del pannello lo usa sulla pagina di prova inclusa; dentro la catena di elaborazione del
//  Mac è un PROTOTIPO dichiarato (non entra nelle letture di questo giro).
//

import Foundation
import llama

public enum GlmOcr {

    /// Le impostazioni del banco del laboratorio OCR.
    public static let prompt = "Text Recognition:"
    public static let maxTokens = 3000
    public static let repeatPenalty: Float = 1.05
    public static let contextTokens: UInt32 = 8192

    public struct Lettura: Sendable {
        public let testo: String
        public let tokenGenerati: Int
        public let secondiCaricamento: Double
        public let secondiLettura: Double
    }

    public enum Problema: Error, Equatable, Sendable {
        case pesiNonCaricati
        case proiettoreNonCaricato
        case contestoNonCreato
        case immagineNonLeggibile
        case preparazioneFallita(Int32)
        case valutazioneFallita(Int32)
        case generazioneFallita
        case annullata
    }

    /// La pagina di prova inclusa nell'app (PNG) e il suo testo atteso.
    public static var paginaDiProva: (png: Data, testo: String)? {
        guard let p = Bundle.module.url(forResource: "pagina_prova", withExtension: "png"),
              let t = Bundle.module.url(forResource: "pagina_prova", withExtension: "txt"),
              let png = try? Data(contentsOf: p), let testo = try? String(contentsOf: t, encoding: .utf8) else { return nil }
        return (png, testo)
    }

    /// Legge l'immagine `png` con GLM-OCR. Sul thread chiamante (lungo: chiamare fuori dal main). Tutte le risorse del
    /// motore si liberano prima di tornare, in ordine (llama.cpp interrompe il processo all'uscita se restano aperte).
    public static func leggi(png: Data, pesi: URL, proiettore: URL, annullata: () -> Bool = { false }) throws -> Lettura {
        let t0 = Date()
        llama_backend_init()
        defer { llama_backend_free() }
        var mp = llama_model_default_params()
        mp.n_gpu_layers = 99
        guard let model = llama_model_load_from_file(pesi.path, mp) else { throw Problema.pesiNonCaricati }
        defer { llama_model_free(model) }
        var cp = llama_context_default_params()
        cp.n_ctx = contextTokens
        cp.n_batch = 2048
        guard let lctx = llama_init_from_model(model, cp) else { throw Problema.contestoNonCreato }
        defer { llama_free(lctx) }
        var mparams = mtmd_context_params_default()
        mparams.use_gpu = true
        mparams.print_timings = false
        mparams.warmup = false
        guard let mctx = mtmd_init_from_file(proiettore.path, model, mparams) else { throw Problema.proiettoreNonCaricato }
        defer { mtmd_free(mctx) }
        let caricamento = Date().timeIntervalSince(t0)

        let t1 = Date()
        let wrapper = png.withUnsafeBytes { raw -> mtmd_helper_bitmap_wrapper in
            mtmd_helper_bitmap_init_from_buf(mctx, raw.bindMemory(to: UInt8.self).baseAddress, raw.count, false,
                                             mtmd_helper_init_opt_default())
        }
        guard let bitmap = wrapper.bitmap else { throw Problema.immagineNonLeggibile }
        defer { mtmd_bitmap_free(bitmap) }

        // La richiesta nel modello di chat del modello stesso (immagine, poi la richiesta), con l'avvio della risposta.
        let marker = String(cString: mtmd_default_marker())
        let utente = marker + prompt
        let formattata = applicaModelloDiChat(model, utente: utente)
        let chunks = mtmd_input_chunks_init()
        defer { mtmd_input_chunks_free(chunks) }
        let rc: Int32 = formattata.withCString { cstr in
            var testo = mtmd_input_text(text: cstr, text_len: strlen(cstr), add_special: true, parse_special: true)
            var bitmaps: [OpaquePointer?] = [bitmap]
            return bitmaps.withUnsafeMutableBufferPointer { buf in
                mtmd_tokenize(mctx, chunks, &testo, buf.baseAddress, 1)
            }
        }
        guard rc == 0 else { throw Problema.preparazioneFallita(rc) }
        var nPast: llama_pos = 0
        let ev = mtmd_helper_eval_chunks(mctx, lctx, chunks, 0, 0, Int32(cp.n_batch), true, &nPast)
        guard ev == 0 else { throw Problema.valutazioneFallita(ev) }

        // Generazione deterministica con penalità di ripetizione.
        let vocab = llama_model_get_vocab(model)
        let sparams = llama_sampler_chain_default_params()
        guard let smpl = llama_sampler_chain_init(sparams) else { throw Problema.generazioneFallita }
        defer { llama_sampler_free(smpl) }
        // Prima i 50 candidati migliori (la penalità sull'intero vocabolario è lenta, avverte llama.cpp), poi la penalità di
        // ripetizione sugli ultimi 64 token, poi il migliore: deterministico.
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(50))
        llama_sampler_chain_add(smpl, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64, repeatPenalty, 0, 0))
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy())
        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }
        var bytes: [UInt8] = []
        var prodotti = 0
        while prodotti < maxTokens {
            if annullata() { throw Problema.annullata }
            let tok = llama_sampler_sample(smpl, lctx, -1)
            if llama_vocab_is_eog(vocab, tok) { break }
            var buf = [CChar](repeating: 0, count: 256)
            let k = llama_token_to_piece(vocab, tok, &buf, Int32(buf.count), 0, false)
            if k > 0 { bytes += buf.prefix(Int(k)).map { UInt8(bitPattern: $0) } }
            prodotti += 1
            batch.n_tokens = 1
            batch.token[0] = tok
            batch.pos[0] = nPast
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1
            nPast += 1
            if llama_decode(lctx, batch) != 0 { throw Problema.generazioneFallita }
        }
        let testo = String(decoding: bytes, as: UTF8.self)
        return Lettura(testo: ripulisci(testo), tokenGenerati: prodotti, secondiCaricamento: caricamento,
                       secondiLettura: Date().timeIntervalSince(t1))
    }

    /// Il testo dell'utente nel modello di chat del modello (se llama.cpp lo riconosce), altrimenti nella forma di GLM.
    static func applicaModelloDiChat(_ model: OpaquePointer, utente: String) -> String {
        let tmpl = llama_model_chat_template(model, nil)
        let ruolo = strdup("user"), contenuto = strdup(utente)
        defer { free(ruolo); free(contenuto) }
        var msg = llama_chat_message(role: ruolo, content: contenuto)
        var buf = [CChar](repeating: 0, count: 4096)
        let n = llama_chat_apply_template(tmpl, &msg, 1, true, &buf, Int32(buf.count))
        if n > 0, Int(n) < buf.count {
            return String(decoding: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return "[gMASK]<sop><|user|>\n" + utente + "<|assistant|>\n"
    }

    /// Toglie i contrassegni di formato che il modello aggiunge a volte (come fa il banco: `strip_tags`).
    static func ripulisci(_ t: String) -> String {
        var s = t
        for tag in ["<|begin_of_box|>", "<|end_of_box|>", "</think>", "<think>"] { s = s.replacingOccurrences(of: tag, with: "") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Misura

    /// Le parole (lettere e cifre, minuscole) di un testo.
    public static func parole(_ t: String) -> [String] {
        t.lowercased().split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    /// Accordo fra le parole lette e quelle attese (misura F sul multinsieme: 1 = identiche).
    public static func accordo(letto: String, atteso: String) -> Double {
        let a = parole(letto), b = parole(atteso)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var cb: [String: Int] = [:]
        for w in b { cb[w, default: 0] += 1 }
        var comuni = 0
        for w in a where (cb[w] ?? 0) > 0 { comuni += 1; cb[w]! -= 1 }
        let p = Double(comuni) / Double(a.count), r = Double(comuni) / Double(b.count)
        return p + r > 0 ? 2 * p * r / (p + r) : 0
    }
}
