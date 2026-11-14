# frozen_string_literal: true
#
# Prove dell'identità del pacchetto del Mac (fastlane/identita_pacchetto.rb), senza firmare né caricare: ogni prova fa un deposito
# git provvisorio, un «pacchetto» finto e la costruzione simulata della corsia (lo stesso `IdentitaPacchetto.costruisci` che usa
# il Fastfile, con un blocco al posto di build_app.sh). Si lancia dalla radice del repo:
#   ruby app/macos/ScaboMac/fastlane/prove/test_identita_pacchetto.rb
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../identita_pacchetto"

class TestIdentitaPacchetto < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("identita_pacchetto")
    @repo = File.join(@dir, "repo")
    FileUtils.mkdir_p(@repo)
    git("init", "-q")
    File.write(File.join(@repo, "codice.swift"), "let a = 1\n")
    commit("primo")
    @uscita = File.join(@dir, "uscita") # fuori dal deposito, come build/ (ignorata) nel repo vero
    FileUtils.mkdir_p(@uscita)
    @pkg = File.join(@uscita, "ScaboPDF.pkg")
  end

  def teardown
    FileUtils.rm_rf(@dir) if @dir && @dir.start_with?(Dir.tmpdir)
  end

  def git(*argomenti)
    uscita, errore, stato = Open3.capture3("git", "-C", @repo, "-c", "user.name=prova", "-c", "user.email=prova@example.invalid",
                                           "-c", "commit.gpgsign=false", *argomenti)
    raise "git #{argomenti.join(' ')}: #{errore}" unless stato.success?
    uscita.strip
  end

  def commit(messaggio, file: "codice.swift", testo: nil)
    File.write(File.join(@repo, file), testo) if testo
    git("add", "-A")
    git("commit", "-q", "--allow-empty", "-m", messaggio)
    git("rev-parse", "HEAD")
  end

  # La costruzione simulata: scrive il pacchetto finto; `durante` fa qualcosa mentre «si compila e si aspetta il portachiavi».
  def costruisci(build: "2", durante: nil)
    IdentitaPacchetto.costruisci(@pkg, repo: @repo, build_number: build) do |_inizio|
      durante&.call
      File.write(@pkg, "pacchetto #{Time.now.to_f}\n")
    end
  end

  def verifica(build: "2")
    IdentitaPacchetto.verifica!(@pkg, repo: @repo, build_number: build)
  end

  def assert_rifiuto(frammento, &blocco)
    errore = assert_raises(IdentitaPacchetto::Rifiuto, &blocco)
    assert_includes errore.message, frammento
  end

  # --- la prova chiesta: un commit dopo la costruzione fa rifiutare; lo stesso commit, costruito, fa passare ---

  def test_stesso_commit_il_riuso_passa
    head = git("rev-parse", "HEAD")
    costruisci
    dati = verifica
    assert_equal head, dati["commit"]
    assert dati["albero_pulito"] && dati["albero_pulito_alla_fine"]
  end

  def test_commit_dopo_la_costruzione_il_riuso_e_rifiutato
    costruisci
    commit("dopo la validazione", testo: "let a = 2\n")
    assert_rifiuto("lo HEAD attuale") { verifica }
  end

  def test_lo_stesso_commit_costruito_di_nuovo_passa
    costruisci
    nuovo = commit("dopo la validazione", testo: "let a = 2\n")
    assert_rifiuto("lo HEAD attuale") { verifica }
    costruisci # `fastlane mac valida` rifatto sul commit nuovo
    assert_equal nuovo, verifica["commit"]
  end

  def test_anche_un_commit_che_non_tocca_il_codice_dell_app_fa_rifiutare
    costruisci
    commit("solo documenti", file: "NOTE.md", testo: "nota\n")
    assert_rifiuto("lo HEAD attuale") { verifica }
  end

  # --- il caso N16: il commit fatto MENTRE si aspetta la finestra del portachiavi, prima che il pacchetto sia scritto ---

  def test_n16_commit_durante_la_costruzione_e_rifiutato
    costruisci(durante: -> { commit("durante l'attesa del portachiavi", testo: "let a = 3\n") })
    assert_rifiuto("durante la costruzione del pacchetto lo HEAD è cambiato") { verifica }
  end

  def test_n16_il_vecchio_controllo_delle_ore_non_vedeva_quel_commit
    # Il controllo di 61c6b93, ricopiato: «l'ultimo commit è più recente del pacchetto?». Il pacchetto è scritto DOPO il commit
    # fatto nell'attesa, quindi la risposta è no e il riuso passava: è il difetto N16.
    costruisci(durante: lambda {
      commit("durante l'attesa del portachiavi", testo: "let a = 3\n")
      sleep 1.1 # la risoluzione del confronto era il secondo
    })
    ultimo = git("log", "-1", "--format=%ct").to_i
    vecchio_controllo_passava = !(ultimo > File.mtime(@pkg).to_i)
    assert vecchio_controllo_passava, "il vecchio controllo avrebbe dovuto non accorgersene (è la riproduzione di N16)"
    assert_rifiuto("lo HEAD è cambiato") { verifica } # il nuovo se ne accorge
  end

  # --- l'albero di lavoro non pulito ---

  def test_modifica_non_committata_all_inizio_fa_rifiutare
    File.write(File.join(@repo, "codice.swift"), "let a = 9\n")
    costruisci
    assert_rifiuto("non era pulito") { verifica }
  end

  def test_file_nuovo_non_seguito_all_inizio_fa_rifiutare
    File.write(File.join(@repo, "nuovo.swift"), "let b = 1\n")
    costruisci
    assert_rifiuto("non era pulito") { verifica }
  end

  def test_modifica_fatta_durante_la_costruzione_fa_rifiutare
    costruisci(durante: -> { File.write(File.join(@repo, "codice.swift"), "let a = 4\n") })
    assert_rifiuto("non era pulito") { verifica }
  end

  # --- il pacchetto e la sua identità ---

  def test_build_diversa_fa_rifiutare
    costruisci(build: "2")
    assert_rifiuto("è della build 2, non della 3") { verifica(build: "3") }
  end

  def test_pacchetto_cambiato_fuori_dalla_corsia_fa_rifiutare
    costruisci
    File.write(@pkg, "un altro pacchetto\n")
    assert_rifiuto("impronta diversa") { verifica }
  end

  def test_identita_mancante_fa_rifiutare
    File.write(@pkg, "pacchetto fatto a mano\n")
    assert_rifiuto("manca l'identità") { verifica }
  end

  def test_pacchetto_mancante_fa_rifiutare
    assert_rifiuto("non c'è un pacchetto pronto") { verifica }
  end

  def test_identita_illeggibile_fa_rifiutare
    costruisci
    File.write(IdentitaPacchetto.percorso(@pkg), "{ non è json")
    assert_rifiuto("non si legge") { verifica }
  end

  def test_costruzione_interrotta_non_lascia_un_identita_vecchia
    costruisci
    assert File.exist?(IdentitaPacchetto.percorso(@pkg))
    assert_raises(RuntimeError) do
      IdentitaPacchetto.costruisci(@pkg, repo: @repo, build_number: "2") { raise "firma non riuscita" }
    end
    refute File.exist?(IdentitaPacchetto.percorso(@pkg)), "l'identità vecchia non deve restare accanto al pacchetto vecchio"
    assert_rifiuto("manca l'identità") { verifica }
  end
end
