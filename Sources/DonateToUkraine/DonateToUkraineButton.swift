//
//  DonateToUkraineButton.swift
//
//
//  Created by Oleg Dreyman on 1/22/21.
//

import UIKit

public final class DonateToUkraineButton: UIButton {

    private var _contextViewController: UIViewController!

    public var contextViewController: UIViewController {
        get {
            guard let vc = _contextViewController else {
                preconditionFailure("Make sure to set `contextViewController` before using")
            }
            return vc
        }
        set {
            _contextViewController = newValue
        }
    }

    public var didOpen: () -> Void = { }
    public var completion: (UkraineDonation) -> Void = { _ in }

    public struct Style {
        public var backgroundColor: UIColor
        public var tintColor: UIColor
        public var borderColor: UIColor

        public static let black = Style(backgroundColor: .black, tintColor: .white, borderColor: .clear)
        public static let white = Style(backgroundColor: .white, tintColor: .black, borderColor: .clear)
        public static func `dynamic`(light: Style, dark: Style) -> Style {
            return Style(
                backgroundColor: .init(dynamicProvider: { (traitCollection) in
                    if traitCollection.userInterfaceStyle == .dark {
                        return dark.backgroundColor
                    } else {
                        return light.backgroundColor
                    }
                }),
                tintColor: .init(dynamicProvider: { (traitCollection) in
                    if traitCollection.userInterfaceStyle == .dark {
                        return dark.tintColor
                    } else {
                        return light.tintColor
                    }
                }),
                borderColor: .init(dynamicProvider: { (traitCollection) in
                    if traitCollection.userInterfaceStyle == .dark {
                        return dark.borderColor
                    } else {
                        return light.borderColor
                    }
                })
            )
        }
        public static let automatic = Style.dynamic(light: .black, dark: .white)

        public static let blackOutline = Style(backgroundColor: .black, tintColor: .white, borderColor: .white)
        public static let whiteOutline = Style(backgroundColor: .white, tintColor: .black, borderColor: .black)
        public static let automaticOutline = Style.dynamic(light: .whiteOutline, dark: .blackOutline)
    }

    public struct Variant {
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public var rawValue: String

        public static let donate = Variant(rawValue: "🇺🇦 Donate to Ukraine")
    }

    @available(*, deprecated)
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup(style: .automatic, variant: .donate)
    }

    public convenience init(style: Style, variant: Variant = .donate) {
        self.init(type: .system)
        setup(style: style, variant: variant)
    }

    private func setup(style: Style, variant: Variant) {
        layer.cornerRadius = 8
        clipsToBounds = true
        setBackgroundColor(style.backgroundColor, for: .normal)
        tintColor = style.tintColor
        if style.borderColor != .clear {
            layer.borderColor = style.borderColor.cgColor
            layer.borderWidth = 1
        }
        setTitle(variant.rawValue, for: .normal)
        self.anchors.height.equal(44)

        self.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
    }

    public convenience init(style: Style, variant: Variant = .donate, contextViewController: UIViewController) {
        self.init(style: style, variant: variant)
        self.contextViewController = contextViewController
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup(style: .automatic, variant: .donate)
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setTargetAction()
    }

    private func setTargetAction() {
        addTarget(self, action: #selector(_didTouchUpInside), for: .touchUpInside)
    }

    @objc
    private func _didTouchUpInside() {
        didOpen()
        let donateVC = DonateToUkraineViewController(completion: completion)
        contextViewController.present(donateVC, animated: true)
    }
}

// Original authors: Kickstarter
// https://github.com/kickstarter/Kickstarter-Prelude/blob/master/Prelude-UIKit/UIButton.swift

extension DonateToUkraineButton {
    /**
     Sets the background color of a button for a particular state.
     - parameter backgroundColor: The color to set.
     - parameter state:           The state for the color to take affect.
     */
    func setBackgroundColor(_ backgroundColor: UIColor, for state: UIControl.State) {
        DonateToUkraineButton.setBackgroundColor(backgroundColor, to: self, for: state)
    }

    static func setBackgroundColor(_ backgroundColor: UIColor, to button: UIButton, for state: UIControl.State) {
        button.setBackgroundImage(NiceImage.pixel(ofColor: backgroundColor), for: state)
    }
}

enum NiceImage {
    /**
     - parameter color: A color.
     - returns: A 1x1 UIImage of a solid color.
     */
    static func pixel(ofColor color: UIColor) -> UIImage {
        if #available(iOS 12.0, *) {
            let lightModeImage = NiceImage.generatePixel(ofColor: color, userInterfaceStyle: .light)
            let darkModeImage = NiceImage.generatePixel(ofColor: color, userInterfaceStyle: .dark)
            lightModeImage.imageAsset?.register(darkModeImage, with: UITraitCollection(userInterfaceStyle: .dark))
            return lightModeImage
        } else {
            return generatePixel(ofColor: color)
        }
    }

    @available(iOS 12.0, *)
    static private func generatePixel(ofColor color: UIColor, userInterfaceStyle: UIUserInterfaceStyle) -> UIImage {
        var image: UIImage!
        if #available(iOS 13.0, *) {
            UITraitCollection(userInterfaceStyle: userInterfaceStyle).performAsCurrent {
                image = NiceImage.generatePixel(ofColor: color)
            }
        } else {
            image = NiceImage.generatePixel(ofColor: color)
        }
        return image
    }

    static private func generatePixel(ofColor color: UIColor) -> UIImage {
        let pixel = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)

        UIGraphicsBeginImageContext(pixel.size)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }

        context.setFillColor(color.cgColor)
        context.fill(pixel)

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
