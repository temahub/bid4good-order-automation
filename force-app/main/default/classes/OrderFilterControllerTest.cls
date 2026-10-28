/**
 * @description Unit test class for OrderFilterController, verifying account filtering,
 * available month keys extraction, and order retrieval with rigorous edge-case handling.
 */
@isTest
private class OrderFilterControllerTest {
    /**
     * @description Sets up test data including accounts with/without orders and multi-year order distributions.
     */
    @TestSetup
    static void makeData() {
        // Account with no Order__c's, for negative scenarios
        List<Account> emptyAccountList = TestDataFactory.createAccounts(1);
        emptyAccountList[0].Name = 'A Empty Account';
        update emptyAccountList[0];

        // Accounts with Order__c's
        List<Account> activeAccounts = TestDataFactory.createAccounts(2);
        activeAccounts[0].Name = 'B Multi Month Account';
        activeAccounts[1].Name = 'C Multi Year Account';
        update activeAccounts;

        Date baseDate = Date.newInstance(2025, 3, 1);
        TestDataFactory.createOrders(activeAccounts, 2, baseDate);

        // Adjusting the date of one of the Order__c's to test a scenario involving different years.
        Order__c multiYearOrder = [
            SELECT Id, Payment_Due_Date__c
            FROM Order__c
            WHERE Account__c = :activeAccounts[1].Id
            LIMIT 1
        ];
        multiYearOrder.Payment_Due_Date__c = Date.newInstance(2024, 10, 10);
        update multiYearOrder;
    }

    /**
     * @description Verifies that getAccountsWithOrders returns only accounts containing at least one order, sorted by Name ASC.
     */
    @isTest
    static void testGetAccountsWithOrders() {
        // GIVEN: Accounts exist in the system, with and without related Order__c records.
        // WHEN: getAccountsWithOrders is invoked.
        // THEN: Returns only Accounts that have at least one Order__c, sorted by Name ASC.
        Test.startTest();
        List<Account> accounts = OrderFilterController.getAccountsWithOrders();
        Test.stopTest();

        Assert.areEqual(2, accounts.size(), 'Should return exactly 2 accounts with orders.');
        Assert.areEqual('B Multi Month Account', accounts[0].Name, 'Accounts must be sorted by Name ASC.');
    }

    /**
     * @description Verifies that getAvailableMonthKeys returns distinct YYYY-MM formatted keys for active accounts,
     * and empty lists for empty or null accounts.
     */
    @isTest
    static void testGetAvailableMonthKeys() {
        // GIVEN: An Account with orders in different months, an Account without orders, and a null Account ID.
        // WHEN: getAvailableMonthKeys is invoked for each case.
        // THEN: Returns distinct YYYY-MM formatted keys for the Account with orders, and empty lists for others.
        Account multiMonthAcc = [SELECT Id FROM Account WHERE Name = 'B Multi Month Account' LIMIT 1];
        Account emptyAcc = [SELECT Id FROM Account WHERE Name = 'A Empty Account' LIMIT 1];

        Test.startTest();
        List<String> monthsMulti = OrderFilterController.getAvailableMonthKeys(multiMonthAcc.Id);
        List<String> monthsEmpty = OrderFilterController.getAvailableMonthKeys(emptyAcc.Id);
        List<String> monthsNull = OrderFilterController.getAvailableMonthKeys(null);
        Test.stopTest();

        Assert.areEqual(2, monthsMulti.size(), 'Should return two distinct month keys.');
        Assert.isTrue(!monthsMulti.isEmpty(), 'Month keys should not be empty.');

        Assert.isTrue(monthsEmpty.isEmpty(), 'Account with no orders should return an empty list.');
        Assert.isTrue(monthsNull.isEmpty(), 'Null accountId should return an empty list.');
    }

    /**
     * @description Verifies that getAvailableMonthKeys correctly aggregates month keys across multiple years.
     */
    @isTest
    static void testGetAvailableMonthKeys_MultiYear() {
        // GIVEN: An Account with orders in different years.
        // WHEN: getAvailableMonthKeys is invoked.
        // THEN: Returns distinct month keys for each year-month combination.
        Account multiYearAcc = [SELECT Id FROM Account WHERE Name = 'C Multi Year Account' LIMIT 1];

        Test.startTest();
        List<String> monthKeys = OrderFilterController.getAvailableMonthKeys(multiYearAcc.Id);
        Test.stopTest();

        Assert.areEqual(2, monthKeys.size(), 'Should return 2 keys across different years.');
        Assert.areEqual('2024-10', monthKeys[0], 'Should include October 2024.');
    }

    /**
     * @description Verifies that getOrdersForAccountAndMonth filters orders correctly by account and month.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth() {
        // GIVEN: An Account with multiple orders across different months.
        // WHEN: getOrdersForAccountAndMonth is invoked with a valid Account ID and month key.
        // THEN: Returns only Order__c records falling within that specific year and month.
        Account multiMonthAcc = [SELECT Id FROM Account WHERE Name = 'B Multi Month Account' LIMIT 1];

        Test.startTest();
        List<Order__c> orders = OrderFilterController.getOrdersForAccountAndMonth(multiMonthAcc.Id, '2025-03');
        Test.stopTest();

        Assert.isTrue(!orders.isEmpty(), 'Should return orders for March 2025.');
    }

    /**
     * @description Verifies that passing null or blank parameters to getOrdersForAccountAndMonth returns an empty list.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_NullOrBlankInput() {
        // GIVEN: An Account ID and null or empty monthKey parameters.
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Returns an empty list of Order__c records without throwing an exception.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Order__c> ordersNull = OrderFilterController.getOrdersForAccountAndMonth(null, '2025-03');
        List<Order__c> ordersBlank = OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '');
        Test.stopTest();

        Assert.isTrue(ordersNull.isEmpty(), 'Null Account ID should return an empty list.');
        Assert.isTrue(ordersBlank.isEmpty(), 'Blank month key should return an empty list.');
    }

    /**
     * @description Verifies that an invalid monthKey length throws an AuraHandledException.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_InvalidLength() {
        // GIVEN: A monthKey with an invalid string length (not 7 characters).
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Throws an AuraHandledException with invalid month selection message.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '20253');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for invalid string length.');
    }

    /**
     * @description Verifies that a missing hyphen delimiter in monthKey throws an AuraHandledException.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_MissingHyphenDelimiter() {
        // GIVEN: A monthKey missing a hyphen at the 5th character position.
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Throws an AuraHandledException.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025/03');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for missing hyphen delimiter.');
    }

    /**
     * @description Verifies that non-numeric characters in monthKey throw an AuraHandledException.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_NonNumericValues() {
        // GIVEN: A monthKey containing non-numeric values.
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Throws an AuraHandledException upon failing number conversion.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025-AB');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for non-numeric month key values.');
    }

    /**
     * @description Verifies that a year out of acceptable range throws an AuraHandledException.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_YearOutOfRange() {
        // GIVEN: A monthKey containing a year before 1700.
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Throws an AuraHandledException due to year being out of acceptable range.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '1500-01');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for year outside allowed range (< 1700).');
    }

    /**
     * @description Verifies that a month number greater than 12 throws an AuraHandledException.
     */
    @isTest
    static void testGetOrdersForAccountAndMonth_MonthOutOfRange() {
        // GIVEN: A monthKey containing a month value greater than 12.
        // WHEN: getOrdersForAccountAndMonth is invoked.
        // THEN: Throws an AuraHandledException due to invalid month number.
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for month outside valid range (> 12).');
    }
}
