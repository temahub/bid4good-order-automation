/**
 * @description Utility class responsible for generating test data (Accounts and Order__c's) for unit tests.
 */
@isTest
public class TestDataFactory {
    /**
     * @description Creates and inserts the specified number of test Accounts.
     * @param count Number of Account records to create.
     * @return List<Account> List of inserted test Account records.
     */
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 1; i <= count; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
        return accounts;
    }

    /**
     * @description Creates and inserts Order__c records linked to the provided Accounts,
     * with unique amounts and payment dates.
     * @param accounts List of Account records to link the orders to.
     * @param ordersPerAccount Number of orders to generate for each account.
     * @param startDate Base start date used for calculating payment due dates.
     * @return List<Order__c> List of inserted Order__c records.
     */
    public static List<Order__c> createOrders(List<Account> accounts, Integer ordersPerAccount, Date startDate) {
        List<Order__c> ordersToInsert = new List<Order__c>();

        for (Integer accountIndex = 0; accountIndex < accounts.size(); accountIndex++) {
            Account accountRecord = accounts[accountIndex];
            Date firstMonth = startDate.addMonths(accountIndex * 2);

            for (Integer monthIndex = 0; monthIndex < ordersPerAccount; monthIndex++) {
                Date paymentDueDate = firstMonth.addMonths(monthIndex).addDays(4 + accountIndex);
                Decimal totalAmount = 125.50 + (accountIndex * 100) + (monthIndex * 17.25);

                ordersToInsert.add(
                    new Order__c(
                        Account__c = accountRecord.Id,
                        Total_Amount__c = totalAmount,
                        Payment_Due_Date__c = paymentDueDate
                    )
                );
            }
        }

        insert ordersToInsert;
        return ordersToInsert;
    }

    /**
     * @description Creates and inserts a standalone Order__c not linked to any Account (useful for negative testing).
     * @param totalAmount Total monetary amount for the order.
     * @param dueDate Payment due date for the order.
     * @return Order__c The inserted standalone Order__c record.
     */
    public static Order__c createOrderWithoutAccount(Decimal totalAmount, Date dueDate) {
        Order__c standaloneOrder = new Order__c(Total_Amount__c = totalAmount, Payment_Due_Date__c = dueDate);
        insert standaloneOrder;
        return standaloneOrder;
    }
}
