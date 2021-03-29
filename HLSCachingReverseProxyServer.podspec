Pod::Spec.new do |s|
  s.name             = "HLSCachingReverseProxyServer"
  s.version          = "0.2.0"
  s.summary          = "A simple local reverse proxy server for HLS segment cache"
  s.homepage         = "https://github.com/StyleShare/HLSCachingReverseProxyServer"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "StyleShare" => "dev-ios@styleshare.kr" }
  s.source           = { :git => "https://github.com/StyleShare/HLSCachingReverseProxyServer.git",
                         :tag => s.version.to_s }
  s.source_files = "Sources/**/*.{swift,h,m}"
  s.frameworks   = "Foundation"
  s.swift_version = "5.1"

  s.dependency "GCDWebServer", "~> 3.5"
  s.dependency "PINCache", "~> 3.0"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.11"
  s.tvos.deployment_target = "9.0"
end
