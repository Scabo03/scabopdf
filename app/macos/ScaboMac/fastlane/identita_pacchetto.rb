# frozen_string_literal: true
#
# L'IDENTITÀ DEL PACCHETTO del Mac (giro «corsie e memoria», 2026-11-14; cura del rilievo N16 del giro «ScaboPDF per Mac su
# TestFlight»). Accanto a `ScaboPDF.pkg` la corsia scrive `ScaboPDF.pkg.identita.json`: il commit (HEAD) e lo stato pulito
# dell'albero di lavoro quando la costruzione COMINCIA (prima della compilazione) e poi quando FINISCE (dopo
# l'ultima firma, cioè dopo le eventuali finestre del portachiavi), il numero della build e l'impronta SHA-256 del pacchetto.
# Prima di riusare il pacchetto per il caricamento la corsia confronta queste cose con lo HEAD attuale, e rifiuta il riuso se:
#   - l'identità manca o non è leggibile;
#   - il pacchetto non è quello descritto (impronta diversa) o è di un'altra build;
#   - l'albero di lavoro non era pulito a inizio o a fine costruzione;
#   - lo HEAD è cambiato durante la costruzione (un commit fatto mentre si compilava o si aspettava il portachiavi);
#   - lo HEAD attuale è diverso da quello da cui il pacchetto è stato costruito.
# Prima (fino a 61c6b93) la corsia confrontava l'ora dei commit con l'ora del pacchetto, che `productbuild` scrive solo dopo la
# risposta alla finestra del portachiavi: un commit fatto durante quell'attesa sfuggiva (N16).
#
# Modulo senza fastlane: lo usa il Fastfile (`require`) e lo provano i test in fastlane/prove/ (`ruby -I… test_….rb`), senza
# firmare né caricare nulla.
require "digest"
require "json"
require "open3"
require "time"
require "tmpdir"

module IdentitaPacchetto
  # Il rifiuto, con il messaggio da mostrare: il Fastfile lo trasforma in `UI.user_error!`.
  class Rifiuto < StandardError; end

  FORMATO = 1

  module_function

  # Il file dell'identità, accanto al pacchetto.
  def percorso(pkg)
    "#{pkg}.identita.json"
  end

  def git(repo, *argomenti)
    uscita, errore, stato = Open3.capture3("git", "-C", repo, *argomenti)
    raise Rifiuto, "git #{argomenti.first} non è riuscito (#{stato.exitstatus}): #{errore.strip}" unless stato.success?
    uscita
  end

  # Lo HEAD e se l'albero di lavoro è pulito: nessuna modifica, né nei file seguiti né in file nuovi non ignorati.
  def stato(repo)
    { commit: git(repo, "rev-parse", "HEAD").strip,
      pulito: git(repo, "status", "--porcelain", "--untracked-files=normal").strip.empty? }
  end

  # Costruisce il pacchetto (il blocco) e scrive la sua identità. L'identità vecchia si toglie PRIMA, così un pacchetto rimasto
  # da una costruzione interrotta non resta mai accoppiato a un'identità che non è la sua. Restituisce lo stato iniziale, perché
  # chi chiama possa avvisare subito se l'albero non era pulito.
  def costruisci(pkg, repo:, build_number:)
    File.delete(percorso(pkg)) if File.exist?(percorso(pkg))
    inizio = stato(repo)
    yield inizio
    raise Rifiuto, "il pacchetto non c'è dopo la costruzione: #{pkg}" unless File.exist?(pkg)
    fine = stato(repo)
    dati = { "formato" => FORMATO, "build" => build_number.to_s,
             "commit" => inizio[:commit], "albero_pulito" => inizio[:pulito],
             "commit_alla_fine" => fine[:commit], "albero_pulito_alla_fine" => fine[:pulito],
             "sha256_pacchetto" => Digest::SHA256.file(pkg).hexdigest, "scritta" => Time.now.utc.iso8601 }
    File.write(percorso(pkg), "#{JSON.pretty_generate(dati)}\n")
    dati
  end

  # Il controllo prima del riuso: restituisce l'identità se il pacchetto si può riusare, altrimenti solleva `Rifiuto`.
  def verifica!(pkg, repo:, build_number:)
    nome = File.basename(percorso(pkg))
    raise Rifiuto, "non c'è un pacchetto pronto da riusare (#{pkg}): prima `fastlane mac valida`" unless File.exist?(pkg)
    unless File.exist?(percorso(pkg))
      raise Rifiuto, "manca l'identità del pacchetto (#{nome}): il pacchetto non è stato fatto da questa corsia; " \
                     "rifai `fastlane mac valida`"
    end
    dati = begin
      JSON.parse(File.read(percorso(pkg)))
    rescue JSON::ParserError => e
      raise Rifiuto, "l'identità del pacchetto (#{nome}) non si legge: #{e.message}"
    end
    raise Rifiuto, "l'identità del pacchetto ha un formato sconosciuto (#{dati['formato'].inspect})" unless dati["formato"] == FORMATO
    unless dati["build"] == build_number.to_s
      raise Rifiuto, "il pacchetto pronto è della build #{dati['build']}, non della #{build_number}"
    end
    unless dati["sha256_pacchetto"] == Digest::SHA256.file(pkg).hexdigest
      raise Rifiuto, "il pacchetto non è quello descritto dalla sua identità (impronta diversa): è stato rifatto o cambiato " \
                     "fuori dalla corsia; rifai `fastlane mac valida`"
    end
    unless dati["albero_pulito"] && dati["albero_pulito_alla_fine"]
      raise Rifiuto, "l'albero di lavoro non era pulito mentre il pacchetto veniva costruito (modifiche non committate): " \
                     "il pacchetto non corrisponde a un commit; committa o togli le modifiche e rifai `fastlane mac valida`"
    end
    unless dati["commit"] == dati["commit_alla_fine"]
      raise Rifiuto, "durante la costruzione del pacchetto lo HEAD è cambiato (da #{dati['commit'][0, 12]} a " \
                     "#{dati['commit_alla_fine'][0, 12]}): rifai `fastlane mac valida` senza committare mentre lavora"
    end
    attuale = stato(repo)[:commit]
    unless attuale == dati["commit"]
      raise Rifiuto, "lo HEAD attuale (#{attuale[0, 12]}) è diverso da quello da cui è stato costruito il pacchetto " \
                     "(#{dati['commit'][0, 12]}): rifai `fastlane mac valida` sul codice attuale"
    end
    dati
  end

  # La carta d'identità del pacchetto che parte (regola fissa di ogni caricamento, docs/RELEASE_TESTFLIGHT.md): piattaforma,
  # identificativo, versione e build letti dal file Distribution DENTRO il pacchetto (un archivio xar, senza estrarre l'app),
  # più il commit d'origine dall'identità già verificata (`dati`). Restituisce le righe da stampare.
  def carta_pacchetto!(pkg, app_id:, build_number:, dati:)
    testo = Dir.mktmpdir("carta_pacchetto") do |d|
      _uscita, errore, stato = Open3.capture3("xar", "-xf", pkg, "-C", d, "Distribution")
      unless stato.success? && File.exist?(File.join(d, "Distribution"))
        raise Rifiuto, "il pacchetto non si legge come pacchetto d'installazione del Mac (xar #{stato.exitstatus}): #{errore.strip}"
      end
      File.read(File.join(d, "Distribution"))
    end
    raise Rifiuto, "il pacchetto non è un pacchetto d'installazione del Mac (manca installer-gui-script)" unless testo.include?("<installer-gui-script")
    bundle = testo[/<bundle\s[^>]*\bid="#{Regexp.escape(app_id)}"[^>]*>/]
    raise Rifiuto, "nel pacchetto non c'è l'app #{app_id}" unless bundle
    versione = bundle[/CFBundleShortVersionString="([^"]*)"/, 1].to_s
    build = bundle[/CFBundleVersion="([^"]*)"/, 1].to_s
    raise Rifiuto, "nel pacchetto manca la versione dell'app" if versione.empty?
    raise Rifiuto, "nel pacchetto l'app è della build #{build.inspect}, non della #{build_number}" unless build == build_number.to_s
    ["Caricamento per Mac (pacchetto d'installazione macOS): #{app_id}, versione #{versione}, build #{build}, " \
     "commit d'origine #{dati['commit']} (albero pulito)"]
  end
end
