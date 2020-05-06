public with sharing class ACAMSCventEventTriggerHandler extends CCAviTriggerHandler {

    private List<CVENT__Cvent_Event__c> newList = (List<CVENT__Cvent_Event__c>) Trigger.new;
    private List<CVENT__Cvent_Event__c> oldList = (List<CVENT__Cvent_Event__c>) Trigger.old;
    private Map<Id, CVENT__Cvent_Event__c> newMap = (Map<Id, CVENT__Cvent_Event__c>) Trigger.newMap;
    private Map<Id, CVENT__Cvent_Event__c> oldMap = (Map<Id, CVENT__Cvent_Event__c>) Trigger.oldMap;

    public static Boolean skipProductCreationOnInsert = false;
    public static Boolean skipRegionFieldPopulation = false;

    protected override void afterInsert() {
        if (!skipProductCreationOnInsert) {
            ACAMSCventEventService.ProductCreationResults results =
                    ACAMSCventEventService.createCCProductsForEvents(this.newMap);
        }
    }

    protected override void beforeInsert() {
        populateAddressRegionField();
    }

    protected override void beforeUpdate() {
        populateAddressRegionField();
    }

    private void populateAddressRegionField() {
        if (!skipRegionFieldPopulation) {
            ACAMSAddressFieldsService.beforeTriggerCall(
                    this.newList,
                    this.oldMap,
                    CVENT__Cvent_Event__c.CVENT__Country_Name__c.getDescribe().getName(),
                    CVENT__Cvent_Event__c.CVENT__Event_Address_Country__c.getDescribe().getName(),
                    CVENT__Cvent_Event__c.Event_Address_Region__c.getDescribe().getName(),
                    CVENT__Cvent_Event__c.Event_Address_Continent__c.getDescribe().getName(),
                    CVENT__Cvent_Event__c.Event_Address_Named_Territory__c.getDescribe().getName(),
                    CVENT__Cvent_Event__c.Event_Address_SubTerritory__c.getDescribe().getName()
            );
        }
    }

}