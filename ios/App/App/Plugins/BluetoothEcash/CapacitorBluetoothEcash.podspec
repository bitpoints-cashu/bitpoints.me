Pod::Spec.new do |s|
  s.name = 'CapacitorBluetoothEcash'
  s.version = '0.0.1'
  s.summary = 'Bluetooth Ecash Plugin'
  s.license = 'MIT'
  s.homepage = 'https://github.com/bitpoints.me'
  s.author = 'Bitpoints.me'
  s.source = { :path => '.' }
  s.source_files = '*.swift', '*.m'
  s.dependency 'Capacitor'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
end
