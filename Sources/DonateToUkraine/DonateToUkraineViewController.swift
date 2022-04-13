//
//  TelegraphKit.swift
//  Nice Photon
//
//  Created by Oleg Dreyman on 2/2/21.
//

import UIKit
import WebKit

// special thanks to Daniel Jalkut:
// https://indiestack.com/2018/10/supporting-dark-mode-in-app-web-content/

public final class DonateToUkraineViewController: UIViewController {

    static private let scriptsFetcher = ScriptsNetworking()

    public var completion: (UkraineDonation) -> Void = { _ in }
    public var onFailure: () -> Void = { }

    public let loadingIndicator = UIActivityIndicatorView(style: .large)
    let failedConnectionView = EmptyStateView(contents: .init(elements: [
        .title("Failed to load"),
        .text("Please check your internet connection and try again later.")
    ]))
    lazy var failedPaymentView = EmptyStateView(contents: .init(elements: [
        .title("Payment failed"),
        .text("Please check your credentials and try again later."),
        .button("Try again", { [weak self] in self?.loadMain() })
    ]))
    let closeButton: UIButton = {
        $0.setImage(UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate), for: .normal)
        $0.tintColor = UIColor.black
        $0.alpha = 0.3
        $0.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return $0
    }(UIButton())
    
    public let url: URL
    public let webView = ListeningWebView()

    private var currentAmount: String?
    private var scripts: Promise<String> = .init()

    static let uaHelpURL = URL(string: "https://uahelp.monobank.ua")!

    public convenience init(completion: @escaping (UkraineDonation) -> Void) {
        self.init(url: Self.uaHelpURL)
        self.completion = completion
    }

    fileprivate init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        scripts = Self.scriptsFetcher.fetchJSScripts()
        
        view.addSubview(webView) {
            $0.anchors.edges.pin()
        }
        
        view.addSubview(loadingIndicator) {
            $0.anchors.center.align()
            $0.alpha = 0
        }
        
        view.addSubview(failedConnectionView) {
            $0.anchors.centerY.align(offset: -25)
            $0.anchors.edges.readableContentPin(insets: .init(top: 0, left: 32, bottom: 0, right: 32), axis: .horizontal)
            $0.isHidden = true
        }

        view.addSubview(failedPaymentView) {
            $0.anchors.centerY.align(offset: -25)
            $0.anchors.edges.readableContentPin(insets: .init(top: 0, left: 32, bottom: 0, right: 32), axis: .horizontal)
            $0.isHidden = true
        }

        view.addSubview(closeButton) {
            $0.anchors.top.safeAreaPin()
            $0.anchors.leading.pin()
        }
        closeButton.addTarget(self, action: #selector(didPressDone), for: .touchUpInside)

        overrideUserInterfaceStyle = .light
        view.backgroundColor = .systemBackground
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.3 Mobile/15E148 Safari/604.1"
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.alpha = 0

        webView.configuration.userContentController.add(self, name: "buttonClicked")

        self.navigationItem.backButtonTitle = ""
        
        webView.navigationDelegate = self
        loadMain()
    }

    func finish(donation: UkraineDonation) {
        UkraineDonationTracking.didDonate(donation: donation)
        completion(donation)
    }
    
    @objc
    func didPressDone() {
        self.close { }
    }

    func close(completion: @escaping () -> Void) {
        presentingViewController?.dismiss(animated: true, completion: completion)
    }
}

extension DonateToUkraineViewController {
    func loadMain() {
        currentAmount = nil
        failedConnectionView.isHidden = true
        failedPaymentView.isHidden = true
        webView.alpha = 0

        let request = URLRequest(url: url)
        webView.load(request)
        startLoading()
    }

    func startLoading() {
        loadingIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            animated {
                self.loadingIndicator.alpha = 1.0
            }
        }
    }
}

extension DonateToUkraineViewController: WKScriptMessageHandler {
    var getAmountJS: Promise<String> {
        scripts.then({ $0 + "\n getDonationAmount()" })
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.getAmountJS.then { script in
            self.webView.evaluateJavaScript(script) { result, error in
                guard let result = result as? String else {
                    return
                }
                if result != "invalid" {
                    self.currentAmount = result
                }
            }
        }
    }
}

extension DonateToUkraineViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.absoluteString.contains("mbnk.biz") {
            guard currentAmount != nil else {
                animated {
                    self.webView.alpha = 0.0
                }
                self.failedConnectionView.isHidden = false
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.loadingIndicator.stopAnimating()
        webView.alpha = 0
        self.failedConnectionView.isHidden = false
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.loadingIndicator.stopAnimating()
        webView.alpha = 0
        self.failedConnectionView.isHidden = false
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.loadingIndicator.startAnimating()
        animated {
            self.webView.alpha = 0.0
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.absoluteString.contains("done") == true {
            checkForSuccess()
            return
        }
        if let url = webView.url, !url.absoluteString.contains("mbnk.biz") {
            self.webView.registerClickEventObserver()
        }
        self.loadingIndicator.stopAnimating()
        animated {
            self.webView.alpha = 1.0
        }
    }

    func scheduleCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkForSuccess()
        }
    }

    func paymentDidSucceed() {
        guard let receiptId = webView.url?.lastPathComponent, let amount = self.currentAmount, let amountUAH = UkraineDonation.AmountUAH(rawValue: amount) else {
            paymentDidFail()
            return
        }
        self.loadingIndicator.stopAnimating()

        let donation = UkraineDonation(amount: amountUAH, receiptId: receiptId, donatedAt: Date())

        close(completion: { self.finish(donation: donation) })
    }

    func paymentDidFail() {
        animated {
            self.webView.alpha = 0.0
        }
        self.loadingIndicator.stopAnimating()
        self.failedPaymentView.isHidden = false
    }

    var checkForStatusJS: Promise<String> {
        scripts.then({ $0 + "\npaymentStatus()" })
    }

    enum PaymentStatusJS: String {
        case success, failure, waiting
    }

    func checkForSuccess() {
        checkForStatusJS.then { script in
            self.webView.evaluateJavaScript(script) { result, error in
                guard let resultString = result as? String, let status = PaymentStatusJS(rawValue: resultString) else {
                    self.scheduleCheck()
                    return
                }

                switch status {
                case .success:
                    self.paymentDidSucceed()
                case .failure:
                    self.paymentDidFail()
                case .waiting:
                    self.scheduleCheck()
                }
            }
        }
    }
}

public class ListeningWebView: WKWebView {
    public func registerClickEventObserver() {
        let clickEventScript = """
document.addEventListener("click", function(evnt){
    window.webkit.messageHandlers.buttonClicked.postMessage("hello");
});
"""
        self.evaluateJavaScript(clickEventScript)
    }
}

// https://stackoverflow.com/a/47357277
extension UIColor {
    var hexString: String {
        let cgColorInRGB = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let colorRef = cgColorInRGB.components
        let r = colorRef?[0] ?? 0
        let g = colorRef?[1] ?? 0
        let b = ((colorRef?.count ?? 0) > 2 ? colorRef?[2] : g) ?? 0
        let a = cgColor.alpha

        var color = String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )

        if a < 1 {
            color += String(format: "%02lX", lroundf(Float(a * 255)))
        }

        return color
    }
}

final class EmptyStateView: UIView {
        
    struct Contents {
        enum Element {
            case text(String)
            case title(String)
            case button(String, () -> Void)
        }
        
        var elements: [Element]
    }
    
    let stack = UIStackView()
    private var handlers: [UIButton: () -> Void] = [:]
    
    let contents: Contents
    
    init(contents: Contents) {
        self.contents = contents
        super.init(frame: .zero)
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        addSubview(stack)
        with(stack) {
            $0.anchors.edges.pin()
            $0.axis = .vertical
            $0.distribution = .equalSpacing
            $0.spacing = 8
        }
        
        for element in contents.elements {
            switch element {
            case .title(let string):
                let label = with(UILabel()) {
                    $0.text = string
                    $0.font = .boldSystemFont(ofSize: 22)
                    $0.numberOfLines = 0
                    $0.textAlignment = .center
                }
                stack.addArrangedSubview(label)
            case .text(let string):
                let label = with(UILabel()) {
                    $0.text = string
                    $0.font = .boldSystemFont(ofSize: 17)
                    $0.numberOfLines = 0
                    $0.textAlignment = .center
                    $0.textColor = .secondaryLabel
                }
                stack.addArrangedSubview(label)
            case .button(let title, let handler):
                let button = with(UIButton(type: .system)) {
                    $0.setTitle(title, for: .normal)
                    $0.titleLabel?.font = .boldSystemFont(ofSize: 17)
                }
                self.handlers[button] = handler
                button.addTarget(self, action: #selector(buttonDidPress(_:)), for: .touchUpInside)
                stack.addArrangedSubview(button)
            }
        }
    }

    @objc
    func buttonDidPress(_ button: UIButton) {
        handlers[button]?()
    }
}

func animated(_ block: @escaping () -> (), completion: @escaping () -> () = { }) {
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
        block()
    } completion: { (isCompleted) in
        if isCompleted {
            completion()
        }
    }
}

fileprivate final class ScriptsNetworking {

    let urlSession = URLSession.shared

    enum ExecuteError: Error {
        case invalidResponse(URLResponse?)
        case badStatusCode(Int)
        case notAString(Data?)
        case invalidURL
    }

    func fetchJSScripts() -> Promise<String> {
        // scripts are used to parse donation amount & success status. they are fetched remotely to ensure the library remains functional
        // even if monobank's webpage structure changes
        guard let url = URL(string: "https://raw.githubusercontent.com/dreymonde/uahelp-js-scripts/main/scripts.js") else {
            return .init(error: ExecuteError.invalidURL)
        }
        let request = URLRequest(url: url)
        let promise = Promise<String>()
        urlSession.dataTask(with: request) { data, response, error in

            if let error = error {
                return promise.reject(error)
            }

            guard let string = String(data: data ?? .init(), encoding: .utf8) else {
                return promise.reject(ExecuteError.notAString(data))
            }

            promise.fulfill(string)
        }.resume()
        return promise
    }

}
