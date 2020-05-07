public without sharing class ACAMSUserTriggerHandler extends CCAviTriggerHandler {
    private List<User> newUsers;
    private Map<Id, User> newMap;

    public ACAMSUserTriggerHandler() {
        this.newUsers = (List<User>) Trigger.new;
        this.newMap = (Map<Id, User>) Trigger.newMap;
    }

    public override void afterInsert() {
        Id b2bCommerceUserId;

        Profile profile = ACAMSUserDAO.getB2BProfile();
        b2bCommerceUserId = profile != null ? profile.Id : null;
        ccrz__E_AccountGroup__c portalAccount = ACAMSUserDAO.getAccountGroupByName(ACAMSUtil.PORTAL_ACCOUNT);
        ccrz__E_AccountGroup__c govMilPortalAccount =
                ACAMSUserDAO.getAccountGroupByName(ACAMSUtil.PORTAL_ACCOUNT_GOV);

        Set<Id> accountIds = new Set<Id>();

        if (b2bCommerceUserId != null) {
            for (User u : this.newUsers) {
                if (u.ProfileId == b2bCommerceUserId) {
                    accountIds.add(u.AccountId);
                }
            }

            List<Account> accounts = ACAMSAccountDAO.getAccountsFromId(accountIds);
            Set<Id> userIds = new Set<Id>();
            for (Id userId : newMap.keySet()) {
                if (newMap.get(userId).ContactId != null) {
                    userIds.add(userId);
                }
            }

            Map<Id, Id> accountIdToCommunityIdMap = new Map<Id, Id>();
            Map<Id, User> usersMap = new Map<Id, User>(
                    ACAMSUserDAO.queryContactAccountsByIds(userIds)
            );

            for (Id userId : userIds) {
                try {
                    Id accountId = usersMap.get(userId).Contact.AccountId;
                    Id communityId = usersMap.get(userId).Contact.Account.CommunityUser__c;
                    if (communityId != userId) {
                        accountIdToCommunityIdMap.put(accountId, userId);
                    }
                } catch (Exception ex) {
                    System.debug(ex.getMessage() + '\n' + ex.getStackTraceString());
                }
            }
            for (Account account : accounts) {
                if (account.PersonEmail.endsWith('.gov') || account.PersonEmail.endsWith('.mil')) {
                    account.ccrz__E_AccountGroup__c = govMilPortalAccount.Id;
                } else {
                    account.ccrz__E_AccountGroup__c = portalAccount.Id;
                }
                account.Type = ACAMSUtil.CUSTOMER;
                Id communityId = accountIdToCommunityIdMap.get(account.Id);
                account.CommunityUser__c = communityId;
            }

            if (Test.isRunningTest()) {
                update accounts;
            } else if (!System.isFuture() && !accounts.isEmpty()) {
                System.enqueueJob(new ACAMSUtil.UpdateObject(accounts));
            }
        }
    }
}