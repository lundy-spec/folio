// Renders an HTML file to a PNG at an exact pixel size, via WebKit.
// Usage: swift render.swift <in.html> <out.png> <width> <height>
import AppKit
import WebKit

let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let width = CGFloat(Double(args[3])!), height = CGFloat(Double(args[4])!)

final class Renderer: NSObject, WKNavigationDelegate {
	let view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
	func start() {
		view.navigationDelegate = self
		view.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent().deletingLastPathComponent())
	}
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// Give webfonts/images a moment to settle before capturing.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
			let config = WKSnapshotConfiguration()
			config.rect = NSRect(x: 0, y: 0, width: width, height: height)
			config.snapshotWidth = NSNumber(value: Double(width))
			webView.takeSnapshot(with: config) { image, error in
				guard let image, let tiff = image.tiffRepresentation,
					let rep = NSBitmapImageRep(data: tiff),
					let png = rep.representation(using: .png, properties: [:]) else {
					print("snapshot failed: \(String(describing: error))"); exit(1)
				}
				try! png.write(to: output)
				print("wrote \(output.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
				exit(0)
			}
		}
	}
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = Renderer()
renderer.start()
app.run()
