public with sharing class ACAMSAccountTriggerHandler extends CCAviTriggerHandler {
    private List<Account> newList = (List<Account>) Trigger.new;
    private List<Account> oldList = (List<Account>) Trigger.old;
    private Map<Id, Account> newMap = (Map<Id, Account>) Trigger.newMap;
    private Map<Id, Account> oldMap = (Map<Id, Account>) Trigger.oldMap;

    protected override void beforeInsert() {
        this.setFieldsFromCountrySettings(this.newList);
    }
    protected override void beforeUpdate() {
        this.setFieldsFromCountrySettings(
                this.getAccountsWithBillingCountryCodeChanged(this.newList, this.oldMap)
        );
        List<String> accountGroupNames = new List<String>{
                ACAMSUtil.PORTAL_ACCOUNT,
                ACAMSUtil.PORTAL_ACCOUNT_GOV,
                ACAMSUtil.PORTAL_ACCOUNT_GOV_MEMBER,
                ACAMSUtil.PORTAL_ACCOUNT_MEMBER
        };
        List<ccrz__E_AccountGroup__c> accountGroups = [
                SELECT Id, Name
                FROM ccrz__E_AccountGroup__c
                WHERE Name IN :accountGroupNames
        ];
        Map<String, Id> accountGroupsMap = new Map<String, Id>();
        for (ccrz__E_AccountGroup__c accountGroup : accountGroups) {
            accountGroupsMap.put(accountGroup.Name, accountGroup.Id);
        }

        for (Account account : newList) {
            if (account.IsPersonAccount) {
                String oldMembershipType = oldMap.get(account.Id).Membership_Type__pc;
                String newMembershipType = newMap.get(account.Id).Membership_Type__pc;
                if (oldMembershipType != newMembershipType) {
                    String email = newMap.get(account.Id).PersonEmail;
                    Boolean govEmail = email.endsWith('.gov') || email.endsWith('.mil');
                    if ((oldMembershipType == null || oldMembershipType == ACAMSUtil.NON_MEMBER_CAPS) &&
                            newMembershipType == ACAMSUtil.MEMBER_CAPS) {
                        // UPGRADE FROM NON-MEMBER TO MEMBER BY EMAIL
                        if (govEmail) {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT_GOV_MEMBER);
                        } else {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT_MEMBER);
                        }
                    } else if ((oldMembershipType == ACAMSUtil.ENTERPRISE_CAPS ||
                            oldMembershipType == ACAMSUtil.MEMBER_CAPS) && (newMembershipType == null ||
                            newMembershipType == ACAMSUtil.NON_MEMBER_CAPS)) {
                        // DOWNGRADE TO NON-MEMBER BY EMAIL
                        if (govEmail) {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT_GOV);
                        } else {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT);
                        }

                    } else if (oldMembershipType == ACAMSUtil.ENTERPRISE_CAPS &&
                            newMembershipType == ACAMSUtil.MEMBER_CAPS) {
                        // DOWNGRADE TO MEMBER BY EMAIL
                        if (govEmail) {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT_GOV_MEMBER);
                        } else {
                            account.ccrz__E_AccountGroup__c = accountGroupsMap.get(ACAMSUtil.PORTAL_ACCOUNT_MEMBER);
                        }
                    }
                }
            }
        }
    }
    private List<Account> getAccountsWithBillingCountryCodeChanged(List<Account> currentAccounts, Map<Id, Account> oldAccounts) {
        List<Account> accountsWithBillingCountryChanges = new List<Account>();
        for (Account account : currentAccounts) {
            Account oldAccount = oldAccounts.get(account.Id);
            if (oldAccount.BillingCountryCode != account.BillingCountryCode) {
                accountsWithBillingCountryChanges.add(account);
            }
        }
        return accountsWithBillingCountryChanges;
    }

    private void setFieldsFromCountrySettings(List<Account> accounts) {
        Set<String> countryCodes = new Set<String>();
        Map<String, String> settingsMap = new Map<String, String>();
        for (Account accountToUpdate : accounts) {
            if (!String.isBlank(accountToUpdate.BillingCountryCode)) {
                countryCodes.add(accountToUpdate.BillingCountryCode);
            }
        }
        for (CountrySettings__mdt countrySetting : [
                SELECT Region__c, Continent__c, Named_Territory__c, SubTerritory__c
                FROM CountrySettings__mdt
                WHERE DeveloperName IN :countryCodes
        ]) {
            settingsMap.put('region', countrySetting.Region__c);
            settingsMap.put('namedTerritory', countrySetting.Named_Territory__c);
            settingsMap.put('subTerritory', countrySetting.SubTerritory__c);
            settingsMap.put('continent', countrySetting.Continent__c);
        }
        for (Account accountToUpdate : accounts) {
            accountToUpdate.Billing_Region__c = settingsMap.get('region');
            accountToUpdate.Billing_Named_Territory__c = settingsMap.get('namedTerritory');
            accountToUpdate.Billing_SubTerritory__c = settingsMap.get('subTerritory');
            accountToUpdate.Billing_Continent__c = settingsMap.get('continent');
        }
    }
}