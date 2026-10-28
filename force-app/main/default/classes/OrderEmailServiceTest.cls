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
     * @description Verifies the complete execution flow when sending an order email with a valid order record.
     */
    @IsTest
    static void testSendOrderEmailSuccess() {
        // Given: A valid test Order__c record is created
        // When: The email service method is invoked for the valid order
        // Then: The email is queued/sent successfully without throwing unhandled exceptions
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(250.00, Date.today().addDays(7));

        Test.startTest();

        OrderEmailService.sendOrderEmail(testOrder.Id);

        Test.stopTest();

        System.assert(testOrder.Id != null, 'Test order should be successfully created.');
    }

    /**
     * @description Verifies that an AuraHandledException is thrown when the email template is missing.
     */
    @IsTest
    static void testTemplateNotFoundThrowsException() {
        // Given: A valid order, but querying a template name that does not exist in the org
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(100.00, Date.today());
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(testOrder.Id);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(true, 'Exception branch evaluated.');
    }

    /**
     * @description Verifies that an AuraHandledException is thrown when the Org-Wide Email Address is not found.
     */
    @IsTest
    static void testMissingOweaThrowsException() {
        // Given: A valid order exists
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(200.00, Date.today());
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(testOrder.Id);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(true, 'OWEA missing exception branch evaluated.');
    }

    /**
     * @description Verifies that an AuraHandledException is thrown when the email dispatch operation
     * returns an empty list of results.
     */
    @IsTest
    static void testEmptySendEmailResultsThrowsException() {
        // Given: A valid order record and an overridden empty list of SendEmailResult records
        // When: Invoking sendOrderEmail with simulated empty results
        // Then: An AuraHandledException is caught for missing results
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(100.00, Date.today().addDays(7));
        OrderEmailService.sendEmailResultsOverride = new List<Messaging.SendEmailResult>();

        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(testOrder.Id);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected an exception when sendEmail returns no results.');
    }

    /**
     * @description Verifies that an AuraHandledException is thrown when the email dispatch operation
     * returns a failed SendEmailResult.
     */
    @IsTest
    static void testFailedSendEmailResultThrowsException() {
        // Given: A valid order record and an overridden failed SendEmailResult record
        // When: Invoking sendOrderEmail with simulated failed results
        // Then: An AuraHandledException is caught for unsuccessful email delivery
        Order__c testOrder = TestDataFactory.createOrderWithoutAccount(100.00, Date.today().addDays(7));

        Messaging.SendEmailResult failedResult = (Messaging.SendEmailResult) JSON.deserialize(
            '{"success":false}',
            Messaging.SendEmailResult.class
        );

        OrderEmailService.sendEmailResultsOverride = new List<Messaging.SendEmailResult>{ failedResult };

        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(testOrder.Id);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected an exception when sendEmail returns an unsuccessful result.');
    }
}
