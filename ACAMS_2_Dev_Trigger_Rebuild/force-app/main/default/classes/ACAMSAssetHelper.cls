public with sharing class ACAMSAssetHelper {

    @Future
    public static void generateAssets(Id orderId) {
        ccrz__E_Order__c order = ACAMSOrderDAO.getOrder(orderId);
        RecordType assetRegistrantRecordType = [SELECT Id FROM RecordType WHERE Name = 'Registrant' AND SObjectType = 'Asset'];
        List<Asset> existingAssets = new List<Asset>();
        if (order.ccrz__Contact__c != null) {
            existingAssets = ACAMSAssetDAO.getAssetsByContactIds(new Set<Id>{
                    order.ccrz__Contact__c
            });
        }

        Set<String> existingAssetNames = new Set<String>();
        if (!existingAssets.isEmpty()) {
            for (Asset asset : existingAssets) {
                existingAssetNames.add(asset.Name);
            }
        }
        Map<Id, Asset_Group__c> idToAssetGroupMap = new Map<Id, Asset_Group__c>();
        Map<Id, List<Asset>> idToAssetListMap = new Map<Id, List<Asset>>();
        Map<Id, List<Asset>> assetsToLinkMap = new Map<Id, List<Asset>>();
        List<Asset_Term__c> assetTermsToInsert = new List<Asset_Term__c>();
        Set<Id> orderItemIds = new Set<Id>();

        for (ccrz__E_OrderItem__c orderItem : order.ccrz__E_OrderItems__r) {
            orderItemIds.add(orderItem.Id);
            if (orderItem.ccrz__Product__r.Name == 'Shipping Cost' ||
                    orderItem.ccrz__Product__r.Level_1__c == ACAMSUtil.ENTERPRISE_BUNDLE) {
                continue;
            }
            String level1 = orderItem.ccrz__Product__r.Level_1__c;
            String level2 = orderItem.ccrz__Product__r.Level_2__c;
            String level3 = orderItem.ccrz__Product__r.Level_3__c;

            String assetGroupName = level1;
            Boolean isRegistrant = false;

            if (level1 == ACAMSUtil.CERTIFICATION || (level1 == ACAMSUtil.CHAPTER && level2 == ACAMSUtil.MEMBERSHIP) ||
                    level1 == ACAMSUtil.PUBLICATION) {
                if (!String.isBlank(level2)) {
                    assetGroupName += ' - ' + level2;
                }
            } else if (level1 == ACAMSUtil.CONFERENCES ||
                    (level1 == ACAMSUtil.TRAINING &&
                            (level3 == ACAMSUtil.ATTENDANCE || level3 == ACAMSUtil.FACE_TO_FACE ||
                                    level3 == ACAMSUtil.SPONSORSHIP)) ||
                    (level1 == ACAMSUtil.CHAPTER && level2 == ACAMSUtil.EVENT)) {
                isRegistrant = true;
                if (String.isNotBlank(level2)) {
                    assetGroupName += ' - ' + level2;
                }
                if (String.isNotBlank(level3)) {
                    assetGroupName += ' - ' + level3;
                }
            } else if (level1 == ACAMSUtil.TRAINING && (level3 == ACAMSUtil.VIRTUAL_CLASSROOM ||
                    level3 == ACAMSUtil.ASYNCHRONOUS)) {
                if (String.isNotBlank(level2)) {
                    assetGroupName += ' - ' + level2;
                }
                if (String.isNotBlank(level3)) {
                    assetGroupName += ' - ' + level3;
                }
            }

            Asset_Group__c assetGroup = new Asset_Group__c();
            assetGroup.Name = assetGroupName;
            assetGroup.CC_Order__c = order.Id;
            assetGroup.CC_Order_Item__c = orderItem.Id;
            idToAssetGroupMap.put(orderItem.Id, assetGroup);

            if (existingAssetNames.contains(assetGroupName) && !isRegistrant) {
                for (Asset asset : existingAssets) {
                    if (asset.Name == assetGroupName) {
                        assetTermsToInsert.add(createAssetTerm(asset, orderItem));
                        List<Asset> assetList = assetsToLinkMap.get(orderItem.Id);
                        if (assetList == null) {
                            assetsToLinkMap.put(orderItem.Id, new List<Asset>{
                                    asset
                            });
                        } else {
                            assetList.add(asset);
                        }
                        break;
                    }
                }
            } else {
                for (Integer i = 0; i < orderItem.ccrz__Quantity__c; i++) {
                    Asset asset = new Asset();
                    if (isRegistrant) {
                        asset.RecordTypeId = assetRegistrantRecordType.Id;
                    }
                    if (i == 0) {
                        asset.ContactId = order.ccrz__Contact__c;
                        asset.Assignee__c = order.ccrz__Contact__c;
                    }
                    asset.InstallDate = order.ccrz__OrderDate__c;
                    asset.Status__c = ACAMSUtil.INACTIVE;
                    asset.CC_Product__c = orderItem.ccrz__Product__c;
                    asset.Name = assetGroupName;
                    asset.AccountId = order.ccrz__Account__c;
                    if (orderItem.ccrz__SubProdTerm__c != NULL) {
                        Decimal term = 12;
                        if (orderItem.ccrz__SubProdTerm__r.ccrz__InstallmentFrequencyUOM__c == 'Yearly') {
                            term = 12 * orderItem.ccrz__SubProdTerm__r.ccrz__InstallmentCount__c;
                        } else if (orderItem.ccrz__SubProdTerm__r.ccrz__InstallmentFrequencyUOM__c == 'Monthly') {
                            term = orderItem.ccrz__SubProdTerm__r.ccrz__InstallmentCount__c;
                        }
                        asset.Subscription_Term__c = term;
                    }
                    List<Asset> assetList = idToAssetListMap.get(orderItem.Id);
                    if (assetList == null) {
                        idToAssetListMap.put(orderItem.Id, new List<Asset>{
                                asset
                        });
                    } else {
                        assetList.add(asset);
                    }
                }
            }
        }
        insert idToAssetGroupMap.values();

        List<Asset> assetListToInsert = new List<Asset>();
        for (List<Asset> assetList : idToAssetListMap.values()) {
            assetListToInsert.addAll(assetList);
        }
        // TODO: Find solution for this workaround for occasional UNABLE_TO_LOCK_ROW errors.
        try {
            insert assetListToInsert;
        } catch (DmlException e) {
            System.debug('DmlException in ACAMSAssetHelper: ' + e.getMessage() + ' ' + e.getStackTraceString());
            insert assetListToInsert;
        }
        for (Asset asset : assetListToInsert) {
            if (asset.RecordTypeId != assetRegistrantRecordType.Id) {
                Asset_Term__c assetTerm = new Asset_Term__c();
                assetTerm.Asset__c = asset.Id;
                Decimal term = asset.Subscription_Term__c != null ? asset.Subscription_Term__c : 12;
                assetTerm.Expiration_Date__c = Date.today().addMonths(Integer.valueOf(term));
                assetTerm.Start_Date__c = Date.today();
                assetTerm.CC_Product__c = asset.CC_Product__c;
                assetTermsToInsert.add(assetTerm);
            }
        }

        insert assetTermsToInsert;

        List<Asset_Group_Item__c> assetGroupItems = new List<Asset_Group_Item__c>();
        for (Id orderItemId : idToAssetGroupMap.keySet()) {
            if (idToAssetListMap.containsKey(orderItemId)) {
                for (Asset asset : idToAssetListMap.get(orderItemId)) {
                    Asset_Group_Item__c assetGroupItem = new Asset_Group_Item__c();
                    assetGroupItem.Asset__c = asset.Id;
                    assetGroupItem.Asset_Group__c = idToAssetGroupMap.get(orderItemId).Id;
                    assetGroupItems.add(assetGroupItem);
                }
            }

            if (assetsToLinkMap.containsKey(orderItemId)) {
                for (Asset asset : assetsToLinkMap.get(orderItemId)) {
                    Asset_Group_Item__c assetGroupItem = new Asset_Group_Item__c();
                    assetGroupItem.Asset__c = asset.Id;
                    assetGroupItem.Asset_Group__c = idToAssetGroupMap.get(orderItemId).Id;
                    assetGroupItems.add(assetGroupItem);
                }
            }
        }

        insert assetGroupItems;
        if (order.ccrz__PaymentMethod__c == ACAMSUtil.CC && order.Opportunity__c == NULL) {
            activateAssets(orderItemIds);
        }
    }

    public static Asset_Term__c createAssetTerm(Asset asset, ccrz__E_OrderItem__c orderItem) {
        Asset_Term__c assetTerm = new Asset_Term__c();
        assetTerm.Asset__c = asset.Id;
        Date currentExpirationDate = asset.Current_Expiration_Date__c != null ?
                asset.Current_Expiration_Date__c : Date.today();
        Decimal term = orderItem.ccrz__Product__r.Term__c != null ?
                orderItem.ccrz__Product__r.Term__c : 12;
        assetTerm.Expiration_Date__c = currentExpirationDate.addMonths(Integer.valueOf(term));
        assetTerm.Start_Date__c = currentExpirationDate;
        assetTerm.CC_Product__c = orderItem.ccrz__Product__c;
        return assetTerm;
    }

    public static void activateAssets(Set<Id> orderItemIds) {
        List<Asset_Group__c> assetGroups = ACAMSAssetDAO.getAssetGroupsByOrderItemIds(orderItemIds);
        Set<Id> assetIds = new Set<Id>();
        for (Asset_Group__c assetGroup : assetGroups) {
            for (Asset_Group_Item__c assetGroupItem : assetGroup.Asset_Group_Items__r) {
                assetIds.add(assetGroupItem.Asset__c);
            }
        }
        List<Asset_Term__c> assetTerms = ACAMSAssetDAO.getAssetTermsByAssetIds(assetIds);
        for (Asset_Term__c assetTerm : assetTerms) {
            assetTerm.Paid__c = TRUE;
        }
        update assetTerms;

        List<Asset> assets = ACAMSAssetDAO.getAssetsByIds(assetIds);
        for (Asset asset : assets) {
            asset.Paid_Cert__c = TRUE;
            asset.Status__c = 'Active';
        }
        update assets;
    }
}