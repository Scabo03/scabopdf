# frozen_string_literal: true
#
# LA CARTA D'IDENTITÀ DELL'ARCHIVIO dell'iPad (giro «corsie e memoria», 2026-11-14): la regola fissa di ogni caricamento
# (docs/RELEASE_TESTFLIGHT.md, «La regola fissa di ogni caricamento») vuole che prima dell'invio si verifichino sull'archivio
# piattaforma, identificativo, versione, numero di build e commit d'origine. La corsia dell'iPad archivia e carica in una corsa
# sola, quindi il controllo lo fa lei: all'inizio annota lo HEAD e rifiuta un albero di lavoro non pulito (senza, l'archivio
# non corrisponderebbe a nessun commit); fra l'esportazione e il caricamento legge l'Info.plist dentro l'IPA e confronta.
#
# Modulo senza fastlane: lo usa il Fastfile (`require`) e lo provano i test in fastlane/prove/, senza archiviare né caricare.
require "json"
require "open3"

module CartaArchivio
  # Il rifiuto, con il messaggio da mostrare: il Fastfile lo trasforma in `UI.user_error!`.
  class Rifiuto < StandardError; end

  module_function

  def esegui(*comando, input: nil)
    uscita, errore, stato = Open3.capture3(*comando, stdin_data: input, binmode: true)
    raise Rifiuto, "#{comando.first} non è riuscito (#{stato.exitstatus}): #{errore.strip}" unless stato.success?
    uscita
  end

  # Lo HEAD e se l'albero di lavoro è pulito (nessuna modifica, né file nuovi non ignorati).
  def stato_git(repo)
    { commit: esegui("git", "-C", repo, "rev-parse", "HEAD").strip,
      pulito: esegui("git", "-C", repo, "status", "--porcelain", "--untracked-files=normal").strip.empty? }
  end

  # All'inizio della corsia: lo stato da confrontare prima dell'invio. Rifiuta un albero non pulito.
  def partenza!(repo)
    stato = stato_git(repo)
    unless stato[:pulito]
      raise Rifiuto, "l'albero di lavoro non è pulito: l'archivio non corrisponderebbe a un commit. Committa (note per i tester " \
                     "comprese) o togli le modifiche, poi rilancia"
    end
    stato
  end

  # L'Info.plist dell'app dentro l'IPA, come Hash.
  def info_ipa(ipa)
    raise Rifiuto, "l'archivio non c'è: #{ipa}" unless File.exist?(ipa)
    elenco = esegui("unzip", "-Z1", ipa).lines.map(&:strip)
    voce = elenco.find { |v| v.match?(%r{\APayload/[^/]+\.app/Info\.plist\z}) }
    raise Rifiuto, "nell'archivio manca Payload/<app>.app/Info.plist" unless voce
    plist = esegui("unzip", "-p", ipa, voce)
    JSON.parse(esegui("plutil", "-convert", "json", "-o", "-", "-", input: plist))
  end

  # Prima dell'invio: confronta l'archivio con ciò che la corsia sta per caricare. Restituisce le righe della carta da stampare.
  def verifica!(info:, app_id:, build_number:, partenza:, ora:)
    piattaforma = info["DTPlatformName"]
    raise Rifiuto, "l'archivio è per la piattaforma #{piattaforma.inspect}, non per l'iPad (iphoneos)" unless piattaforma == "iphoneos"
    unless info["CFBundleIdentifier"] == app_id
      raise Rifiuto, "l'archivio è dell'app #{info['CFBundleIdentifier'].inspect}, non di #{app_id}"
    end
    versione = info["CFBundleShortVersionString"].to_s
    raise Rifiuto, "nell'archivio manca la versione (CFBundleShortVersionString)" if versione.empty?
    unless info["CFBundleVersion"].to_s == build_number.to_s
      raise Rifiuto, "l'archivio è della build #{info['CFBundleVersion'].inspect}, non della #{build_number}"
    end
    unless ora[:commit] == partenza[:commit] && ora[:pulito]
      raise Rifiuto, "il codice è cambiato durante la corsia (HEAD da #{partenza[:commit][0, 12]} a #{ora[:commit][0, 12]}, " \
                     "albero pulito: #{ora[:pulito]}): l'archivio non corrisponde più a un commit; rilancia"
    end
    ["Caricamento per iPad (#{piattaforma}): #{app_id}, versione #{versione}, build #{build_number}, " \
     "commit d'origine #{partenza[:commit]} (albero pulito)"]
  end
end
