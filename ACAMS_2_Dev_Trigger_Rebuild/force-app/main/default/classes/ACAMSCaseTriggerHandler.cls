public with sharing class ACAMSCaseTriggerHandler extends CCAviTriggerHandler {

    private List<Case> newList;
    private List<Case> oldList;
    private Map<Id, Case> newMap;
    private Map<Id, Case> oldMap;

    public ACAMSCaseTriggerHandler() {
        super();
        this.newList = (List<Case>) Trigger.new;
        this.oldList = (List<Case>) Trigger.old;
        this.newMap = (Map<Id, Case>) Trigger.newMap;
        this.oldMap = (Map<Id, Case>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        this.setRegionFieldByCountry(this.newList);
    }

    public override void beforeUpdate() {
        this.setRegionFieldByCountry(
                this.getCaseWithCountriesChanged(this.newList, this.oldMap)
        );
    }

    private List<Case> getCaseWithCountriesChanged(List<Case> currentCases, Map<Id, Case> oldCases) {
        List<Case> casesWithCountriesChanged = new List<Case>();
        for (Case currentCase : currentCases) {
            Case oldCase = oldCases.get(currentCase.Id);
            if (oldCase.AddressCountry__c != currentCase.AddressCountry__c) {
                casesWithCountriesChanged.add(currentCase);
            }
        }
        return casesWithCountriesChanged;
    }

    private void setRegionFieldByCountry(List<Case> cases) {
        Set<String> countryCodes = new Set<String>();
        Map<String, String> regionByCountryCode = new Map<String, String>();
        for (Case caseToUpdate : cases) {
            if (!String.isBlank(caseToUpdate.AddressCountry__c)) {
                countryCodes.add(caseToUpdate.AddressCountry__c);
            }
        }
        for (CountrySettings__mdt countrySetting : [
                SELECT DeveloperName, Region__c
                FROM CountrySettings__mdt
                WHERE DeveloperName IN :countryCodes
        ]) {
            regionByCountryCode.put(countrySetting.DeveloperName, countrySetting.Region__c);
        }
        for (Case caseToUpdate : cases) {
            if (regionByCountryCode.containsKey(caseToUpdate.AddressCountry__c)) {
                caseToUpdate.AddressRegion__c = regionByCountryCode.get(caseToUpdate.AddressCountry__c);
            } else if (String.isBlank(caseToUpdate.AddressCountry__c)) {
                caseToUpdate.AddressRegion__c = '';
            }
        }
    }
}