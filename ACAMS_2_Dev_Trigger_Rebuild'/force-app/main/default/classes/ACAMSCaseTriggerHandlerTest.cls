@IsTest
class ACAMSCaseTriggerHandlerTest {

    @IsTest
    static void createCaseWithCountry() {
        List<Case> testCases = new List<Case>{
                new Case(
                        Subject = 'Test 1',
                        AddressCountry__c = 'CA'
                ),
                new Case(
                        Subject = 'Test 2',
                        AddressCountry__c = 'AU'
                )
        };
        insert testCases;
        for (Case testCase : [
                SELECT AddressCountry__c, AddressRegion__c
                FROM Case
                WHERE Id IN :testCases
        ]) {
            if (testCase.AddressCountry__c == 'CA') {
                System.assertEquals('Americas', testCase.AddressRegion__c);
            } else if (testCase.AddressCountry__c == 'AU') {
                System.assertEquals('APAC', testCase.AddressRegion__c);
            }
        }
    }

}