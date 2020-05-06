global class ACAMSAssetTermRecalculationScheduler implements Schedulable, Database.Batchable<sObject> {

    private static final String ASSET_STATUS_ACTIVE = 'Active';
    private static final String ASSET_STATUS_INACTIVE = 'Inactive';

    global void execute(SchedulableContext context) {
        Database.executeBatch(new ACAMSAssetTermRecalculationScheduler());
    }

    global Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Asset__c, Asset__r.Status__c, Asset__r.CC_Product__c
            FROM Asset_Term__c
            WHERE Expiration_Date__c = YESTERDAY
        ]);
    }

    global void execute(Database.BatchableContext context, List<Asset_Term__c> assetTerms) {
        Set<Id> targetAssetIds = new Set<Id>();
        List<Asset> assetsToUpdate = new List<Asset>();
        for (Asset_Term__c assetTerm : assetTerms) {
            targetAssetIds.add(assetTerm.Asset__c);
        }
        for(Asset targetAsset : [
            SELECT
                Id, Status__c, CC_Product__c,
                (
                    SELECT Id, CC_Product__c, Paid__c
                    FROM Asset_Terms__r
                    WHERE Start_Date__c >= TODAY
                    ORDER BY Start_Date__c ASC
                    LIMIT 1
                )
            FROM Asset
            WHERE Id IN :targetAssetIds
        ]) {
            if (targetAsset.Asset_Terms__r.isEmpty() && targetAsset.Status__c == ASSET_STATUS_ACTIVE) {
                assetsToUpdate.add(new Asset(
                    Id = targetAsset.Id,
                    Status__c = ASSET_STATUS_INACTIVE
                ));
            } else if (!targetAsset.Asset_Terms__r.isEmpty()) {
                Asset_Term__c newAssetTerm = targetAsset.Asset_Terms__r[0];
                String newStatus = newAssetTerm.Paid__c ? ASSET_STATUS_ACTIVE : ASSET_STATUS_INACTIVE;
                Id newProductId = newAssetTerm.CC_Product__c;
                if (targetAsset.CC_Product__c != newProductId || targetAsset.Status__c != newStatus) {
                    assetsToUpdate.add(new Asset(
                        Id = targetAsset.Id,
                        CC_Product__c = newProductId,
                        Status__c = newStatus
                    ));
                }
            }
        }
        if (!assetsToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(assetsToUpdate, false);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, result);
                }
            }
        }
    }

    global void finish(Database.BatchableContext context) {

    }

}