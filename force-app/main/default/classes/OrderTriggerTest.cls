/**
 * @description Unit test class for OrderTrigger and OrderTriggerHandler, verifying automated
 * rollup counts of related Order__c records on Account across all DML operations (insert, update, delete, undelete).
 */
@IsTest
private class OrderTriggerTest {
    private static final Date START_DATE = Date.newInstance(2025, 9, 30);

    /**
     * @description Verifies that inserting orders correctly increments the Total_Orders_Count__c on the related Account.
     */
    @IsTest
    static void setsTotalOrdersCountAfterInsert() {
        // WHEN: Insert two Order__c records linked to an Account.
        // THEN: Account.Total_Orders_Count__c matches the number of related Order__c records.
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

    /**
     * @description Verifies that reassigning an order between accounts updates rollup counts for both accounts.
     */
    @IsTest
    static void updatesTotalOrdersCountsWhenOrderIsReassigned() {
        // WHEN: Reassign an Order__c from Account A to Account B.
        // THEN: Account A has 0 related Order__c records; Account B has 1 related Order__c record.
        List<Account> accounts = TestDataFactory.createAccounts(2);
        List<Order__c> orders = TestDataFactory.createOrders(new List<Account>{ accounts[0] }, 1, START_DATE);

        Test.startTest();

        update new Order__c(Id = orders[0].Id, Account__c = accounts[1].Id);

        Test.stopTest();

        assertTotalOrdersCount(accounts[0].Id, 0, 'Total_Orders_Count__c of the original Account should equal 0.');
        assertTotalOrdersCount(accounts[1].Id, 1, 'Total_Orders_Count__c of the new Account should equal 1.');
    }

    /**
     * @description Verifies that deleting one order from an account decrements the total orders count.
     */
    @IsTest
    static void decrementsTotalOrdersCountWhenOneOrderIsDeleted() {
        // WHEN: Delete one of two Order__c records.
        // THEN: Account.Total_Orders_Count__c equals 1.
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

    /**
     * @description Verifies that deleting the last remaining order resets the account's total orders count to zero.
     */
    @IsTest
    static void setsTotalOrdersCountToZeroWhenLastOrderIsDeleted() {
        // WHEN: Delete the last Order__c related to an Account.
        // THEN: Account.Total_Orders_Count__c equals 0.
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

    /**
     * @description Verifies that restoring a deleted order via undelete properly restores the account's order count.
     */
    @IsTest
    static void restoresTotalOrdersCountAfterOrderUndelete() {
        // WHEN: Restore a deleted Order__c.
        // THEN: Account.Total_Orders_Count__c returns to 1.
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

    /**
     * @description Verifies that inserting an order without an account link does not alter existing account counts.
     */
    @IsTest
    static void keepsTotalOrdersCountsUnchangedWhenInsertingUnlinkedOrder() {
        // WHEN: Insert an Order__c without an Account.
        // THEN: No error occurs, and existing Account.Total_Orders_Count__c values remain unchanged.
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

    /**
     * @description Verifies that linking a previously unlinked order to an account increments that account's order count.
     */
    @IsTest
    static void assignsAccountToPreviouslyUnlinkedOrder() {
        // WHEN: Assign an Account to an Order__c whose Account__c is null.
        // THEN: Account.Total_Orders_Count__c becomes 1.
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

    /**
     * @description Verifies that clearing the account lookup on an order resets the previous account's count to zero.
     */
    @IsTest
    static void clearsAccountLookupAndResetsPreviousAccountCount() {
        // WHEN: Clear Account__c on an Order__c.
        // THEN: The previous Account.Total_Orders_Count__c becomes 0.
        List<Account> accounts = TestDataFactory.createAccounts(1);
        List<Order__c> orders = TestDataFactory.createOrders(accounts, 1, START_DATE);

        Test.startTest();

        update new Order__c(Id = orders[0].Id, Account__c = null);

        Test.stopTest();

        assertTotalOrdersCount(accounts[0].Id, 0, 'Total_Orders_Count__c should equal 0 after clearing Account__c.');
    }

    /**
     * @description Verifies that updating non-lookup fields (like total amount) does not affect order rollup counts.
     */
    @IsTest
    static void keepsTotalOrdersCountUnchangedWhenOnlyAmountChanges() {
        // WHEN: Update Total_Amount__c without changing Account__c.
        // THEN: Account.Total_Orders_Count__c remains 2.
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

    /**
     * @description Verifies correct rollup behavior and performance under bulk insert operations.
     */
    @IsTest
    static void recalculatesTotalOrdersCountsForBulkInsert() {
        // WHEN: Insert 200 Order__c records for five Accounts in one DML operation.
        // THEN: Account.Total_Orders_Count__c equals 40 for every Account.
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

    /**
     * @description Helper method that queries the persisted Total_Orders_Count__c value and performs the assertion.
     * @param accountId Id of the Account record being validated.
     * @param expectedCount Expected total order count value.
     * @param message Assertion failure message description.
     */
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
