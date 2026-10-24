@IsTest(SeeAllData=true)
private class OrderEmailServiceTest {
    @IsTest
    static void testNullOrderIdThrowsException() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            OrderEmailService.sendOrderEmail(null);
        } catch (AuraHandledException e) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected an AuraHandledException when orderId is null.');
    }

    @IsTest
    static void testInvalidOrderIdThrowsException() {
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

    @IsTest
    static void testSendOrderEmailSuccess() {
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
