//
//  AppDelegate.swift
//  CurrencyConverter
//
//  Created by Chris Eidhof on 29-08-17.
//  Copyright © 2017 Chris Eidhof. All rights reserved.
//

import UIKit

let ratesURL = URL(string: "http://api.fixer.io/latest?base=EUR")!

struct Converter: Codable {
    var inputText: String? = "100"
    var rate: Double
    var currency: String

    var inputAmount: Double? {
        guard let text = inputText, let number = Double(text) else {
            return nil
        }
        return number
    }
    
    var outputAmount: Double? {
        guard let input = inputAmount else { return  nil }
        return input * rate
    }

    var viewController: ViewController<State.Message> {
        return .viewController(View.stackView(views: [
            View.textField(text: inputText ?? "", backgroundColor: inputAmount == nil ? .red : .white, onChange: State.Message.setInputText),
            View.label(text: outputAmount.map { "\($0) \(currency)" } ?? "...", font: UIFont.systemFont(ofSize: 20))
            ]))
    }
}

struct State: RootComponent {
    private var rates: [String: Double]?
    var converter: Converter?
    
    enum Message {
        case setInputText(String?)
        case dataReceived(Data?)
        case reload
        case currencySelected(String)
    }
    
    mutating func send(_ message: Message) -> [Command<Message>] {
        switch message {
        case .setInputText(let text):
            converter?.inputText = text
            return []
        case .dataReceived(let data):
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let dict = json as? [String:Any],
                let dataDict = dict["rates"] as? [String:Double] else { return [] }
            self.rates = dataDict
            return []
        case .reload:
            return [.request(URLRequest(url: ratesURL), available: Message.dataReceived)]
        case .currencySelected(let currency):
            converter = Converter(inputText: "100", rate: rates![currency]!, currency: currency)
            return []
        }
    }
    
    var viewController: ViewController<State.Message> {
        let viewController: ViewController<Message>
        if let r = rates {
            let cells: [TableViewCell<Message>] = r.keys.sorted().map { currency in
                TableViewCell(identity: currency, text: currency, onSelect: Message.currencySelected(currency), onDelete: nil)
            }
            viewController = .tableViewController(TableView(items: cells))
        } else {
            viewController = .viewController(View.label(text: "No rates loaded", font: UIFont.systemFont(ofSize: 20)))
        }
        var viewControllers = [
            NavigationItem(title: "Rates", leftBarButtonItem: nil, rightBarButtonItems: [
                BarButtonItem.system(.refresh, action: .reload)
                ], leftItemsSupplementsBackButton: false, viewController: viewController)
        ]
        if let c = converter {
            viewControllers.append(NavigationItem(title: c.currency, leftBarButtonItem: nil, rightBarButtonItems: [], leftItemsSupplementsBackButton: false, viewController: c.viewController))
        }
        return ViewController.navigationController(viewControllers: viewControllers)
    }
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var driver: Driver<State>?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        driver = Driver(State())
        window?.rootViewController = driver?.viewController
        window?.makeKeyAndVisible()
        return true
    }

}

