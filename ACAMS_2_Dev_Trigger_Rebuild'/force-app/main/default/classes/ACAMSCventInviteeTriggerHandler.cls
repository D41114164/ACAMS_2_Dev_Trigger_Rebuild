public with sharing class ACAMSCventInviteeTriggerHandler extends CCAviTriggerHandler {

    private List<CVENT__Invitee__c>    newList = (List<CVENT__Invitee__c>)    Trigger.new;
    private List<CVENT__Invitee__c>    oldList = (List<CVENT__Invitee__c>)    Trigger.old;
    private Map<Id, CVENT__Invitee__c> newMap  = (Map<Id, CVENT__Invitee__c>) Trigger.newMap;
    private Map<Id, CVENT__Invitee__c> oldMap  = (Map<Id, CVENT__Invitee__c>) Trigger.oldMap;

    protected override void afterInsert() {
        ACAMSCventEventService.removeInviteeDuplicates(Trigger.new);
    }

}