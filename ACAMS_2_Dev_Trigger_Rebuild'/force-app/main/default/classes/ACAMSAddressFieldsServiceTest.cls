@IsTest
class ACAMSAddressFieldsServiceTest {
    @IsTest
    static void setEventRegionFields() {
        List<CVENT__Cvent_Event__c> cventEvents = new List<CVENT__Cvent_Event__c> {
            new CVENT__Cvent_Event__c (
                CVENT__Event_Address_Country__c = 'GB'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Event_Address_Country__c = 'GBR'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Event_Address_Country__c = 'UK'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Country_Name__c = 'United Kingdom'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Country_Name__c = 'GB'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Country_Name__c = 'GBR'
            ),
            new CVENT__Cvent_Event__c (
                CVENT__Country_Name__c = 'UK'
            )
        };
        insert cventEvents;
        cventEvents = [
            SELECT CVENT__Event_Address_Country__c, Event_Address_Region__c, Event_Address_Continent__c
            FROM CVENT__Cvent_Event__c
            WHERE Id IN :cventEvents
        ];
        for (CVENT__Cvent_Event__c cventEvent : cventEvents) {
            System.assertEquals('EMEA', cventEvent.Event_Address_Region__c);
            System.assertEquals('Europe', cventEvent.Event_Address_Continent__c);
        }
        CVENT__Cvent_Event__c cventEvent = [
            SELECT CVENT__Event_Address_Country__c, Event_Address_Region__c, Event_Address_Continent__c
            FROM CVENT__Cvent_Event__c
            WHERE Id = :cventEvents[0].Id
        ];
        cventEvent.CVENT__Event_Address_Country__c = 'CN';
        update cventEvent;
        cventEvent = [
            SELECT CVENT__Event_Address_Country__c, Event_Address_Region__c, Event_Address_Continent__c
            FROM CVENT__Cvent_Event__c
            WHERE Id = :cventEvent.Id
        ];
        System.assertEquals('APAC', cventEvent.Event_Address_Region__c);
        System.assertEquals('Asia', cventEvent.Event_Address_Continent__c);
    }

    @IsTest
    static void setProductRegionFields() {
        CCACAMSTestUtil testUtil = new CCACAMSTestUtil();
        ccrz__E_Product__c testProduct = testUtil.createProduct('Test', 'TEST', 'acams', 'Conferences');
        testProduct.Event_Address_Country__c = 'CAN';
        insert testProduct;
        testProduct = [
            SELECT Event_Address_Country__c, Event_Address_Region__c, Event_Address_Continent__c
            FROM ccrz__E_Product__c
            WHERE Id = :testProduct.Id
        ];
        System.assertEquals('Americas', testProduct.Event_Address_Region__c);
        System.assertEquals('North America', testProduct.Event_Address_Continent__c);
        testProduct.Event_Address_Country__c = 'CN';
        update testProduct;
        testProduct = [
            SELECT Event_Address_Country__c, Event_Address_Region__c, Event_Address_Continent__c
            FROM ccrz__E_Product__c
            WHERE Id = :testProduct.Id
        ];
        System.assertEquals('APAC', testProduct.Event_Address_Region__c);
        System.assertEquals('Asia', testProduct.Event_Address_Continent__c);
    }
}