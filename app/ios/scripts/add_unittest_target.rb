#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds (idempotently) the ScaboPDFExtractionTests app-hosted XCTest unit target
# to ScaboPDF.xcodeproj and registers it as a second testable in the shared
# scheme (the XCUITest target ScaboPDFUITests is left exactly as is). Run with
# the CocoaPods-bundled xcodeproj gem (no Python in the toolchain):
#
#   cd app/ios && bundle exec ruby scripts/add_unittest_target.rb
#   bundle exec pod install   # wires the :search_paths inheritance
#
# Why a hosted unit target (vs the UI target): an XCTest unit test does NOT use
# the accessibility-automation backbone, so it runs on the restricted sandbox
# Simulator where XCUITest cannot. Hosting it on the app lets it read the app's
# own data container, where seed_fixtures.sh places the PDFs, and `import
# ScaboNative` (via the Podfile's `inherit! :search_paths`) calls the real
# ScaboPdfExtractor / ScaboLog without a second linked copy.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ScaboPDF.xcodeproj')
APP_TARGET_NAME = 'ScaboPDF'
TEST_TARGET_NAME = 'ScaboPDFExtractionTests'
TEST_SOURCE = 'ScaboPDFExtractionTests.swift'

project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
raise "App target #{APP_TARGET_NAME} not found" if app_target.nil?

test_target = project.targets.find { |t| t.name == TEST_TARGET_NAME }

if test_target.nil?
  puts "Creating hosted unit-test target #{TEST_TARGET_NAME}…"
  test_target = project.new_target(
    :unit_test_bundle, TEST_TARGET_NAME, :ios, '15.1', project.products_group, :swift
  )

  # Source group + file (group carries the dir path; file is the bare name).
  group = project.main_group.find_subpath(TEST_TARGET_NAME, true)
  group.set_source_tree('SOURCE_ROOT')
  group.set_path(TEST_TARGET_NAME)
  file_ref = group.find_file_by_path(TEST_SOURCE) || group.new_file(TEST_SOURCE)
  unless test_target.source_build_phase.files_references.include?(file_ref)
    test_target.add_file_references([file_ref])
  end

  # Hosted by the app so the test reads the app container and links ScaboNative
  # symbols from the host at runtime.
  test_target.add_dependency(app_target)
else
  puts "Unit-test target #{TEST_TARGET_NAME} already exists; updating settings…"
end

host = '$(BUILT_PRODUCTS_DIR)/ScaboPDF.app/ScaboPDF'
test_target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.scabo.scabopdf.extractiontests'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['TEST_HOST'] = host
  s['BUNDLE_LOADER'] = '$(TEST_HOST)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.1'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  s['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
end

project.save
puts "Project saved. Target UUID: #{test_target.uuid}"

# --- Register as a SECOND testable in the shared scheme --------------------
# Keep the existing ScaboPDFUITests testable; just add this one so
# `xcodebuild test -only-testing:ScaboPDFExtractionTests` resolves it.
scheme_path = File.join(
  Xcodeproj::XCScheme.shared_data_dir(PROJECT_PATH).to_s, 'ScaboPDF.xcscheme'
)
scheme = Xcodeproj::XCScheme.new(scheme_path)
test_action = scheme.test_action

already = test_action.testables.any? do |t|
  t.buildable_references.any? { |r| r.target_name == TEST_TARGET_NAME }
end

if already
  puts "Scheme already lists #{TEST_TARGET_NAME}; leaving as is."
else
  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  test_action.add_testable(testable)
  scheme.save!
  puts "Scheme TestAction now also runs #{TEST_TARGET_NAME}."
end
