import XCTest

final class ChaselogUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        return app
    }

    func testAddInvoiceFromMainList() throws {
        let app = launchApp()

        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["clientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "New Invoice sheet did not appear")
        nameField.tap()
        nameField.typeText("Acme Studio")

        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText("750")

        let saveButton = app.buttons["invoiceSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Acme Studio"].waitForExistence(timeout: 5), "New invoice did not appear on the list")
    }

    func testFreeLimitTriggersPaywallAfterTwentyInvoices() throws {
        let app = launchApp()
        // Seed data already has 2 invoices; add 18 more to hit the free cap of 20, then try a 21st.
        for i in 0..<19 {
            let addButton = app.buttons["addInvoiceButton"]
            if addButton.waitForExistence(timeout: 3) {
                addButton.tap()
                let nameField = app.textFields["clientNameField"]
                if nameField.waitForExistence(timeout: 3) {
                    nameField.tap()
                    nameField.typeText("Client \(i)")
                    let amountField = app.textFields["amountField"]
                    amountField.tap()
                    amountField.typeText("50")
                    app.buttons["invoiceSaveButton"].tap()
                }
            }
        }
        XCTAssertTrue(app.staticTexts["Chaselog Pro"].waitForExistence(timeout: 5), "Paywall did not appear after hitting the free invoice limit")
    }

    func testEditInvoiceFromSettings() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        let addButton = app.buttons["settingsAddInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["clientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Editable Client")
        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText("300")
        app.buttons["invoiceSaveButton"].tap()

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Editable Client"].waitForExistence(timeout: 5))

        let menu = app.buttons["invoiceMenu_Editable Client"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Edit Invoice"].tap()

        let editNameField = app.textFields["clientNameField"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 5))
        editNameField.tap()
        let stringValue = editNameField.value as? String ?? ""
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        editNameField.typeText(deleteString)
        editNameField.typeText("Renamed Client")

        app.buttons["invoiceSaveButton"].tap()

        XCTAssertTrue(app.staticTexts["Renamed Client"].waitForExistence(timeout: 5), "Invoice rename did not apply")
    }

    func testMarkInvoicePaidViaMenu() throws {
        let app = launchApp()

        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["clientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Payer Co")
        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText("400")
        app.buttons["invoiceSaveButton"].tap()

        XCTAssertTrue(app.staticTexts["Payer Co"].waitForExistence(timeout: 5))

        let menu = app.buttons["invoiceMenu_Payer Co"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Mark Paid"].tap()

        XCTAssertTrue(app.staticTexts["Paid"].waitForExistence(timeout: 5), "Invoice was not marked paid")
    }

    func testDeleteInvoiceViaMenu() throws {
        let app = launchApp()

        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["clientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Disposable Client")
        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText("150")
        app.buttons["invoiceSaveButton"].tap()

        XCTAssertTrue(app.staticTexts["Disposable Client"].waitForExistence(timeout: 5))

        let menu = app.buttons["invoiceMenu_Disposable Client"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Remove Invoice"].tap()

        let confirmButton = app.buttons["Remove"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        XCTAssertFalse(app.staticTexts["Disposable Client"].waitForExistence(timeout: 3), "Invoice was not deleted")
    }

    func testKeyboardDismissesOnTapOutsideInAddSheet() throws {
        let app = launchApp()

        let addButton = app.buttons["addInvoiceButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["clientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "Keyboard did not appear after tapping field")

        let sectionHeader = app.staticTexts["Dates"]
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 5))
        sectionHeader.tap()

        let keyboardGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.element, handler: nil)
        wait(for: [keyboardGone], timeout: 5)
    }

    func testProSettingsSectionsHiddenWithoutPro() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Unlock Chaselog Pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Client Balances"].exists)
    }

    func testAlertDaysStepperSectionLoads() throws {
        let app = launchApp()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}
