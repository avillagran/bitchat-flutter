#
# Local bluetooth_low_energy_bitchat override with lazy BLE initialization
# to fix macOS TCC crash on app startup.
#
Pod::Spec.new do |s|
  s.name             = 'bluetooth_low_energy_darwin'
  s.version          = '6.0.0'
  s.summary          = 'bluetooth_low_energy_bitchat with lazy BLE initialization'
  s.description      = <<-DESC
Local override of bluetooth_low_energy_bitchat that defers CBCentralManager
and CBPeripheralManager creation until initialize() is called from Dart.
This prevents macOS TCC crashes when BLE permissions are not yet granted.
                       DESC
  s.homepage         = 'https://github.com/yanshouwang/bluetooth_low_energy'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'yanshouwang' => 'yanshouwang@outlook.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.ios.dependency 'Flutter'
  s.ios.deployment_target = '12.0'

  s.osx.dependency 'FlutterMacOS'
  s.osx.deployment_target = '10.11'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
