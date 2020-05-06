trigger ACAMSCertificationApplicationTrigger on Certification_Application__c (before insert, before update) {
    new ACAMSCertAppTriggerHandler().run();
}