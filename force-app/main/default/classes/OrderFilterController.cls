public with sharing class OrderFilterController {
    /**
     * Returns a list of Accounts, each of which contains at least one Order__c.
     */
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

    /**
     * Returns a list of available Order__c's dates (in YYYY-MM format) for the specified Account Id.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableMonthKeys(Id accountId) {
        List<String> monthKeys = new List<String>();

        if (accountId == null) {
            return monthKeys;
        }

        for (AggregateResult result : [
            SELECT
                CALENDAR_YEAR(Payment_Due_Date__c) yearValue,
                CALENDAR_MONTH(Payment_Due_Date__c) monthValue,
                COUNT(Id) orderCount
            FROM Order__c
            WHERE Account__c = :accountId AND Payment_Due_Date__c != NULL
            WITH USER_MODE
            GROUP BY CALENDAR_YEAR(Payment_Due_Date__c), CALENDAR_MONTH(Payment_Due_Date__c)
            ORDER BY CALENDAR_YEAR(Payment_Due_Date__c), CALENDAR_MONTH(Payment_Due_Date__c)
        ]) {
            Integer yearValue = (Integer) result.get('yearValue');
            Integer monthValue = (Integer) result.get('monthValue');

            String monthText = monthValue < 10 ? '0' + String.valueOf(monthValue) : String.valueOf(monthValue);

            monthKeys.add(String.valueOf(yearValue) + '-' + monthText);
        }

        return monthKeys;
    }
}
