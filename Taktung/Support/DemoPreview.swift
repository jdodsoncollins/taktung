import Foundation

/// A bundled sample website, rendered by the same WebKit preview path as live sites.
/// The reserved .invalid address never reaches the network.
enum DemoPreview {
    static let pageURL = "https://preview.taktung.invalid"
    static func comparisonHTML(deploymentID: String, route: String) -> String {
        let baseline = !deploymentID.hasSuffix("_0")
        var page = html
        if baseline {
            page = page.replacingOccurrences(of: "Thoughtful work.", with: "Thoughtful design.")
                .replacingOccurrences(of: "#c4784a", with: "#659f93")
                .replacingOccurrences(of: "Digital experiences shaped with care.", with: "Websites shaped with care.")
        }
        if route != "/" {
            page = page.replacingOccurrences(of: "A clearer starting point.", with: "A new perspective.")
        }
        return page
    }
    static let html = """
    <!doctype html><html lang="en"><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Example Portfolio</title><style>
    *{box-sizing:border-box}body{margin:0;background:#f5f0e8;color:#29241f;font:16px -apple-system,sans-serif}
    header{display:flex;justify-content:space-between;padding:26px 22px;font-size:12px;font-weight:700}
    main{padding:20px 22px}small{font-size:10px;letter-spacing:2px;color:#87614a}
    h1{font-size:44px;line-height:1.05;letter-spacing:-2px;margin:20px 0}p{font-size:14px;line-height:1.6;color:#6d6258}
    .art{height:230px;margin:30px 0;background:#c4784a;position:relative;overflow:hidden;border-radius:4px}
    .art:before{content:'';position:absolute;width:190px;height:190px;border:28px solid #f5f0e8;border-radius:50%;left:30px;top:50px}
    .art:after{content:'';position:absolute;width:150px;height:210px;background:#29241f;right:-20px;top:-30px;transform:rotate(25deg)}
    h2{font-size:20px}section{border-top:1px solid #d8ccbe;padding:18px 0}footer{padding:22px;font-size:11px;color:#6d6258}
    </style><header><span>EXAMPLE STUDIO</span><span>WORK / ABOUT</span></header>
    <main><small>INDEPENDENT DESIGN & DEVELOPMENT</small><h1>Thoughtful work.<br>Built to last.</h1>
    <p>Digital experiences shaped with care. A small selection of recent projects.</p>
    <div class="art"></div><section><small>01 / SELECTED WORK</small><h2>A clearer starting point.</h2>
    <p>Brand, website, and a better way to find what matters.</p></section>
    <section><small>02 / PROCESS</small><h2>Simple ideas. Useful details.</h2></section></main>
    <footer>EXAMPLE STUDIO · SAMPLE WEBSITE</footer></html>
    """
}
