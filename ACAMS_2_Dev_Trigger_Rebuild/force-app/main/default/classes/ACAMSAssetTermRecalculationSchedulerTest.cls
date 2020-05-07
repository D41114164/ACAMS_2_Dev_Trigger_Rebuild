@IsTest
public class ACAMSAssetTermRecalculationSchedulerTest {

    @TestSetup
    static void initData() {
        CCACAMSTestUtil testUtil = new CCACAMSTestUtil();
        Account testAccount = new Account(
            Name = 'test'
        );
        insert testAccount;
        List<ccrz__E_Product__c> products = new List<ccrz__E_Product__c>{
                testUtil.createProduct('Test 1', 'TEST1', 'Membership'),
                testUtil.createProduct('Test 2', 'TEST2', 'Membership')
        };
        insert products;
        Asset testAsset = new Asset(
                Name = 'test',
                AccountId = testAccount.Id,
                Status__c = 'Active',
                CC_Product__c = products[0].Id,
                Assignee__c = testAccount.PersonContactId
        );
        insert testAsset;
        List<Asset_Term__c> terms = new List<Asset_Term__c>{
            new Asset_Term__c(
                Asset__c = testAsset.Id,
                CC_Product__c = products[0].Id,
                Paid__c = false,
                Start_Date__c = Date.today().addDays(-2),
                Expiration_Date__c = Date.today().addDays(-1)
            ),
            new Asset_Term__c(
                Asset__c = testAsset.Id,
                CC_Product__c = products[1].Id,
                Paid__c = true,
                Start_Date__c = Date.today(),
                Expiration_Date__c = Date.today().addDays(1)
            )
        };
        insert terms;
    }

    @IsTest
    static void updateAssetInBatch() {
        Test.startTest();
        Database.executeBatch(new ACAMSAssetTermRecalculationScheduler());
        Test.stopTest();
        Asset testAsset = [
            SELECT Status__c, CC_Product__r.Name
            FROM Asset
            LIMIT 1
        ];
        System.assertEquals('Active', testAsset.Status__c);
        System.assertEquals('Test 2', testAsset.CC_Product__r.Name);
    }

    @IsTest
    static void updateAssetInBatchWithoutNewTerm() {
        Asset_Term__c newTerm = [
            SELECT Id
            FROM Asset_Term__c
            WHERE Start_Date__c = :Date.today()
            LIMIT 1
        ];
        delete newTerm;
        Asset testAsset = [
            SELECT Status__c
            FROM Asset
            LIMIT 1
        ];
        testAsset.Status__c = 'Active';
        update testAsset;
        Test.startTest();
        Database.executeBatch(new ACAMSAssetTermRecalculationScheduler());
        Test.stopTest();
        testAsset = [
            SELECT Status__c
            FROM Asset
            LIMIT 1
        ];
        System.assertEquals('Inactive', testAsset.Status__c);
    }

    @IsTest
    static void updateAssetInSchedule() {
        Test.startTest();
        Id jobId = System.schedule('Test', '0 0 23 * * ?', new ACAMSAssetTermRecalculationScheduler());
        Test.stopTest();
        CronTrigger job = [
            SELECT TimesTriggered
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job);
    }

}