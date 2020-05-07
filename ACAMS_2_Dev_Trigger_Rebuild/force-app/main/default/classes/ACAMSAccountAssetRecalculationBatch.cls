global without sharing class ACAMSAccountAssetRecalculationBatch implements Database.Batchable<AggregateResult>, Database.Stateful, Schedulable {

    private Datetime lastModifiedDateThreshold = Datetime.now().addHours(-1).addMinutes(-1);

    global ACAMSAccountAssetRecalculationBatch() {
    }

    global ACAMSAccountAssetRecalculationBatch(Datetime lastModifiedDateThreshold) {
        this.lastModifiedDateThreshold = lastModifiedDateThreshold;
    }

    global void execute(SchedulableContext context) {
        Database.executeBatch(new ACAMSAccountAssetRecalculationBatch());
    }

    global Iterable<AggregateResult> start(Database.BatchableContext context) {
        return [
                SELECT AccountId
                FROM Asset
                WHERE LastModifiedDate > :this.lastModifiedDateThreshold
                GROUP BY AccountId
                LIMIT 10000
        ];
    }

    global void execute(Database.BatchableContext context, List<AggregateResult> accountAggregateResults) {
        Set<Id> accountIds = new Set<Id>();
        Map<Id, Decimal> assignedAssetCountByAccountId = new Map<Id, Decimal>();
        Map<Id, Decimal> unassignedAssetCountByAccountId = new Map<Id, Decimal>();
        Map<Id, Decimal> educationalCreditCountByAccountId = new Map<Id, Decimal>();
        List<Account> accountsToUpdate = new List<Account>();
        for (AggregateResult accountAggregateResult : accountAggregateResults) {
            accountIds.add((Id) accountAggregateResult.get('AccountId'));
        }
        collectAssetSummary(accountIds, assignedAssetCountByAccountId, unassignedAssetCountByAccountId,
                educationalCreditCountByAccountId);
        for (Account accountToCheck : [
                SELECT Id, Assets_Assigned__c, Assets_Unassigned__c, Total_Educational_Credits__c
                FROM Account
                WHERE Id IN :accountIds
        ]) {
            Decimal assetsAssigned = assignedAssetCountByAccountId.get(accountToCheck.Id);
            Decimal assetsUnassigned = unassignedAssetCountByAccountId.get(accountToCheck.Id);
            Decimal totalEducationalCredits = educationalCreditCountByAccountId.get(accountToCheck.Id);
            assetsAssigned = assetsAssigned == null ? 0 : assetsAssigned;
            assetsUnassigned = assetsUnassigned == null ? 0 : assetsUnassigned;
            totalEducationalCredits = totalEducationalCredits == null ? 0 : totalEducationalCredits;
            if (accountToCheck.Assets_Assigned__c != assetsAssigned ||
                    accountToCheck.Assets_Unassigned__c != assetsUnassigned ||
                    accountToCheck.Total_Educational_Credits__c != totalEducationalCredits) {
                accountToCheck.Assets_Assigned__c = assetsAssigned;
                accountToCheck.Assets_Unassigned__c = assetsUnassigned;
                accountToCheck.Total_Educational_Credits__c = accountToCheck.Total_Educational_Credits__c != null ?
                        accountToCheck.Total_Educational_Credits__c + totalEducationalCredits : totalEducationalCredits;
                accountsToUpdate.add(accountToCheck);
            }
        }
        List<Database.SaveResult> results = Database.update(accountsToUpdate, false);
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, result);
            }
        }

    }

    global void finish(Database.BatchableContext context) {}

    private void collectAssetSummary(
            Set<Id> accountIds,
            Map<Id, Decimal> assignedAssetCountByAccountId,
            Map<Id, Decimal> unassignedAssetCountByAccountId,
            Map<Id, Decimal> educationalCreditCountByAccountId
    ) {
        for (Asset asset : [
                SELECT AccountId, CC_Product__r.Educational_Credits__c
                FROM Asset
                WHERE Assignee__c != NULL
                AND AccountId IN :accountIds
                LIMIT 200
        ]) {
            if (educationalCreditCountByAccountId.containsKey(asset.AccountId)) {
                Decimal educationalCredits = educationalCreditCountByAccountId.get(asset.AccountId);
                if (asset.CC_Product__r.Educational_Credits__c != null) {
                    educationalCreditCountByAccountId.put(asset.AccountId, educationalCredits +
                            (Decimal) asset.CC_Product__r.Educational_Credits__c);
                }
            } else {
                if (asset.CC_Product__r.Educational_Credits__c != null) {
                    educationalCreditCountByAccountId.put(asset.AccountId,
                            (Decimal) asset.CC_Product__r.Educational_Credits__c);
                }
            }
        }

        for (AggregateResult assetAssignedAggregateResult : [
                SELECT COUNT(Id) AssetCount, AccountId
                FROM Asset
                WHERE Assignee__c != NULL
                AND AccountId IN :accountIds
                GROUP BY AccountId
                LIMIT 200
        ]) {
            assignedAssetCountByAccountId.put(
                    (Id) assetAssignedAggregateResult.get('AccountId'),
                    (Decimal) assetAssignedAggregateResult.get('AssetCount')
            );
        }
        for (AggregateResult assetUnassignedAggregateResult : [
                SELECT COUNT(Id) AssetCount, AccountId
                FROM Asset
                WHERE Assignee__c = NULL
                AND AccountId IN :accountIds
                GROUP BY AccountId
                LIMIT 200
        ]) {
            unassignedAssetCountByAccountId.put(
                    (Id) assetUnassignedAggregateResult.get('AccountId'),
                    (Decimal) assetUnassignedAggregateResult.get('AssetCount')
            );
        }
    }
}