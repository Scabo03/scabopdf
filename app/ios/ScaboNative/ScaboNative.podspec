require 'json'
package = JSON.parse(File.read(File.join(__dir__, '..', '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = "ScaboNative"
  s.version        = package['version']
  s.summary        = "ScaboPDF native bridge: accessible reading view (Fabric) + accessibility settings (TurboModule)."
  s.homepage       = "https://github.com/Scabo03/scabopdf"
  s.license        = { :type => "MIT" }
  s.author         = { "Scabo03" => "scabi03@gmail.com" }
  s.platforms      = { :ios => "15.1" }
  s.source         = { :path => "." }
  s.source_files   = "**/*.{h,m,mm,swift}"
  # Keep the Fabric component header out of the umbrella: it imports
  # RCTViewComponentView.h which transitively pulls C++ (<atomic>), and the
  # module is compiled as ObjC. The .mm consumes the header directly; Swift
  # never needs it.
  s.private_header_files = "ScaboReadingViewComponentView.h"
  s.requires_arc   = true
  s.swift_version  = "5.0"
  s.module_name    = "ScaboNative"

  # Pulls React-Core, React-RCTFabric, React-Codegen and the rest of the
  # New-Architecture toolchain. Provided by the host Podfile via
  # react_native_pods.rb (loaded with `require_relative` in the app Podfile).
  install_modules_dependencies(s)
end
