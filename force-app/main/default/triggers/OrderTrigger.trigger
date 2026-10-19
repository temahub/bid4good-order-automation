trigger OrderTrigger on Order__c(after insert, after update, after delete, after undelete) {
    OrderTriggerHandler.countOrdersOnAccount();
}
