@IsTest
class ACAMSCventEventServiceTest {

    @TestSetup
    static void initData() {
        ACAMS_CSR_Settings__mdt[] settingsRecords = [
                SELECT DeveloperName, Private_Pricelist_Name__c
                FROM ACAMS_CSR_Settings__mdt
                LIMIT 1
        ];
        if (!settingsRecords.isEmpty()) {
            insert new ccrz__E_PriceList__c(
                    Name = settingsRecords[0].Private_Pricelist_Name__c
            );
        }
    }

    @IsTest
    static void testInsertProduct() {
        CVENT__Cvent_Event__c testEvent = new CVENT__Cvent_Event__c(
                Name = 'test Event',
                CVENT__Event_Code__c = 'test'
        );
        Test.startTest();
        insert testEvent;
        Test.stopTest();
        ccrz__E_Product__c product = [
                SELECT Id, Name, Cvent_Event__c, ccrz__SKU__c
                FROM ccrz__E_Product__c
                LIMIT 1
        ];
        System.assertEquals(testEvent.Name, product.Name);
        System.assertEquals('CVENT-' + testEvent.CVENT__Event_Code__c, product.ccrz__SKU__c);
        System.assertEquals(testEvent.Id, product.Cvent_Event__c);
        ACAMS_CSR_Settings__mdt[] settingsRecords = [
                SELECT DeveloperName, Private_Pricelist_Name__c
                FROM ACAMS_CSR_Settings__mdt
                LIMIT 1
        ];
        if (!settingsRecords.isEmpty()) {
            ccrz__E_PriceListItem__c pricelistItem = [
                    SELECT ccrz__Pricelist__r.Name
                    FROM ccrz__E_PricelistItem__c
                    WHERE ccrz__Product__c = :product.Id
                    LIMIT 1
            ];
            System.assertEquals(settingsRecords[0].Private_Pricelist_Name__c, pricelistItem.ccrz__Pricelist__r.Name);
        }
    }

    @IsTest
    static void testCheckoutWithEvent() {
        CVENT__Cvent_Event__c testEvent = new CVENT__Cvent_Event__c(
                Name = 'test Event',
                CVENT__Event_Code__c = 'test'
        );
        insert testEvent;
        ccrz__E_Product__c product = [
                SELECT Id, Name, Cvent_Event__c, ccrz__SKU__c
                FROM ccrz__E_Product__c
                LIMIT 1
        ];
        Account testAccount = new Account(
                Name = 'test',
                ccrz__TaxExemptAccount__c = true
        );
        insert testAccount;
        Contact testContact = new Contact(
                AccountId = testAccount.Id,
                FirstName = 'Test',
                LastName = 'Test',
                Email = 'test@test.com'
        );
        insert testContact;
        Test.startTest();
        ccrz__E_Order__c order = new ccrz__E_Order__c(
                ccrz__Account__c = testAccount.Id,
                ccrz__Contact__c = testContact.Id
        );
        insert order;
        ccrz__E_OrderItem__c orderItem = new ccrz__E_OrderItem__c(
                ccrz__Order__c = order.Id,
                ccrz__Product__c = product.Id,
                ccrz__Price__c = 1,
                ccrz__Quantity__c = 1,
                ccrz__SubAmount__c = 1
        );
        insert orderItem;
        orderItem = [
                SELECT Id, ccrz__Order__c, ccrz__Product__c, ccrz__Product__r.Cvent_Event__c
                FROM ccrz__E_OrderItem__c
                WHERE Id = :orderItem.Id
        ];
        ACAMSCventEventService.EventNominationCreationResults result = ACAMSCventEventService.registerContactOnEvent(
                order,
                new ccrz__E_OrderItem__c[]{
                        orderItem
                }
        );
        Test.stopTest();
        System.assert(result.isSuccess);
        System.assert(!result.invitees.isEmpty());
        System.assert(!result.nominations.isEmpty());
    }

    @IsTest
    static void testReplaceInviteeWithInternal() {
        CVENT__Cvent_Event__c testEvent = new CVENT__Cvent_Event__c(
                Name = 'test Event',
                CVENT__Event_Code__c = 'test'
        );
        insert testEvent;
        ccrz__E_Product__c product = [
                SELECT Id, Name, Cvent_Event__c, ccrz__SKU__c
                FROM ccrz__E_Product__c
                LIMIT 1
        ];
        Account testAccount = new Account(
                Name = 'test',
                ccrz__TaxExemptAccount__c = true
        );
        insert testAccount;
        Contact testContact = new Contact(
                AccountId = testAccount.Id,
                FirstName = 'Test',
                LastName = 'Test',
                Email = 'test@test.com'
        );
        insert testContact;
        Test.startTest();
        ccrz__E_Order__c order = new ccrz__E_Order__c(
                ccrz__Account__c = testAccount.Id,
                ccrz__Contact__c = testContact.Id
        );
        insert order;
        ccrz__E_OrderItem__c orderItem = new ccrz__E_OrderItem__c(
                ccrz__Order__c = order.Id,
                ccrz__Product__c = product.Id,
                ccrz__Price__c = 1,
                ccrz__Quantity__c = 1,
                ccrz__SubAmount__c = 1
        );
        insert orderItem;
        orderItem = [
                SELECT Id, ccrz__Order__c, ccrz__Product__c, ccrz__Product__r.Cvent_Event__c
                FROM ccrz__E_OrderItem__c
                WHERE Id = :orderItem.Id
        ];
        ACAMSCventEventService.EventNominationCreationResults result = ACAMSCventEventService.registerContactOnEvent(
                order,
                new ccrz__E_OrderItem__c[]{
                        orderItem
                }
        );
        CVENT__Invitee__c inviteeFromCventService = new CVENT__Invitee__c(
                CVENT__Contact_Id__c = testContact.Id,
                CVENT__Event_Id__c = testEvent.Id,
                CVENT__Confirmation_Number__c = 'TEST123'
        );
        insert inviteeFromCventService;
        List<CVENT__Invitee__c> invitees = [
                SELECT Id
                FROM CVENT__Invitee__c
        ];
        System.assertEquals(1, invitees.size());
        System.assertEquals(inviteeFromCventService.Id, invitees[0].Id);
    }

}