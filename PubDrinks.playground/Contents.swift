/***
 
 Pub Drinks Exercise
 
 Time taken: 3.5 hours
 
 Example output:
 
 """
 DRINK: Beer £3.99
 DRINK: Beer £3.99
 DRINK: Spirit/Liqueur (Double) £13.98
 DRINK: Bottle of Wine £29.95
 
 OFFERS APPLIED:
 Buy one drink get two free on Fridays starting at 6pm (-£7.98)
 TOTAL: £43.93
 """
 
 Notes:
 This is all in one file for the exercise but in a real system this would be
 split into multiple files.
 
 Key points:
 - See bottom of file under "Examples" for example usage (probably easiest to
 look at this first). The tests also demonstrate the requirements pass.
 
 - 'Transactions' are made by adding drinks and then calling 'finalise()'
 which returns a cost and a description. The description is a list of the drinks
 and the offers applied.
 
 - Composable. Drinks are composed at runtime of a base type and any combination
 of extras. Using decorator pattern which is abstracted away inside Transaction
 for ease of use from caller.
 
 - Extensible. Just add another case to the 'Offer' enum for new offers, or
 another case to the 'Drink' enum for new drink types, and if there's another
 extra (eg, ice, lemonade, fruit) you can just implement 'DrinkDecorator'.
 
 - Type safe. Passes enums around and not strings
 
 IMPROVEMENTS / ASSUMPTIONS:
 
 - The description code is fairly dense but in a real system we would be passing
 around types and not composing strings for the console.
 
 - Would use localisation in a production environment, have assumed currency as £
 and strings and days of week are in English.
 
 - Since we can decorate a drink with any options there is no current protection
 against unsuitable combinations (ie, making a drink both a Double and a Bottle
 doesn't really make sense)
 
 */

import Foundation

protocol DrinkProtocol {
    var description: String { get }
    var cost: Double { get }
}

enum Drink: String  {
    case soft = "Soft drink"
    case beer = "Beer"
    case cider = "Cider"
    case wine = "Wine"
    case spiritsAndLiqueurs = "Spirit/Liqueur"
}

extension Drink: DrinkProtocol {
    var description: String {
        return self.rawValue
    }
    
    var cost: Double {
        switch self {
        case .soft:
            return 0.99
        case .beer:
            return 3.99
        case .cider:
            return 2.99
        case .wine:
            return 5.99
        case .spiritsAndLiqueurs:
            return 7.99
        }
    }
}

class DrinkDecorator: DrinkProtocol {
    var decoratingDrink: DrinkProtocol?
    
    var description: String {
        return decoratingDrink?.description ?? ""
    }
    var cost: Double {
        return decoratingDrink?.cost ?? 0
    }
    
    init(drink: DrinkProtocol? = nil) {
        decoratingDrink = drink
    }
}

class DrinkOptionDouble: DrinkDecorator {
    override var cost: Double {
        return super.cost * 1.75
    }
    
    override var description: String {
        return super.description + " (Double)"
    }
}

class DrinkOptionBottle: DrinkDecorator {
    override var cost: Double {
        return super.cost * 5
    }
    
    override var description: String {
        return "Bottle of " + super.description
    }
}

extension Date {
    typealias DayAndHour = (day: String, hour: Int)
    
    var dayAndHour: DayAndHour {
        let calender = Calendar.current
        let component = calender.dateComponents([.weekday, .hour], from: self)
        return (calender.weekdaySymbols[component.weekday! - 1], component.hour!)
    }
}

extension Decimal {
    func rounded(places: Int) -> Decimal {
        var originalValue = self
        var result: Decimal = 0
        NSDecimalRound(&result, &originalValue, places, .plain)
        return result
    }
}

extension Double {
    var currency: Decimal {
        return Decimal(floatLiteral: self).rounded(places: 2)
    }
}

enum Offer: String, CaseIterable {
    case TGIF = "Buy one drink get two free on Fridays starting at 6pm"
    
    func isValid(transaction: Transaction) -> Bool {
        switch self {
        case .TGIF:
            let dayAndHour = transaction.dateSupplier.resolve().dayAndHour
            return transaction.drinks.count >= 3 && dayAndHour.day == "Friday" && dayAndHour.hour > 18
        }
    }
    
    func discountAmount(transaction: Transaction) -> Double {
        let sortedByCost = transaction.drinks.sorted { $0.cost < $1.cost }
        
        switch self {
        case .TGIF:
            let count = transaction.drinks.count
            let countWithOfferApplied = count - (count % 3)
            let numFreeDrinks = Int(Double(countWithOfferApplied) * (2.0/3))
            return sortedByCost.prefix(numFreeDrinks).map { $0.cost }.reduce(0, +)
        }
    }
}

protocol DateSupplier {
    func resolve() -> Date
}

struct CurrentDateSupplier: DateSupplier {
    func resolve() -> Date {
        return Date()
    }
}

class Transaction {
    private(set) var drinks = [DrinkProtocol]()
    let dateSupplier: DateSupplier
    
    init(dateSupplier: DateSupplier = CurrentDateSupplier()) {
        self.dateSupplier = dateSupplier
    }
    
    func addDrink(drink: Drink, options: [DrinkDecorator] = []) {
        drinks.append(
            options.reduce(drink) { (result, option) -> DrinkProtocol in
                option.decoratingDrink = result
                return option
        })
    }
    
    typealias TransactionSummary = (description: String, cost: Decimal)
    
    func finalise() -> TransactionSummary {
        let fullCost = drinks.map { $0.cost }.reduce(0, +)
        let validOffers = Offer.allCases.filter { $0.isValid(transaction: self) }
        let offersDiscount = validOffers.map { $0.discountAmount(transaction: self) }.reduce(0, +)
        let actualCost = (fullCost - offersDiscount)
        
        let description = drinks.map { "\($0.description) £\($0.cost.currency)" }.reduce("") { (result, description) -> String in
            return result + "\nDRINK: \(description)"
            }.appending(validOffers.map { "\($0.rawValue) (-£\($0.discountAmount(transaction: self).currency))" }.reduce("\n\nOFFERS APPLIED:", { (result, description) -> String in
                return result + "\n\(description)"
            })).appending("\nTOTAL: £\(actualCost.currency)")
        
        
        return (description: description, cost: actualCost.currency)
    }
}


import XCTest

class TestSuite: XCTestCase {
    
    func testSingleDrinksCosts() {
        XCTAssert(getCostOfDrink(.soft).isEqual(to: (0.99).currency))
        XCTAssert(getCostOfDrink(.beer).isEqual(to: (3.99).currency))
        XCTAssert(getCostOfDrink(.cider).isEqual(to: (2.99).currency))
        XCTAssert(getCostOfDrink(.wine).isEqual(to: (5.99).currency))
        XCTAssert(getCostOfDrink(.spiritsAndLiqueurs).isEqual(to: (7.99).currency))
    }
    
    func testDrinkExtrasCosts() {
        XCTAssert(getCostOfDrink(.wine, options: [DrinkOptionBottle()]).isEqual(to: (5.99 * 5).currency))
        XCTAssert(getCostOfDrink(.spiritsAndLiqueurs, options: [DrinkOptionBottle()]).isEqual(to: (7.99 * 5).currency))
        XCTAssert(getCostOfDrink(.spiritsAndLiqueurs, options: [DrinkOptionDouble()]).isEqual(to: (7.99 * 1.75).currency))
    }
    
    func testTGIFOfferNotAppliedWhenWrongDay() {
        // Sunday 17/02/2019
        let dateSupplier = FakeDate(day: 17, month: 2, year: 2019, hour: 0)
        
        // 3 beers
        let transaction = Transaction(dateSupplier: dateSupplier)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        let cost = transaction.finalise().cost
        
        // Normal price (3x beer price)
        XCTAssert(cost.isEqual(to: (3.99 * 3).currency))
    }
    
    func testTGIFOfferNotAppliedWhenCorrectDayButTooEarly() {
        // Friday 22/02/2019 @ 13:00
        let dateSupplier = FakeDate(day: 22, month: 2, year: 2019, hour: 13)
        
        // 3 beers
        let transaction = Transaction(dateSupplier: dateSupplier)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        let cost = transaction.finalise().cost
        
        // Normal price (3x beer price)
        XCTAssert(cost.isEqual(to: (3.99 * 3).currency))
    }
    
    func testTGIFOfferAppliedWhenCorrectDayAndTime() {
        // Friday 22/02/2019 @ 19:00
        let dateSupplier = FakeDate(day: 22, month: 2, year: 2019, hour: 19)
        
        // 3 beers
        let transaction = Transaction(dateSupplier: dateSupplier)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        let cost = transaction.finalise().cost
        
        // Special price (1x beer price)
        XCTAssert(cost.isEqual(to: (3.99).currency))
    }
    
    func testTGIFOfferAppliedWhenCorrectDayAndTimeAndDrinksNotMultipleOfThree() {
        // Friday 22/02/2019 @ 19:00
        let dateSupplier = FakeDate(day: 22, month: 2, year: 2019, hour: 19)
        
        // 3 beers
        let transaction = Transaction(dateSupplier: dateSupplier)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        transaction.addDrink(drink: .beer)
        let cost = transaction.finalise().cost
        
        // Special price (1x beer price) + the one extra beer
        XCTAssert(cost.isEqual(to: (3.99 + 3.99).currency))
    }
    
    // MARK: Test helpers
    
    private func getCostOfDrink(_ drink: Drink, options: [DrinkDecorator] = []) -> Decimal {
        let transaction = Transaction()
        transaction.addDrink(drink: drink, options: options)
        return transaction.finalise().cost
    }
    
    struct FakeDate: DateSupplier {
        let day: Int
        let month: Int
        let year: Int
        let hour: Int
        
        func resolve() -> Date {
            // Friday 22/02/2019 @ 13:00
            var dateComponents = DateComponents()
            dateComponents.day = day
            dateComponents.month = month
            dateComponents.year = year
            dateComponents.hour = hour
            return Calendar.current.date(from: dateComponents)!
        }
    }
}

XCTestSuite.default.run()


// Examples

let transaction = Transaction()
transaction.addDrink(drink: .beer)
transaction.addDrink(drink: .spiritsAndLiqueurs, options: [DrinkOptionDouble()])
transaction.addDrink(drink: .wine, options: [DrinkOptionBottle()])
print(transaction.finalise().description)

print("--------\n")

let transaction2 = Transaction(dateSupplier: TestSuite.FakeDate(day: 22, month: 2, year: 2019, hour: 19))
transaction2.addDrink(drink: .beer)
transaction2.addDrink(drink: .beer)
transaction2.addDrink(drink: .spiritsAndLiqueurs, options: [DrinkOptionDouble()])
transaction2.addDrink(drink: .wine, options: [DrinkOptionBottle()])
print(transaction2.finalise().description)

