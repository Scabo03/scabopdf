# frozen_string_literal: true
#
# Prove della carta d'identità dell'archivio dell'iPad (fastlane/carta_archivio.rb), senza archiviare né caricare: un deposito
# git provvisorio e IPA finte (uno zip con Payload/<app>.app/Info.plist). Si lancia dalla radice del repo:
#   ruby app/ios/fastlane/prove/test_carta_archivio.rb
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../carta_archivio"

class TestCartaArchivio < Minitest::Test
  APP = "com.scabo.scabopdf"

  def setup
    @dir = Dir.mktmpdir("carta_archivio")
    @repo = File.join(@dir, "repo")
    FileUtils.mkdir_p(@repo)
    git("init", "-q")
    File.write(File.join(@repo, "codice.swift"), "let a = 1\n")
    git("add", "-A")
    git("commit", "-q", "-m", "primo")
    @ipa = File.join(@dir, "ScaboApp.ipa")
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

  def ipa_finta(id: APP, build: "67", piattaforma: "iphoneos", versione: "1.0", nome: "ScaboApp")
    radice = File.join(@dir, "ipa_src")
    FileUtils.rm_rf(radice)
    app = File.join(radice, "Payload", "#{nome}.app")
    FileUtils.mkdir_p(app)
    File.write(File.join(app, "Info.plist"), <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>#{id}</string><key>CFBundleShortVersionString</key><string>#{versione}</string>
      <key>CFBundleVersion</key><string>#{build}</string><key>DTPlatformName</key><string>#{piattaforma}</string>
      </dict></plist>
    PLIST
    FileUtils.rm_f(@ipa)
    _o, e, st = Open3.capture3("zip", "-qr", @ipa, "Payload", chdir: radice)
    raise "zip: #{e}" unless st.success?
  end

  def verifica(build: "67")
    partenza = CartaArchivio.partenza!(@repo)
    yield if block_given? # ciò che succede durante la corsia
    CartaArchivio.verifica!(info: CartaArchivio.info_ipa(@ipa), app_id: APP, build_number: build, partenza: partenza,
                            ora: CartaArchivio.stato_git(@repo))
  end

  def assert_rifiuto(frammento, &blocco)
    errore = assert_raises(CartaArchivio::Rifiuto, &blocco)
    assert_includes errore.message, frammento
  end

  def test_archivio_giusto_passa_e_dichiara_la_piattaforma
    ipa_finta
    riga = verifica.first
    assert_includes riga, "Caricamento per iPad (iphoneos)"
    assert_includes riga, "#{APP}, versione 1.0, build 67"
    assert_includes riga, git("rev-parse", "HEAD")
  end

  def test_albero_non_pulito_alla_partenza_e_rifiutato
    File.write(File.join(@repo, "codice.swift"), "let a = 2\n")
    assert_rifiuto("non è pulito") { CartaArchivio.partenza!(@repo) }
  end

  def test_file_nuovo_alla_partenza_e_rifiutato
    File.write(File.join(@repo, "COSA_TESTARE.txt"), "note non committate\n")
    assert_rifiuto("non è pulito") { CartaArchivio.partenza!(@repo) }
  end

  def test_commit_durante_la_corsia_e_rifiutato
    ipa_finta
    assert_rifiuto("il codice è cambiato durante la corsia") do
      verifica { git("commit", "-q", "--allow-empty", "-m", "durante") }
    end
  end

  def test_modifica_durante_la_corsia_e_rifiutata
    ipa_finta
    assert_rifiuto("il codice è cambiato durante la corsia") do
      verifica { File.write(File.join(@repo, "codice.swift"), "let a = 3\n") }
    end
  end

  def test_archivio_di_un_altra_piattaforma_e_rifiutato
    ipa_finta(piattaforma: "macosx")
    assert_rifiuto("non per l'iPad") { verifica }
  end

  def test_archivio_di_un_altra_app_e_rifiutato
    ipa_finta(id: "com.esempio.altra")
    assert_rifiuto("non di #{APP}") { verifica }
  end

  def test_archivio_di_un_altra_build_e_rifiutato
    ipa_finta(build: "66")
    assert_rifiuto("è della build \"66\", non della 67") { verifica }
  end

  def test_archivio_senza_versione_e_rifiutato
    ipa_finta(versione: "")
    assert_rifiuto("manca la versione") { verifica }
  end

  def test_archivio_mancante_e_rifiutato
    assert_rifiuto("l'archivio non c'è") { verifica }
  end

  def test_archivio_senza_info_plist_e_rifiutato
    File.write(File.join(@dir, "x.txt"), "x")
    Open3.capture3("zip", "-q", @ipa, "x.txt", chdir: @dir)
    assert_rifiuto("manca Payload/<app>.app/Info.plist") { verifica }
  end
end
