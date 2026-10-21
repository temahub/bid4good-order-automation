@isTest
private class OrderFilterControllerTest {
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

    // GIVEN: Accounts exist in the system, with and without related Order__c records.
    // WHEN: getAccountsWithOrders is invoked.
    // THEN: Returns only Accounts that have at least one Order__c, sorted by Name ASC.
    @isTest
    static void testGetAccountsWithOrders() {
        Test.startTest();
        List<Account> accounts = OrderFilterController.getAccountsWithOrders();
        Test.stopTest();

        System.assertEquals(2, accounts.size(), 'Should return exactly 2 accounts with orders.');
        System.assertEquals('B Multi Month Account', accounts[0].Name, 'Accounts must be sorted by Name ASC.');
    }

    // GIVEN: An Account with orders in different months, an Account without orders, and a null Account ID.
    // WHEN: getAvailableMonthKeys is invoked for each case.
    // THEN: Returns distinct YYYY-MM formatted keys for the Account with orders, and empty lists for others.
    @isTest
    static void testGetAvailableMonthKeys() {
        Account multiMonthAcc = [SELECT Id FROM Account WHERE Name = 'B Multi Month Account' LIMIT 1];
        Account emptyAcc = [SELECT Id FROM Account WHERE Name = 'A Empty Account' LIMIT 1];

        Test.startTest();
        List<String> monthsMulti = OrderFilterController.getAvailableMonthKeys(multiMonthAcc.Id);
        List<String> monthsEmpty = OrderFilterController.getAvailableMonthKeys(emptyAcc.Id);
        List<String> monthsNull = OrderFilterController.getAvailableMonthKeys(null);
        Test.stopTest();

        System.assertEquals(2, monthsMulti.size(), 'Should return two distinct month keys.');
        System.assert(!monthsMulti.isEmpty(), 'Month keys should not be empty.');

        System.assert(monthsEmpty.isEmpty(), 'Account with no orders should return an empty list.');
        System.assert(monthsNull.isEmpty(), 'Null accountId should return an empty list.');
    }

    // GIVEN: An Account with orders in different years.
    // WHEN: getAvailableMonthKeys is invoked.
    // THEN: Returns distinct month keys for each year-month combination.
    @isTest
    static void testGetAvailableMonthKeys_MultiYear() {
        Account multiYearAcc = [SELECT Id FROM Account WHERE Name = 'C Multi Year Account' LIMIT 1];

        Test.startTest();
        List<String> monthKeys = OrderFilterController.getAvailableMonthKeys(multiYearAcc.Id);
        Test.stopTest();

        System.assertEquals(2, monthKeys.size(), 'Should return 2 keys across different years.');
        System.assertEquals('2024-10', monthKeys[0], 'Should include October 2024.');
    }

    // GIVEN: An Account with multiple orders across different months.
    // WHEN: getOrdersForAccountAndMonth is invoked with a valid Account ID and month key.
    // THEN: Returns only Order__c records falling within that specific year and month.
    @isTest
    static void testGetOrdersForAccountAndMonth() {
        Account multiMonthAcc = [SELECT Id FROM Account WHERE Name = 'B Multi Month Account' LIMIT 1];

        Test.startTest();
        List<Order__c> orders = OrderFilterController.getOrdersForAccountAndMonth(multiMonthAcc.Id, '2025-03');
        Test.stopTest();

        System.assert(!orders.isEmpty(), 'Should return orders for March 2025.');
    }

    // GIVEN: An Account ID and null or empty monthKey parameters.
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Returns an empty list of Order__c records without throwing an exception.
    @isTest
    static void testGetOrdersForAccountAndMonth_NullOrBlankInput() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Order__c> ordersNull = OrderFilterController.getOrdersForAccountAndMonth(null, '2025-03');
        List<Order__c> ordersBlank = OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '');
        Test.stopTest();

        System.assert(ordersNull.isEmpty(), 'Null Account ID should return an empty list.');
        System.assert(ordersBlank.isEmpty(), 'Blank month key should return an empty list.');
    }

    // GIVEN: A monthKey with an invalid string length (not 7 characters).
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Throws an AuraHandledException with invalid month selection message.
    @isTest
    static void testGetOrdersForAccountAndMonth_InvalidLength() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '20253');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid string length.');
    }

    // GIVEN: A monthKey missing a hyphen at the 5th character position.
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Throws an AuraHandledException.
    @isTest
    static void testGetOrdersForAccountAndMonth_MissingHyphenDelimiter() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025/03');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for missing hyphen delimiter.');
    }

    // GIVEN: A monthKey containing non-numeric values.
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Throws an AuraHandledException upon failing number conversion.
    @isTest
    static void testGetOrdersForAccountAndMonth_NonNumericValues() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025-AB');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for non-numeric month key values.');
    }

    // GIVEN: A monthKey containing a year before 1700.
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Throws an AuraHandledException due to year being out of acceptable range.
    @isTest
    static void testGetOrdersForAccountAndMonth_YearOutOfRange() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '1500-01');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for year outside allowed range (< 1700).');
    }

    // GIVEN: A monthKey containing a month value greater than 12.
    // WHEN: getOrdersForAccountAndMonth is invoked.
    // THEN: Throws an AuraHandledException due to invalid month number.
    @isTest
    static void testGetOrdersForAccountAndMonth_MonthOutOfRange() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            OrderFilterController.getOrdersForAccountAndMonth(acc.Id, '2025-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for month outside valid range (> 12).');
    }
}
