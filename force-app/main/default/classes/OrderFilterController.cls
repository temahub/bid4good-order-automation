public with sharing class OrderFilterController {
    // Returns a list of Accounts, each of which contains at least one Order__c
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccountsWithOrders() {
        return [
            SELECT Id, Name
            FROM Account
            WHERE
                Id IN (
                    SELECT Account__c
                    FROM Order__c
                    WHERE Account__c != NULL
                )
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }
}
