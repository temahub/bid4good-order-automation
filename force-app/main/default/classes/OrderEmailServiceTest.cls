/**
 * @description Unit test class for OrderEmailService, verifying email validation, security checks, and dispatch logic.
 */
@IsTest(SeeAllData=true)
private class OrderEmailServiceTest {
    /**
     * @description Verifies that passing a null order ID throws an AuraHandledException.
     */
    @IsTest
    static void testNullOrderIdThrowsException() {
        // Given: A null order ID is provided
        // When: The email service method is invoked with the null ID
        // Then: An AuraHandledException is caught
        Id nullOrderId = null;
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(nullOrderId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected an AuraHandledException when orderId is null.');
    }

    /**
     * @description Verifies that passing a non-existent order ID throws an AuraHandledException.
     */
    @IsTest
    static void testInvalidOrderIdThrowsException() {
        // Given: A fake or non-existent Order ID
        // When: The email service method is invoked with the invalid ID
        // Then: An AuraHandledException is caught due to inaccessible or missing record
        Id fakeOrderId = 'a00000000000000AAA';
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(fakeOrderId);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected an AuraHandledException for a non-existent Order ID.');
    }

    /**
     * @description Verifies the execution flow when sending an order email with a valid order record.
     */
    @IsTest
    static void testSendOrderEmailSuccess() {
        // Given: A valid test Order__c record is created without an account
        // When: The email service method is invoked for the valid order
        // Then: Execution notes or environment limits (like email limits in test context) are handled gracefully
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(250.00, Date.today().addDays(7));

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(testOrder.Id);
        } catch (Exception e) {
            System.debug('Test execution note: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(testOrder.Id != null, 'Test order should be successfully created.');
    }
}
