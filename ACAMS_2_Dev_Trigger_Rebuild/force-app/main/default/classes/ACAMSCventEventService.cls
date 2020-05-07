public with sharing class ACAMSCventEventService {

    private static final String CVENT_PRODUCT_SKU_TEMPLATE       = 'CVENT-';
    private static final String CVENT_PRODUCT_LEVEL_1            = 'Conferences';
    private static final String CVENT_INVITEE_STATUS_APPROVED    = 'Nomination Approved';
    private static final String CVENT_NOMINATION_STATUS_APPROVED = 'Approved';

    public class ProductCreationResults {
        public Boolean                    isSuccess      { get; set; }
        public ccrz__E_Product__c[]       products       { get; set; }
        public ccrz__E_PriceListItem__c[] priceListItems { get; set; }
    }

    public class EventNominationCreationResults {
        public Boolean                isSuccess   { get; set; }
        public CVENT__Invitee__c[]    invitees    { get; set; }
        public CVENT__Nomination__c[] nominations { get; set; }
    }

    public static ProductCreationResults createCCProductsForEvents(Map<Id, CVENT__Cvent_Event__c> newEvents) {
        ProductCreationResults result = new ProductCreationResults();
        ccrz__E_Product__c[] newEventProducts = new ccrz__E_Product__c[]{};
        for (CVENT__Cvent_Event__c newEvent : newEvents.values()) {
            newEventProducts.add(ACAMSCventEventService.createProductFromCventEvent(newEvent));
        }
        Savepoint savepoint = Database.setSavepoint();
        try {
            if (!newEventProducts.isEmpty()) {
                insert newEventProducts;
            }
            ccrz__E_PriceListItem__c[] priceListItems =
                    ACAMSCventEventService.getPriceListItems(newEventProducts, newEvents);
            if (!priceListItems.isEmpty()) {
                insert priceListItems;
            }
            result.isSuccess      = true;
            result.products       = newEventProducts;
            result.priceListItems = priceListItems;
        } catch (Exception e) {
            Database.rollback(savepoint);
            result.isSuccess = false;
        }
        return result;
    }

    public static EventNominationCreationResults registerContactOnEvent(ccrz__E_Order__c orderData, ccrz__E_OrderItem__c[] orderItems) {
        EventNominationCreationResults results = new EventNominationCreationResults();
        Id invitedContactId = orderData.ccrz__Contact__c;
        if (invitedContactId != null) {
            Savepoint savepoint = Database.setSavepoint();
            try {
                CVENT__Invitee__c[] invitees = ACAMSCventEventService.getInvitees(invitedContactId, orderItems);
                if (!invitees.isEmpty()) {
                    upsert invitees;
                }
                CVENT__Nomination__c[] nominations = ACAMSCventEventService.getNominations(invitees);
                if (!nominations.isEmpty()) {
                    upsert nominations;
                }
                results.isSuccess   = true;
                results.invitees    = invitees;
                results.nominations = nominations;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, e.getMessage());
                System.debug(LoggingLevel.ERROR, e.getStackTraceString());
                Database.rollback(savepoint);
                results.isSuccess = false;
            }
        }
        return results;
    }

    public static void removeInviteeDuplicates(List<CVENT__Invitee__c> invitees) {
        Map<String, CVENT__Invitee__c> newInviteeByUuid = new Map<String, CVENT__Invitee__c> ();
        List<CVENT__Invitee__c> inviteesToDelete = new List<CVENT__Invitee__c>();
        for (CVENT__Invitee__c invitee : invitees) {
            if (!String.isBlank(invitee.InviteeUUID__c)) {
                newInviteeByUuid.put(invitee.InviteeUUID__c, invitee);
            }
        }
        for (CVENT__Invitee__c oldInvitee : [
                SELECT
                        Id, CVENT__Confirmation_Number__c, InviteeUUID__c
                FROM
                        CVENT__Invitee__c
                WHERE
                        InviteeUUID__c IN :newInviteeByUuid.keySet()
                AND
                        Id NOT IN :invitees
        ]) {
            CVENT__Invitee__c newInvitee = newInviteeByUuid.get(oldInvitee.InviteeUUID__c);
            if (String.isBlank(oldInvitee.CVENT__Confirmation_Number__c) ||
                    !String.isBlank(newInvitee.CVENT__Confirmation_Number__c)) {
                inviteesToDelete.add(oldInvitee);
            }
        }
        Database.delete(inviteesToDelete);
    }

    private static CVENT__Invitee__c[] getInvitees(Id invitedContactId, ccrz__E_OrderItem__c[] orderItems) {
        CVENT__Invitee__c[] invitees = new CVENT__Invitee__c[]{};
        Map<Id, ccrz__E_OrderItem__c> orderItemByCventEventId = new Map<Id, ccrz__E_OrderItem__c>();
        for (ccrz__E_OrderItem__c orderItem : orderItems) {
            if (
                orderItem != null &&
                orderItem.ccrz__Product__r != null &&
                orderItem.ccrz__Product__r.Cvent_Event__c != null
            ) {
                orderItemByCventEventId.put(orderItem.ccrz__Product__r.Cvent_Event__c, orderItem);
            }
        }
        Map<Id, CVENT__Invitee__c> existingInvitees = new Map<Id, CVENT__Invitee__c>([
                SELECT
                        Id, CVENT__Contact_Id__c, CVENT__Event_Id__c, CVENT__Invitee_Status__c
                FROM
                        CVENT__Invitee__c
                WHERE
                        CVENT__Contact_Id__c = :invitedContactId
                AND
                        CVENT__Event_Id__c IN :orderItemByCventEventId.keySet()
        ]);
        for (Id cventEventId : orderItemByCventEventId.keySet()) {
            CVENT__Invitee__c invitee;
            if (existingInvitees.containsKey(cventEventId)) {
                invitee = existingInvitees.get(cventEventId);
            } else {
                invitee = new CVENT__Invitee__c(
                        CVENT__Contact_Id__c = invitedContactId,
                        CVENT__Event_Id__c = cventEventId
                );
            }
            invitee.CC_Order_Item__c = orderItemByCventEventId.get(cventEventId).Id;
            invitee.CC_Order__c      = orderItemByCventEventId.get(cventEventId).ccrz__Order__c;
            if (invitee.CVENT__Invitee_Status__c != CVENT_INVITEE_STATUS_APPROVED) {
                invitee.CVENT__Invitee_Status__c = CVENT_INVITEE_STATUS_APPROVED;
                invitees.add(invitee);
            }
        }
        return invitees;
    }

    private static CVENT__Nomination__c[] getNominations(CVENT__Invitee__c[] invitees) {
        CVENT__Nomination__c[] nominations = new CVENT__Nomination__c[]{};
        Map<Id, CVENT__Nomination__c> existingNominationsByEventAttendee = new Map<Id, CVENT__Nomination__c>();
        for (CVENT__Nomination__c existingNomination : [
                SELECT
                        Id, CVENT__Status__c, CVENT__Approval_Complete__c, CVENT__Attendee__c,
                        CVENT__Contact_Id__c, CVENT__Event_Id__c
                FROM
                        CVENT__Nomination__c
                WHERE
                        CVENT__Attendee__c IN :invitees
        ]) {
            existingNominationsByEventAttendee.put(existingNomination.CVENT__Attendee__c, existingNomination);
        }
        for (CVENT__Invitee__c invitee : invitees) {
            CVENT__Nomination__c nomination = existingNominationsByEventAttendee.get(invitee.Id);
            if (nomination == null) {
                nomination = new CVENT__Nomination__c(
                        CVENT__Approval_Complete__c = true,
                        CVENT__Attendee__c = invitee.Id,
                        CVENT__Contact_Id__c = invitee.CVENT__Contact_Id__c,
                        CVENT__Event_Id__c = invitee.CVENT__Event_Id__c
                );
            }
            nomination.CVENT__Status__c = CVENT_NOMINATION_STATUS_APPROVED;
            nominations.add(nomination);
        }
        return nominations;
    }

    private static ccrz__E_PriceListItem__c[] getPriceListItems(
            ccrz__E_Product__c[] products,
            Map<Id, CVENT__Cvent_Event__c> events
    ) {
        ccrz__E_PriceList__c privatePricelist = ACAMSCventEventService.getPrivatePriceList();
        ccrz__E_PriceListItem__c[] priceListItems = new ccrz__E_PriceListItem__c[]{};
        if (privatePricelist != null) {
            for (ccrz__E_Product__c product : products) {
                priceListItems.add(
                        ACAMSCventEventService.createPriceListItem(
                                product,
                                privatePricelist,
                                events.get(product.Cvent_Event__c)
                        )
                );
            }
        }
        return priceListItems;
    }

    private static ccrz__E_PriceList__c getPrivatePriceList() {
        return ACAMSCsrService.getNonMemberPricelist();
    }

    private static ccrz__E_Product__c createProductFromCventEvent(CVENT__Cvent_Event__c newEvent) {
        return new ccrz__E_Product__c(
                Name                      = newEvent.Name,
                ccrz__Storefront__c       = ACAMSCsrService.STOREFRONT_NAME_ACAMS,
                ccrz__SKU__c              = CVENT_PRODUCT_SKU_TEMPLATE + newEvent.CVENT__Event_Code__c,
                Cvent_Event__c            = newEvent.Id,
                Level_1__c                = CVENT_PRODUCT_LEVEL_1,
                Event_Address_City__c     = newEvent.CVENT__Event_Address_City__c,
                Event_Address_Country__c  = newEvent.CVENT__Event_Address_Country__c,
                Event_Address_State__c    = newEvent.CVENT__Event_Address_State__c,
                Event_Address_Street_1__c = newEvent.CVENT__Event_Address_Street_1__c,
                Event_Address_Street_2__c = newEvent.CVENT__Event_Address_Street_2__c,
                Event_Address_Street_3__c = newEvent.CVENT__Event_Address_Street_3__c,
                Event_Address_Zip__c      =  newEvent.CVENT__Event_Address_Zip__c,
                Event_Location__c         =  newEvent.CVENT__Event_Location__c
        );
    }

    private static ccrz__E_PriceListItem__c createPriceListItem(
            ccrz__E_Product__c    newProduct,
            ccrz__E_PriceList__c  privatePricelist,
            CVENT__Cvent_Event__c newEvent
    ) {
        return new ccrz__E_PriceListItem__c(
                ccrz__Pricelist__c = privatePricelist.Id,
                ccrz__Product__c   = newProduct.Id,
                ccrz__Price__c     = 0
        );
    }

}