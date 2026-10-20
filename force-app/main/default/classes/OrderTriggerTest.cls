@IsTest
private class OrderTriggerTest {
    private static final Date START_DATE = Date.newInstance(2025, 9, 30);

    // WHEN: Insert two Order__c records linked to an Account.
    // THEN: Account.Total_Orders_Count__c matches the number
    //       of related Order__c records.
    @IsTest
    static void setsTotalOrdersCountAfterInsert() {
        List<Account> accounts = TestDataFactory.createAccounts(1);

        Test.startTest();

        List<Order__c> orders = TestDataFactory.createOrders(accounts, 2, START_DATE);

        Test.stopTest();

        assertTotalOrdersCount(
            accounts[0].Id,
            orders.size(),
            'Total_Orders_Count__c should match the number of related Order__c records.'
        );
    }

    // WHEN: Reassign an Order__c from Account A to Account B.
    // THEN: Account A has 0 related Order__c records;
    //       Account B has 1 related Order__c record.
    @IsTest
    static void updatesTotalOrdersCountsWhenOrderIsReassigned() {
        List<Account> accounts = TestDataFactory.createAccounts(2);
        List<Order__c> orders = TestDataFactory.createOrders(new List<Account>{ accounts[0] }, 1, START_DATE);

        Test.startTest();

        update new Order__c(Id = orders[0].Id, Account__c = accounts[1].Id);

        Test.stopTest();

        assertTotalOrdersCount(accounts[0].Id, 0, 'Total_Orders_Count__c of the original Account should equal 0.');
        assertTotalOrdersCount(accounts[1].Id, 1, 'Total_Orders_Count__c of the new Account should equal 1.');
    }

    // WHEN: Delete one of two Order__c records.
    // THEN: Account.Total_Orders_Count__c equals 1.
    @IsTest
    static void decrementsTotalOrdersCountWhenOneOrderIsDeleted() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 2, START_DATE);

        Test.startTest();

        delete orders[0];

        Test.stopTest();

        assertTotalOrdersCount(
            accounts[0].Id,
            1,
            'Total_Orders_Count__c should equal 1 after deleting one of two Order__c records.'
        );
    }

    // WHEN: Delete the last Order__c related to an Account.
    // THEN: Account.Total_Orders_Count__c equals 0.
    @IsTest
    static void setsTotalOrdersCountToZeroWhenLastOrderIsDeleted() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 1, START_DATE);

        Test.startTest();

        delete orders[0];

        Test.stopTest();

        assertTotalOrdersCount(
            accounts[0].Id,
            0,
            'Total_Orders_Count__c should equal 0 after deleting the last Order__c record.'
        );
    }

    // WHEN: Restore a deleted Order__c.
    // THEN: Account.Total_Orders_Count__c returns to 1.
    @IsTest
    static void restoresTotalOrdersCountAfterOrderUndelete() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 1, START_DATE);

        delete orders[0];

        assertTotalOrdersCount(
            accounts[0].Id,
            0,
            'Total_Orders_Count__c should equal 0 before restoring the deleted Order__c.'
        );

        Test.startTest();

        undelete orders[0];

        Test.stopTest();

        assertTotalOrdersCount(accounts[0].Id, 1, 'Total_Orders_Count__c should equal 1 after restoring the Order__c.');
    }

    // WHEN: Insert an Order__c without an Account.
    // THEN: No error occurs, and existing Account.Total_Orders_Count__c
    //       values remain unchanged.
    @IsTest
    static void keepsTotalOrdersCountsUnchangedWhenInsertingUnlinkedOrder() {
        List<Account> accounts = TestDataFactory.createAccounts(2);
        TestDataFactory.createOrders(accounts, 2, START_DATE);
        Order__c unlinkedOrder = new Order__c(Total_Amount__c = 100, Payment_Due_Date__c = START_DATE);

        Test.startTest();

        insert unlinkedOrder;

        Test.stopTest();

        Order__c insertedOrder = [
            SELECT Account__c
            FROM Order__c
            WHERE Id = :unlinkedOrder.Id
        ];

        Assert.areEqual(null, insertedOrder.Account__c, 'The inserted Order__c should not be linked to an Account.');

        assertTotalOrdersCount(accounts[0].Id, 2, 'Total_Orders_Count__c of the first Account should remain 2.');
        assertTotalOrdersCount(accounts[1].Id, 2, 'Total_Orders_Count__c of the second Account should remain 2.');
    }

    // WHEN: Assign an Account to an Order__c whose Account__c is null.
    // THEN: Account.Total_Orders_Count__c becomes 1.
    @IsTest
    static void assignsAccountToPreviouslyUnlinkedOrder() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        Order__c unlinkedOrder = TestDataFactory.createOrderWithoutAccount(100, START_DATE);

        Test.startTest();

        update new Order__c(Id = unlinkedOrder.Id, Account__c = accounts[0].Id);

        Test.stopTest();

        assertTotalOrdersCount(
            accounts[0].Id,
            1,
            'Total_Orders_Count__c should equal 1 after assigning an Account to the Order__c.'
        );
    }

    // WHEN: Clear Account__c on an Order__c.
    // THEN: The previous Account.Total_Orders_Count__c becomes 0.
    @IsTest
    static void clearsAccountLookupAndResetsPreviousAccountCount() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 1, START_DATE);

        Test.startTest();

        update new Order__c(Id = orders[0].Id, Account__c = null);

        Test.stopTest();

        assertTotalOrdersCount(accounts[0].Id, 0, 'Total_Orders_Count__c should equal 0 after clearing Account__c.');
    }

    // WHEN: Update Total_Amount__c without changing Account__c.
    // THEN: Account.Total_Orders_Count__c remains 2.
    @IsTest
    static void keepsTotalOrdersCountUnchangedWhenOnlyAmountChanges() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 2, START_DATE);

        Test.startTest();

        update new Order__c(Id = orders[0].Id, Total_Amount__c = 999);

        Test.stopTest();

        assertTotalOrdersCount(
            accounts[0].Id,
            2,
            'Total_Orders_Count__c should remain 2 when only Total_Amount__c changes.'
        );
    }

    // WHEN: Insert 200 Order__c records for five Accounts in one DML operation.
    // THEN: Account.Total_Orders_Count__c equals 40 for every Account.
    @IsTest
    static void recalculatesTotalOrdersCountsForBulkInsert() {
        List<Account> accounts = TestDataFactory.createAccounts(5);
        List<Order__c> ordersToInsert = new List<Order__c>();
        Integer orderNumber = 0;

        for (Account accountRecord : accounts) {
            for (Integer i = 0; i < 40; i++) {
                orderNumber++;

                ordersToInsert.add(
                    new Order__c(
                        Account__c = accountRecord.Id,
                        Total_Amount__c = 100.00 + orderNumber,
                        Payment_Due_Date__c = START_DATE.addDays(orderNumber - 1)
                    )
                );
            }
        }

        Test.startTest();

        insert ordersToInsert;

        Test.stopTest();

        Assert.areEqual(200, ordersToInsert.size(), 'The test should insert 200 Order__c records.');

        for (Account accountRecord : accounts) {
            assertTotalOrdersCount(
                accountRecord.Id,
                40,
                'Total_Orders_Count__c should equal 40 for every Account after bulk insert.'
            );
        }
    }

    // Queries the persisted Total_Orders_Count__c value.
    private static void assertTotalOrdersCount(Id accountId, Integer expectedCount, String message) {
        Account accountRecord = [
            SELECT Total_Orders_Count__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        Integer actualCount = accountRecord.Total_Orders_Count__c == null
            ? null
            : accountRecord.Total_Orders_Count__c.intValue();

        Assert.areEqual(expectedCount, actualCount, message);
    }
}
