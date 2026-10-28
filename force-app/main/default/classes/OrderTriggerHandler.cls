/**
 * @description Trigger handler class for Order__c object. Recalculates total order counts on related Accounts.
 */
public without sharing class OrderTriggerHandler {
    /**
     * @description Main entry point for counting orders on Accounts. Handles AFTER_INSERT, AFTER_UPDATE,
     * AFTER_DELETE, and AFTER_UNDELETE trigger contexts.
     */
    public static void countOrdersOnAccount() {
        Set<Id> affectedAccountIds = new Set<Id>();

        switch on Trigger.operationType {
            when AFTER_INSERT {
                addAccountIds((List<Order__c>) Trigger.new, affectedAccountIds);
            }
            when AFTER_UPDATE {
                List<Order__c> newOrders = (List<Order__c>) Trigger.new;

                Map<Id, Order__c> oldOrdersMap = (Map<Id, Order__c>) Trigger.oldMap;

                for (Order__c newOrder : newOrders) {
                    Order__c oldOrder = oldOrdersMap.get(newOrder.Id);

                    if (newOrder.Account__c != oldOrder.Account__c) {
                        addAccountId(affectedAccountIds, oldOrder.Account__c);

                        addAccountId(affectedAccountIds, newOrder.Account__c);
                    }
                }
            }
            when AFTER_DELETE {
                addAccountIds((List<Order__c>) Trigger.old, affectedAccountIds);
            }
            when AFTER_UNDELETE {
                addAccountIds((List<Order__c>) Trigger.new, affectedAccountIds);
            }
        }

        recalculateOrderCounts(affectedAccountIds);
    }

    /**
     * @description Extracts non-null Account IDs from a list of Order__c records and adds them to a Set.
     * @param orders List of Order__c records to inspect.
     * @param accountIds Target Set where Account IDs will be collected.
     */
    private static void addAccountIds(List<Order__c> orders, Set<Id> accountIds) {
        for (Order__c orderRecord : orders) {
            addAccountId(accountIds, orderRecord.Account__c);
        }
    }

    /**
     * @description Helper method to safely add a non-null Account ID to a Set.
     * @param accountIds Target Set of Account IDs.
     * @param accountId Account ID to validate and add.
     */
    private static void addAccountId(Set<Id> accountIds, Id accountId) {
        if (accountId != null) {
            accountIds.add(accountId);
        }
    }

    /**
     * @description Queries the total count of Orders for each specified Account in SYSTEM_MODE
     * and updates the Total_Orders_Count__c field on the Account records.
     * @param accountIds Set of Account IDs whose order counts need recalculation.
     */
    private static void recalculateOrderCounts(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }

        // Initialize to zero so Accounts with no remaining Orders
        // are correctly updated after deletion or reassignment.
        Map<Id, Integer> countsByAccountId = new Map<Id, Integer>();

        for (Id accountId : accountIds) {
            countsByAccountId.put(accountId, 0);
        }

        // Explicit system mode ensures this derived count includes
        // all related Orders, regardless of the running user's FLS.
        for (AggregateResult result : [
            SELECT Account__c, COUNT(Id) orderCount
            FROM Order__c
            WHERE Account__c IN :accountIds
            WITH SYSTEM_MODE
            GROUP BY Account__c
        ]) {
            countsByAccountId.put((Id) result.get('Account__c'), (Integer) result.get('orderCount'));
        }

        List<Account> accountsToUpdate = new List<Account>();

        for (Id accountId : countsByAccountId.keySet()) {
            accountsToUpdate.add(new Account(Id = accountId, Total_Orders_Count__c = countsByAccountId.get(accountId)));
        }

        Database.update(accountsToUpdate, AccessLevel.SYSTEM_MODE);
    }
}
