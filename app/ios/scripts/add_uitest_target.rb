#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds (idempotently) the ScaboPDFUITests UI-test target to ScaboPDF.xcodeproj
# and repairs the shared scheme's TestAction to reference it. Run with the
# CocoaPods-bundled xcodeproj gem (no Python anywhere in the toolchain):
#
#   cd app/ios && bundle exec ruby scripts/add_uitest_target.rb
#
# The resulting project + scheme changes are the permanent, checked-in artifact;
# this script documents how they were produced and lets a fresh clone or a
# future restructure reproduce them deterministically.
#
# Why a UI-test target (not a unit test): the E2E methodology drives the REAL
# app — picker included — and reads the accessibility tree as VoiceOver does,
# which only XCUITest can do. Fixtures are never bundled here (copyright,
# gitignored); they are seeded host-side into the Simulator in a later step.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ScaboPDF.xcodeproj')
APP_TARGET_NAME = 'ScaboPDF'
TEST_TARGET_NAME = 'ScaboPDFUITests'
TEST_SOURCE = 'ScaboPDFUITests.swift'

project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
raise "App target #{APP_TARGET_NAME} not found" if app_target.nil?

test_target = project.targets.find { |t| t.name == TEST_TARGET_NAME }

if test_target.nil?
  puts "Creating UI-test target #{TEST_TARGET_NAME}…"
  test_target = project.new_target(
    :ui_test_bundle, TEST_TARGET_NAME, :ios, '15.1', project.products_group, :swift
  )

  # Source group + file. The group carries the directory path
  # (SOURCE_ROOT/ScaboPDFUITests), so the file is referenced by its bare name to
  # avoid doubling the path component.
  group = project.main_group.find_subpath(TEST_TARGET_NAME, true)
  group.set_source_tree('SOURCE_ROOT')
  group.set_path(TEST_TARGET_NAME)
  file_ref = group.find_file_by_path(TEST_SOURCE) || group.new_file(TEST_SOURCE)
  unless test_target.source_build_phase.files_references.include?(file_ref)
    test_target.add_file_references([file_ref])
  end

  # The test target automates the app and must build after it.
  test_target.add_dependency(app_target)
else
  puts "UI-test target #{TEST_TARGET_NAME} already exists; updating settings…"
end

# Build settings for every configuration. GENERATE_INFOPLIST_FILE avoids a
# checked-in Info.plist; TEST_TARGET_NAME tells XCUITest which app to drive.
test_target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.scabo.scabopdf.uitests'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['TEST_TARGET_NAME'] = APP_TARGET_NAME
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

# --- Repair the shared scheme's TestAction ---------------------------------
# The RN template left a TestableReference pointing at a ScaboPDFTests target
# that does not exist in this project. Replace the whole testables list with the
# new UI-test target so `xcodebuild test -scheme ScaboPDF` runs it.
scheme_path = File.join(
  Xcodeproj::XCScheme.shared_data_dir(PROJECT_PATH).to_s, 'ScaboPDF.xcscheme'
)
scheme = Xcodeproj::XCScheme.new(scheme_path)
test_action = scheme.test_action

# Drop any existing (possibly dangling) testables.
test_action.testables.each do |testable|
  testable.xml_element.parent.delete_element(testable.xml_element)
end

# Add the repaired reference to the UI-test target.
testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
test_action.add_testable(testable)

scheme.save!
puts "Scheme TestAction repaired -> #{TEST_TARGET_NAME}"
