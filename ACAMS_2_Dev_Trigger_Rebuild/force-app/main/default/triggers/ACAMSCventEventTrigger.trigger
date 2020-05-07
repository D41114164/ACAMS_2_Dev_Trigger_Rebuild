trigger ACAMSCventEventTrigger on CVENT__Cvent_Event__c (
    before insert,
    after insert,
    before update,
    after update,
    before delete,
    after delete,
    after undelete
) {
    (new ACAMSCventEventTriggerHandler()).run();
}