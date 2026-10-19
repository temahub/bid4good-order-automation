/*
 * Bid4Good Order Automation - demo data seeder
 *
 * Creates/reuses five dedicated seed Accounts and inserts exactly 8 Order__c
 * records for each of them (40 orders total).
 *
 * IMPORTANT:
 * On every run, this script deletes ALL Order__c records linked to the five
 * Accounts named below before inserting the demo orders again. Use only in a
 * development/demo org, and do not use these Account names for real data.
 *
 * Order__c.Name is assumed to be Auto Number, so it is intentionally omitted.
 */

List<String> seedAccountNames = new List<String>{
    'Bid4Good Seed Account 1',
    'Bid4Good Seed Account 2',
    'Bid4Good Seed Account 3',
    'Bid4Good Seed Account 4',
    'Bid4Good Seed Account 5'
};

// Reuse seed Accounts that already exist so the script can be run again.
Map<String, Account> accountsByName = new Map<String, Account>();
for (Account accountRecord : [
    SELECT Id, Name
    FROM Account
    WHERE Name IN :seedAccountNames
]) {
    if (!accountsByName.containsKey(accountRecord.Name)) {
        accountsByName.put(accountRecord.Name, accountRecord);
    }
}

// Create any missing seed Accounts.
List<Account> accountsToInsert = new List<Account>();
for (String accountName : seedAccountNames) {
    if (!accountsByName.containsKey(accountName)) {
        accountsToInsert.add(new Account(Name = accountName));
    }
}

if (!accountsToInsert.isEmpty()) {
    insert accountsToInsert;
    for (Account accountRecord : accountsToInsert) {
        accountsByName.put(accountRecord.Name, accountRecord);
    }
}

Set<Id> seedAccountIds = new Set<Id>();
Map<Id, String> accountNameById = new Map<Id, String>();
for (String accountName : seedAccountNames) {
    Account accountRecord = accountsByName.get(accountName);
    seedAccountIds.add(accountRecord.Id);
    accountNameById.put(accountRecord.Id, accountRecord.Name);
}

// Clean up previous demo orders linked to these dedicated seed Accounts.
List<Order__c> existingSeedOrders = [
    SELECT Id
    FROM Order__c
    WHERE Account__c IN :seedAccountIds
];
if (!existingSeedOrders.isEmpty()) {
    delete existingSeedOrders;
}

/*
 * Each Account gets orders in 8 consecutive months, but the starting month
 * differs by Account. This makes the second picklist's month options vary
 * depending on the selected Account.
 *
 * Account 1: Oct 2025 - May 2026
 * Account 2: Dec 2025 - Jul 2026
 * Account 3: Feb 2026 - Sep 2026
 * Account 4: Apr 2026 - Nov 2026
 * Account 5: Jun 2026 - Jan 2027
 *
 * Due dates use days 5-9 of each month, so all 40 dates are unique even when
 * different Accounts have an order in the same month.
 */
List<Order__c> ordersToInsert = new List<Order__c>();

for (Integer accountIndex = 0; accountIndex < seedAccountNames.size(); accountIndex++) {
    Account accountRecord = accountsByName.get(seedAccountNames[accountIndex]);
    Date firstMonth = Date.newInstance(2025, 10, 1).addMonths(accountIndex * 2);

    for (Integer monthIndex = 0; monthIndex < 8; monthIndex++) {
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

System.debug(
    LoggingLevel.INFO,
    'Seed complete: ' + seedAccountNames.size() + ' Accounts; ' + ordersToInsert.size() + ' Orders inserted.'
);

// Verify the resulting distribution in the debug log.
for (AggregateResult result : [
    SELECT Account__c accountId, COUNT(Id) orderCount
    FROM Order__c
    WHERE Account__c IN :seedAccountIds
    GROUP BY Account__c
    ORDER BY Account__c
]) {
    Id accountId = (Id) result.get('accountId');
    Integer orderCount = (Integer) result.get('orderCount');
    System.debug(LoggingLevel.INFO, accountNameById.get(accountId) + ': ' + orderCount + ' Orders');
}
