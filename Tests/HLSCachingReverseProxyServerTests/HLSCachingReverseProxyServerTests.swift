import AVFoundation
import XCTest

import GCDWebServer
import Nimble
import PINCache
import SafeCollection

import HLSCachingReverseProxyServer

final class HLSCachingReverseProxyServerTests: XCTestCase {
  private var webServer: GCDWebServer!
  private var urlSession: URLSession!
  private var cache: PINCache!
  private var server: HLSCachingReverseProxyServer!

  override func setUp() {
    super.setUp()
    URLProtocolSpy.register()

    self.webServer = GCDWebServer()
    self.cache = PINCache.shared
    self.cache.removeAllObjects()
    self.urlSession = URLSession.shared //(configuration: .default)
    self.server = HLSCachingReverseProxyServer(webServer: self.webServer, urlSession: self.urlSession, cache: self.cache)
    self.server.start(port: 1234)
  }

  override func tearDown() {
    self.server.stop()
    URLProtocolSpy.unregister()
    self.cache.removeAllObjects()
    super.tearDown()
  }

  func testReverseProxyURL_returnsLocalhostURLWithOriginURL() {
    let originURL = URL(string: "https://example.com/hls/playlists/vod.m3u8")!
    let reverseProxyURL = self.server.reverseProxyURL(from: originURL)!
    expect(reverseProxyURL.absoluteString) == "http://127.0.0.1:1234/hls/playlists/vod.m3u8?__hls_origin_url=https://example.com/hls/playlists/vod.m3u8"
  }

  func testReverseProxyURL_returnsNilWhenServerNotRunning() {
    self.server.stop()

    let originURL = URL(string: "https://example.com/hls/playlists/vod.m3u8")!
    let reverseProxyURL = self.server.reverseProxyURL(from: originURL)
    expect(reverseProxyURL).to(beNil())
  }

  func testPlaylist_requestsOriginalPlaylist() {
    // when
    let originURL = URL(string: "https://example.com/hls/playlists/vod.m3u8")!
    let url = self.server.reverseProxyURL(from: originURL)!

    let player = AVPlayer(url: url)
    player.play()

    // then
    expect(URLProtocolSpy.requests.first?.url).toEventually(equal(originURL))
  }

  func testPlaylist_returnsPlaylistWithReverseProxyURLs() {
    // given
    var receivedPlaylist: String?

    // when
    let originURL = URL(string: "https://example.com/hls/playlists/vod.m3u8")!
    let url = self.server.reverseProxyURL(from: originURL)!

    let task = self.urlSession.dataTask(with: url) { data, response, error in
      guard let data = data else { return }
      receivedPlaylist = String(data: data, encoding: .utf8)
    }
    task.resume()

    // then
    expect(receivedPlaylist).toEventuallyNot(beNil())
    let lines = receivedPlaylist?.components(separatedBy: .newlines)

    let englishAudioURI = "http://127.0.0.1:1234/hls/playlists/audio_en.m3u8?__hls_origin_url=https://example.com/hls/playlists/audio_en.m3u8"
    expect(lines?.safe[3]) == "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"English\",LANGUAGE=\"en\",AUTOSELECT=YES,URI=\"\(englishAudioURI)\""

    let koreanAudioURI = "http://127.0.0.1:1234/hls/audio_ko.m3u8?__hls_origin_url=https://example.com/hls/audio_ko.m3u8"
    expect(lines?.safe[4]) == "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Korean\",LANGUAGE=\"ko\",AUTOSELECT=YES,URI=\"\(koreanAudioURI)\""

    let frenchAudioURI = "http://127.0.0.1:1234/audio_fr.m3u8?__hls_origin_url=https://example.com/audio_fr.m3u8"
    expect(lines?.safe[5]) == "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"French\",LANGUAGE=\"fr\",AUTOSELECT=YES,URI=\"\(frenchAudioURI)\""

    let espanolAudioURI = "http://127.0.0.1:1234/audios/audio_es.m3u8?__hls_origin_url=https://example.com/audios/audio_es.m3u8"
    expect(lines?.safe[6]) == "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Espanol\",LANGUAGE=\"es\",AUTOSELECT=YES,URI=\"\(espanolAudioURI)\""

    expect(lines?.safe[10]) == "http://127.0.0.1:1234/hls/playlists/0640_00001.ts?__hls_origin_url=https://example.com/hls/playlists/0640_00001.ts"
    expect(lines?.safe[12]) == "http://127.0.0.1:1234/hls/0640_00002.ts?__hls_origin_url=https://example.com/hls/0640_00002.ts"
    expect(lines?.safe[14]) == "http://127.0.0.1:1234/0640_00003.ts?__hls_origin_url=https://example.com/0640_00003.ts"
    expect(lines?.safe[16]) == "http://127.0.0.1:1234/videos/0640_00004.ts?__hls_origin_url=https://example.com/videos/0640_00004.ts"
  }

  func testSegment_requestsOriginalSegments() {
    // when
    let originURL = URL(string: "https://example.com/hls/playlists/vod.m3u8")!
    let url = self.server.reverseProxyURL(from: originURL)!

    let player = AVPlayer(url: url)
    player.play()

    // then
    let urlStrings = { URLProtocolSpy.requests.compactMap { $0.url?.absoluteString } }
    expect(urlStrings()).toEventually(contain("https://example.com/hls/playlists/0640_00001.ts"))
  }

  func testSegment_returnsCacheIfExists() {
    // given
    self.cache.removeAllObjects()

    // when
    let originURL = URL(string: "https://example.com/hls/playlists/0640_00001.ts")!
    let url = self.server.reverseProxyURL(from: originURL)!

    var responseCount = 0
    self.urlSession.dataTask(with: url) { _, _, _ in responseCount += 1 }.resume()

    // run asynchronously; previous request needs time to cache
    DispatchQueue.main.async {
      self.urlSession.dataTask(with: url) { _, _, _ in responseCount += 1 }.resume()
    }

    // then
    expect(responseCount).toEventually(equal(2))

    let urlStrings = URLProtocolSpy.requests.lazy
      .compactMap { $0.url?.absoluteString }
      .filter { $0 == "https://example.com/hls/playlists/0640_00001.ts" }
    expect(urlStrings).to(haveCount(1))
  }
}


// MARK: - URLProtocolSpy

private final class URLProtocolSpy: URLProtocol {
  static var requests: [URLRequest] = []

  class func register() {
    URLProtocol.registerClass(Self.self)
  }

  class func unregister() {
    URLProtocol.unregisterClass(Self.self)
    self.requests.removeAll()
  }
}

extension URLProtocolSpy {
  override class func canInit(with request: URLRequest) -> Bool {
    return request.url?.host != "127.0.0.1"
  }

  override class func canInit(with task: URLSessionTask) -> Bool {
    return task.currentRequest?.url?.host != "127.0.0.1"
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    Self.requests.append(self.request)

    switch self.request.url?.absoluteString {
    case "https://example.com/hls/playlists/vod.m3u8":
      let playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:13
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",AUTOSELECT=YES,URI="audio_en.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Korean",LANGUAGE="ko",AUTOSELECT=YES,URI="../audio_ko.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="French",LANGUAGE="fr",AUTOSELECT=YES,URI="/audio_fr.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Espanol",LANGUAGE="es",AUTOSELECT=YES,URI="/audios/audio_es.m3u8"
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:12.012,
        0640_00001.ts
        #EXTINF:12.012,
        ../0640_00002.ts
        #EXTINF:12.012,
        /0640_00003.ts
        #EXTINF:12.012,
        /videos/0640_00004.ts
        #EXT-X-ENDLIST
        """
      let data = playlist.data(using: .utf8)!
      let response = URLResponse(url: self.request.url!, mimeType: "application/x-mpegurl", expectedContentLength: data.count, textEncodingName: nil)
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowedInMemoryOnly)
      self.client?.urlProtocol(self, didLoad: data)
      self.client?.urlProtocolDidFinishLoading(self)

    case "https://example.com/hls/playlists/0640_00001.ts":
      let data = "abcdef".data(using: .utf8)!
      let response = URLResponse(url: self.request.url!, mimeType: "video/mp2t", expectedContentLength: data.count, textEncodingName: nil)
      self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowedInMemoryOnly)
      self.client?.urlProtocol(self, didLoad: data)
      self.client?.urlProtocolDidFinishLoading(self)

    default:
      self.client?.urlProtocol(self, didFailWithError: URLProtocolError.unhandled)
    }
  }

  override func stopLoading() {
  }

  enum URLProtocolError: Error {
    case unhandled
  }
}
