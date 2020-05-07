public without sharing class ACAMSOpportunityService {

    public static Boolean replaceOpportunityCartWithQuoteCart(
        Opportunity targetOpportunity,
        Id newOpportunityCartId
    ) {
        initCsrCallContext(targetOpportunity.Id);
        Boolean removalSuccessful = false;
        Id cartToRemoveId = targetOpportunity.CC_Cart__c;
        if (cartToRemoveId != null) {
            cleanCartAddressLookups(cartToRemoveId);
            Map<String, Object> inputData = new Map<String,Object>{
                ccrz.ccApiCart.CART_ID => cartToRemoveId,
                ccrz.ccApi.API_VERSION => 9
            };
            Map<String, Object> outputData = ccrz.ccAPICart.removeCart(inputData);
            removalSuccessful = (Boolean) outputData.get(ccrz.ccApi.SUCCESS);
        } else {
            removalSuccessful = true;
        }
        updateOpportunityCartById(targetOpportunity.Id, newOpportunityCartId);
        return removalSuccessful;
    }

    public static Boolean cloneCartToOpportunity(Opportunity targetOpportunity, Id cartId) {
        initCsrCallContext(targetOpportunity.Id);
        Boolean wasSuccessful = false;
        Map<String, Object> inputData = new Map<String,Object> {
            ccrz.ccApiCart.CART_ID => cartId,
            ccrz.ccApi.API_VERSION => ccrz.ccApi.CURRENT_VERSION,
            ccrz.ccAPI.SIZING => new Map<String, Object>{
                ccrz.ccAPICart.ENTITYNAME => new Map<String, Object>{
                    ccrz.ccAPI.SZ_DATA => ccrz.ccAPI.SZ_XL
                },
                ccrz.ccAPICart.CLI_ENTITYNAME => new Map<String, Object>{
                    ccrz.ccAPI.SZ_DATA => ccrz.ccAPI.SZ_XL
                }
            }
        };
        Map<String, Object> outputData = ccrz.ccAPICart.cloneCart(inputData);
        wasSuccessful = (Boolean)outputData.get(ccrz.ccApi.SUCCESS);
        if (wasSuccessful) {
            wasSuccessful = (Boolean)outputData.get(ccrz.ccApi.SUCCESS);
            Id newCartId = (Id) outputData.get(ccrz.ccApiCart.CART_ID);
            updateOpportunityCartById(targetOpportunity.Id, newCartId);
        }
        return wasSuccessful;
    }

    public static Boolean createNewCartForOpportunity(Opportunity targetOpportunity) {
        initCsrCallContext(targetOpportunity.AccountId, null, null, targetOpportunity.Contact__c);
        Boolean wasSuccessful = false;
        Map<String,Object> createResults = ccrz.ccApiCart.create(new Map<String,Object>{
            ccrz.ccApi.API_VERSION => 9
        });
        wasSuccessful = (Boolean)createResults.get(ccrz.ccApi.SUCCESS);
        if (wasSuccessful) {
            String newCartId = (String)createResults.get(ccrz.ccApiCart.CART_ENCID);
            ccrz__E_Cart__c[] newCarts = [
                SELECT Id
                FROM ccrz__E_Cart__c
                WHERE ccrz__EncryptedId__c = :newCartId
                LIMIT 1
            ];
            if (!newCarts.isEmpty()) {
                updateOpportunityCartById(targetOpportunity.Id, newCarts[0].Id);
            }
        }
        return wasSuccessful;
    }

    private static void cleanCartAddressLookups(Id cartId) {
        ccrz__E_Cart__c cartToClean = new ccrz__E_Cart__c (
            Id = cartId,
            ccrz__BillTo__c = null,
            ccrz__ShipTo__c = null
        );
        update cartToClean;
    }

    private static void updateOpportunityCartById(Id opportunityId, Id cartId) {
        Opportunity opportunityToUpdate = new Opportunity(
            Id = opportunityId,
            CC_Cart__c = cartId
        );
        update opportunityToUpdate;

        ccrz__E_Cart__c cartToUpdate = new ccrz__E_Cart__c(
                Id = cartId,
                Opportunity__c = opportunityId
        );
        update cartToUpdate;
    }

    private static void initCsrCallContext(Id accountId, String accountName, String cartEncryptedId, Id contact) {
        Account effectiveAccount = new Account(
            Id = accountId,
            Name = accountName
        );
        ACAMSCsrService.initCsrCallContext(effectiveAccount, cartEncryptedId, contact);
    }

    private static void initCsrCallContext(Id OpportunityId) {
        Opportunity effectiveOpportunity = [
            SELECT Id, Account.Name, AccountId, CC_Cart__r.ccrz__EncryptedId__c, Contact__c
            FROM Opportunity
            WHERE Id = :OpportunityId
        ];
        initCsrCallContext(
            effectiveOpportunity.AccountId,
            effectiveOpportunity.Account.Id,
            effectiveOpportunity.CC_Cart__r.ccrz__EncryptedId__c,
            effectiveOpportunity.Contact__c
        );
    }
}