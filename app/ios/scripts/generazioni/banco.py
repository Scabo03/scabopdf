#!/usr/bin/env python3
"""IL BANCO DELLE RETI fra repo e laboratorio (giro «prove rifatte e granularità», 2026-11-10).

Nel repo c'è solo `banco_volumi.json`: per ogni volume del banco un'ETICHETTA neutra (v01…v52) e l'IMPRONTA SHA-256 del PDF, più
l'etichetta del volume di controllo. Nessun nome di file né di volume. La corrispondenza etichetta → percorso del PDF (relativo
al corpus, ~/Developer/scabopdf-triple-take) sta SOLO nel laboratorio, in `<SCABO_GEN_LAB>/banco/corrispondenza_volumi.json`
(altro file con SCABO_BANCO_CORRISPONDENZA). Le reti chiedono la lista a questo script; se la corrispondenza manca, è
incompleta o un'impronta non torna, lo script si ferma con un messaggio chiaro e il codice 2 (prerequisito mancante): una rete
non dà mai verde su un banco che non ha potuto verificare.

Uso:
  banco.py risolvi <uscita_lista.json>       la lista dei percorsi (la forma di sempre: ["originals/….pdf", …]) nell'ordine del
                                              banco, dopo aver verificato corrispondenza e impronte
  banco.py controllo                          il percorso del volume di controllo, senza estensione (per SCABO_CONTROLLO), dopo
                                              averne verificato l'impronta
  banco.py etichette <uscita.json>            {percorso: etichetta} (per gli strumenti che parlano per etichette)
  banco.py posti-a-percorsi <verità> <uscita> la verità del posto delle risorse visive (repo, per etichette) con i percorsi
  banco.py posti-a-etichette <verità> <uscita> l'inverso, per registrare una verità nuova nel repo senza nomi

Variabili: SCABO_GEN_LAB (~/Developer/scabopdf-gen-lab), SCABO_CORPUS (~/Developer/scabopdf-triple-take),
SCABO_BANCO_CORRISPONDENZA (il file della corrispondenza). Codici d'uscita: 0 fatto, 2 corrispondenza o corpus da sistemare.
Una lista passata alle reti con SCABO_LISTA non passa da qui: le sue impronte non sono verificate (serve per le prove su una
parte dei volumi).
"""
import hashlib, json, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
BANCO = os.path.join(QUI, "banco_volumi.json")
LAB = os.environ.get("SCABO_GEN_LAB") or os.path.expanduser("~/Developer/scabopdf-gen-lab")
CORPUS = os.environ.get("SCABO_CORPUS") or os.path.expanduser("~/Developer/scabopdf-triple-take")
CORR = os.environ.get("SCABO_BANCO_CORRISPONDENZA") or os.path.join(LAB, "banco", "corrispondenza_volumi.json")


def ferma(msg):
    sys.stderr.write("banco.py: " + msg + "\n")
    sys.exit(2)


def carica():
    banco = json.load(open(BANCO))
    if not os.path.exists(CORR):
        ferma(f"manca la corrispondenza fra le etichette del banco e i volumi: {CORR}. Sta solo nel laboratorio (il repo ha "
              f"soltanto etichette e impronte): rimettila lì, oppure indica il file con SCABO_BANCO_CORRISPONDENZA. Nessuna "
              f"rete può girare senza.")
    try:
        corr = json.load(open(CORR))["volumi"]
    except (ValueError, KeyError) as e:
        ferma(f"corrispondenza illeggibile ({CORR}): {e}")
    return banco, corr


def risolvi(verifica=True):
    banco, corr = carica()
    percorsi, problemi = [], []
    for v in banco["volumi"]:
        et, imp = v["etichetta"], v["impronta"]
        p = corr.get(et)
        if not p:
            problemi.append(f"{et}: non nella corrispondenza"); continue
        if verifica:
            f = os.path.join(CORPUS, p)
            if not os.path.exists(f):
                problemi.append(f"{et}: il PDF non è nel corpus"); continue
            h = hashlib.sha256(open(f, "rb").read()).hexdigest()
            if h != imp:
                problemi.append(f"{et}: l'impronta del PDF non è quella del banco"); continue
        percorsi.append(p)
    if problemi:
        ferma(f"la corrispondenza del laboratorio ({CORR}) non torna col banco del repo: " + "; ".join(problemi[:8])
              + (f" (e altri {len(problemi) - 8})" if len(problemi) > 8 else ""))
    return banco, corr, percorsi


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "risolvi" and len(argv) == 3:
        _, _, percorsi = risolvi()
        os.makedirs(os.path.dirname(os.path.abspath(argv[2])), exist_ok=True)
        json.dump(percorsi, open(argv[2], "w"), ensure_ascii=False, indent=0)
        print(f"banco: {len(percorsi)} volumi verificati (corrispondenza e impronte) → {argv[2]}")
    elif cmd == "controllo" and len(argv) == 2:
        banco, corr = carica()
        et = banco["controllo"]
        p = corr.get(et)
        if not p:
            ferma(f"il volume di controllo {et} non è nella corrispondenza ({CORR})")
        impronte = {v["etichetta"]: v["impronta"] for v in banco["volumi"]}
        f = os.path.join(CORPUS, p)
        if not os.path.exists(f):
            ferma(f"il volume di controllo {et} non è nel corpus")
        if et in impronte and hashlib.sha256(open(f, "rb").read()).hexdigest() != impronte[et]:
            ferma(f"l'impronta del volume di controllo {et} non è quella del banco")
        print(p[:-4] if p.endswith(".pdf") else p)
    elif cmd == "etichette" and len(argv) == 3:
        banco, corr = carica()
        json.dump({corr[v["etichetta"]]: v["etichetta"] for v in banco["volumi"] if v["etichetta"] in corr},
                  open(argv[2], "w"), ensure_ascii=False, indent=0)
    elif cmd in ("posti-a-percorsi", "posti-a-etichette") and len(argv) == 4:
        banco, corr = carica()
        inverso = {p: e for e, p in corr.items()}
        mappa = corr if cmd == "posti-a-percorsi" else inverso
        verita = json.load(open(argv[2]))
        for gen, per_volume in verita.get("generazioni", {}).items():
            nuovo = {}
            for k, v in per_volume.items():
                if k not in mappa:
                    ferma(f"la verità del posto nomina «{k}» ({gen}), che la corrispondenza non conosce")
                nuovo[mappa[k]] = v
            verita["generazioni"][gen] = nuovo
        open(argv[3], "w").write(json.dumps(verita, ensure_ascii=False, indent=1) + "\n")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
