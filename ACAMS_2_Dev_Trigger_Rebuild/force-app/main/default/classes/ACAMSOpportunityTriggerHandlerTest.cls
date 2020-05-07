@isTest
public class ACAMSOpportunityTriggerHandlerTest {
    @isTest
    public static void  updateCouponsTest() {
        Account acc = new Account(
            ccrz__TaxExemptAccount__c = true,
            Name = 'acc'
        );
        insert acc;

        ccrz__E_ContactAddr__c testAddress = new ccrz__E_ContactAddr__c(
            OwnerId = UserInfo.getUserId() ,
            ccrz__AddressFirstline__c = 'line1',
            ccrz__AddressSecondline__c = 'line2',
            ccrz__AddressThirdline__c = 'line3',
            ccrz__City__c = 'city',
            ccrz__State__c = 'state',
            ccrz__Country__c = 'country',
            ccrz__CountryISOCode__c = 'US',
            ccrz__PostalCode__c = 'postalCode',
            Vertex_Tax_Area_Id__c = 0
        );
        ACAMSContactAddressTriggerHandler.skipAddressValidation = true;
        insert testAddress;
        System.debug(testAddress.Id);
        ccrz__E_Cart__c cartUnSync = new ccrz__E_Cart__c(
            ccrz__ShipAmount__c =2,
            ccrz__TotalDiscount__c =2,
            ccrz__BillTo__c = testAddress.Id,
            ccrz__ShipTo__c = testAddress.Id,
            ccrz__Account__c = acc.Id
        );
        insert cartUnSync;
        ccrz__E_Cart__c cartSync = new ccrz__E_Cart__c(

            ccrz__ShipAmount__c =2,
            ccrz__TotalDiscount__c =2,
            ccrz__BillTo__c = testAddress.Id,
            ccrz__ShipTo__c = testAddress.Id,
            ccrz__Account__c = acc.Id
        );
        insert cartSync;
        ccrz__E_CartItem__c  cItem = new ccrz__E_CartItem__c(
            ccrz__Cart__c = cartUnSync.Id,
            ccrz__SubAmount__c= 300,
            ccrz__Price__c = 20

        );
        insert  cItem;
        Opportunity  testOpportunity= new Opportunity(
            CloseDate = Date.today().addDays(2000),
            ForecastCategoryName = 'Pipeline',
            Name = 'testOpp',
            Probability = 100,
            StageName ='Qualification',
            SyncedQuoteId = null,
            Coupon_Code__c ='test',
            CC_Cart__c = cartUnSync.Id
        );
        insert testOpportunity;
        testOpportunity = [
            SELECT Id, CC_Cart__c, CC_Cart__r.ccrz__ShipTo__c
            FROM Opportunity
            WHERE Id = :testOpportunity.Id
        ];
        System.debug(testOpportunity.CC_Cart__c);
        System.debug(testOpportunity.CC_Cart__r.ccrz__ShipTo__c);
        update new ccrz__E_Cart__c(
            Id = testOpportunity.CC_Cart__c,
            ccrz__ShipTo__c = testAddress.Id
        );
        Quote quote = new Quote(
            Name= 'testQuote',
            OpportunityId = testOpportunity.Id//,
          //  CC_Cart__c= cartSync.Id

        );
        insert quote;
        // testOpportunity.SyncedQuoteId = quote.id;

        testOpportunity.Coupon_Code__c = 'second';
        update testOpportunity;

    }
}