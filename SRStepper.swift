//
//  SRStepper.swift
//  SRStepper
//
//  Created by Sergei Rosliakov on 26.06.2020.
//

import UIKit

struct StepperStyle {
    
    // MARK: - Properties

    let cornerRadius: CGFloat
    let minusImage: UIImage
    let plusImage: UIImage
    let color: UIColor
    let highlightedColor: UIColor
    let disabledColor: UIColor
    let deviderColor: UIColor
    
    // MARK: - Default styles
    
    static let defaultStyle = StepperStyle(
        cornerRadius: 5,
        minusImage: UIImage(named: "minus") ?? UIImage(),
        plusImage: UIImage(named: "plus") ?? UIImage(),
        color: .lightGray,
        highlightedColor: .darkGray,
        disabledColor: .systemGray6,
        deviderColor: .white
    )
}

///Customizable UIStepper
class Stepper: UIControl {

    // MARK: - Public properties

    var isContinuous: Bool = true // if YES, value change events are sent any time the value changes during interaction. default = YES

    var autorepeat: Bool = true // if YES, press & hold repeatedly alters value. default = YES

    var wraps: Bool = false // if YES, value wraps from min <-> max. default = NO

    
    var value: Double = 0 // default is 0. sends UIControlEventValueChanged. clamped to min/max

    var minimumValue: Double = 0 // default 0. must be less than maximumValue

    var maximumValue: Double = 100 // default 100. must be greater than minimumValue

    var stepValue: Double = 1 // default 1. must be greater than 0

    // MARK: - Private properties

    private let plusButton = UIButton()
    private let minusButton = UIButton()
    private let devider = UIView()
    
    private var style: StepperStyle?
    private let deviderWidth: CGFloat = 2
    
    private var timer: Timer?
    private var timerFastSpeed: Timer?

    private var longPressedButton: UIButton?
    
    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
        setupView()
    }
    
    // MARK: - Lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let buttonsWidth = (frame.width / 2)
        let height = frame.height
        
        minusButton.frame = CGRect(x: 0, y: 0, width: buttonsWidth, height: height)
        devider.frame = CGRect(x: minusButton.frame.maxX, y: 0, width: deviderWidth, height: height)
        plusButton.frame = CGRect(x: devider.frame.maxX, y: 0, width: buttonsWidth, height: height)
    }
    
    // MARK: - Public methods
    
    func applyStyle(_ style: StepperStyle) {
        self.style = style
        
        layer.cornerRadius = style.cornerRadius
        devider.backgroundColor = style.deviderColor
        
        minusButton.setImage(style.minusImage, for: .normal)
        plusButton.setImage(style.plusImage, for: .normal)
        
        minusButton.setBackgroundImage(imageFromColor(style.color), for: .normal)
        minusButton.setBackgroundImage(imageFromColor(style.highlightedColor), for: .highlighted)
        minusButton.setBackgroundImage(imageFromColor(style.disabledColor), for: .disabled)
        
        plusButton.setBackgroundImage(imageFromColor(style.color), for: .normal)
        plusButton.setBackgroundImage(imageFromColor(style.highlightedColor), for: .highlighted)
        plusButton.setBackgroundImage(imageFromColor(style.disabledColor), for: .disabled)
    }
    
    // MARK: - Private methods

    private func setupView() {
        
        addSubview(minusButton)
        addSubview(devider)
        addSubview(plusButton)
        
        clipsToBounds = true

        minusButton.addTarget(self, action: #selector(minusAction), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plusAction), for: .touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(begin(gesture:)))
        let longPress2 = UILongPressGestureRecognizer(target: self, action: #selector(begin(gesture:)))

        plusButton.addGestureRecognizer(longPress)
        minusButton.addGestureRecognizer(longPress2)
        
        changeStateIfNeeded()
    }
     
    // MARK: - Gestures
    
    @objc private func begin(gesture: UILongPressGestureRecognizer) {
        
        guard let button = gesture.view as? UIButton else { return }
        
        if gesture.state == .began {
            longPress(button: button, ended: false)
        } else if
            gesture.state == .ended ||
                gesture.state == .cancelled ||
                (gesture.state == .changed && !gesture.view!.bounds.contains(gesture.location(in: button))) {
            longPress(button: button, ended: true)
        }
    }
    
    //MARK: - Timers
    
    private func longPress(button: UIButton, ended: Bool) {
        
        guard !ended, let selector = getSelectorForButton(button) else {
            timer?.invalidate()
            timer = nil
            timerFastSpeed?.invalidate()
            timerFastSpeed = nil
            longPressedButton = nil
            button.setBackgroundImage(imageFromColor(style?.color), for: .normal)
            changeStateIfNeeded()
            return
        }
        
        longPressedButton = button

        if autorepeat {
            timer = Timer.scheduledTimer(
                timeInterval: 0.2,
                target: self,
                selector: selector,
                userInfo: nil,
                repeats: true)
            
            timerFastSpeed = Timer.scheduledTimer(
                timeInterval: 2.0,
                target: self,
                selector: #selector(enableFastSpeed),
                userInfo: nil,
                repeats: false)
        }
        button.setBackgroundImage(imageFromColor(style?.highlightedColor), for: .normal)
    }
    
    
    @objc private func enableFastSpeed() {
        guard let selector = getSelectorForButton(longPressedButton ?? UIButton()) else { return }
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 0.08, target: self, selector: selector, userInfo: nil, repeats: true)
    }
        
    //MARK: - Actions
    
    @objc private func plusAction() {
        defer { changeStateIfNeeded() }
        
        if value == maximumValue {
            value = minimumValue
            return
        }
        
        guard (value + stepValue) <= maximumValue else {
            value = maximumValue
            return
        }
        value += stepValue
    }
    
    @objc private func minusAction() {
        defer { changeStateIfNeeded() }
        
        if value == minimumValue, wraps {
          value = maximumValue
            return
        }
        
        guard (value - stepValue) >= minimumValue else {
            value = minimumValue
            return
        }
        value -= stepValue
    }
    
    private func changeStateIfNeeded() {
        
        if value == minimumValue, !wraps {
            minusButton.isEnabled = false
        } else {
            minusButton.isEnabled = true
        }
        
        if value == maximumValue, !wraps {
            plusButton.isEnabled = false
        } else {
            plusButton.isEnabled = true
        }
        
        if isContinuous, longPressedButton != nil {
            sendActions(for: .valueChanged)
        } else if !isContinuous, longPressedButton != nil {
            return
        } else {
            sendActions(for: .valueChanged)
        }
    }
    
    //MARK: - Helpers
    
    private func getSelectorForButton(_ button: UIButton) -> Selector? {
        let selector: Selector
        switch button {
        case plusButton:
            selector = #selector(plusAction)
        case minusButton:
            selector = #selector(minusAction)
        default:
            return nil
        }
        return selector
    }
    
    private func imageFromColor(_ color: UIColor?) -> UIImage? {
        let rect = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        (color ?? .clear).setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
