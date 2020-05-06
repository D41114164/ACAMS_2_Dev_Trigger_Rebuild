trigger ACAMSCventInviteeTrigger on CVENT__Invitee__c (after insert) {
    (new ACAMSCventInviteeTriggerHandler()).run();
}