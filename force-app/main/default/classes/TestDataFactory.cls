@isTest
public class TestDataFactory {
    /**
     * Creates and inserts the specified number of test Accounts.
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
     * Creates and inserts Order__c's linked to the provided Accounts,
     * with unique amounts and payment dates.
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
     * Creates a separate Order__c not linked to any Account (useful for negative testing).
     */
    public static Order__c createOrderWithoutAccount(Decimal totalAmount, Date dueDate) {
        Order__c standaloneOrder = new Order__c(Total_Amount__c = totalAmount, Payment_Due_Date__c = dueDate);
        insert standaloneOrder;
        return standaloneOrder;
    }
}
