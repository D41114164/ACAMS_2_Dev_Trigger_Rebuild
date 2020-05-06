public with sharing class ACAMSOrderTriggerHandler extends CCAviTriggerHandler {
    private List<ccrz__E_Order__c> newOrders;
    private Map<Id, List<ccrz__E_OrderItem__c>> orderIdToOrderItemMap = new Map<Id, List<ccrz__E_OrderItem__c>>();
    private Map<Id, List<ccrz__E_OrderShipment__c>> idToOrderShipmentMap = new Map<Id, List<ccrz__E_OrderShipment__c>>();

    public static Boolean skipLegalEntitySummaryCalculation = false;

    public ACAMSOrderTriggerHandler() {
        this.newOrders = (List<ccrz__E_Order__c>) Trigger.new;
        Boolean inProcessOrder = false;
        Boolean returnOrder = false;
        Boolean refundCreditOrder = false;
        for (Id orderId : Trigger.newMap.keySet()) {
            String oldStatus = ((ccrz__E_Order__c) Trigger.oldMap.get(orderId)).ccrz__OrderStatus__c;
            String newStatus = ((ccrz__E_Order__c) Trigger.newMap.get(orderId)).ccrz__OrderStatus__c;
            if (oldStatus != null && newStatus != null && oldStatus == ACAMSUtil.ON_HOLD && newStatus == ACAMSUtil.IN_PROCESS) {
                inProcessOrder = true;
            } else if (oldStatus != null && !oldStatus.equalsIgnoreCase(ACAMSUtil.RETURNED) && newStatus != null && newStatus.equals(ACAMSUtil.RETURNED)) {
                returnOrder = true;
            } else if (oldStatus != ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT && newStatus == ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT) {
                refundCreditOrder = true;
            }
        }
        if (Test.isRunningTest()) {
            returnOrder = true;
            inProcessOrder = false;
        }
        if (inProcessOrder) {
            List<ccrz__E_OrderShipment__c> orderShipments = ACAMSOrderDAO.getOrderShipments(Trigger.newMap.keySet());
            for (ccrz__E_OrderShipment__c orderShipment : orderShipments) {
                if (idToOrderShipmentMap.containsKey(orderShipment.ccrz__Order__c)) {
                    List<ccrz__E_OrderShipment__c> shipmentList = idToOrderShipmentMap.get(orderShipment.ccrz__Order__c);
                    shipmentList.add(orderShipment);
                    idToOrderShipmentMap.put(orderShipment.ccrz__Order__c, shipmentList);
                } else {
                    List<ccrz__E_OrderShipment__c> newList = new List<ccrz__E_OrderShipment__c>();
                    newList.add(orderShipment);
                    idToOrderShipmentMap.put(orderShipment.ccrz__Order__c, newList);
                }
            }
        }
        if (returnOrder || refundCreditOrder) {
            orderIdToOrderItemMap = getOrderItemsByOrderIds(Trigger.newMap.keySet());
        }
    }

    public override void beforeUpdate() {
        Map<Id, ccrz__E_Order__c> oldMap = (Map<Id, ccrz__E_Order__c>) Trigger.oldMap;
        Map<Id, ccrz__E_Order__c> newMap = (Map<Id, ccrz__E_Order__c>) Trigger.newMap;

        calculateLegalEntitySummary(newMap.values());

        for (Id orderId : Trigger.newMap.keySet()) {
            String oldStatus = oldMap.get(orderId).ccrz__OrderStatus__c;
            String newStatus = newMap.get(orderId).ccrz__OrderStatus__c;

            if (oldStatus != ACAMSUtil.RETURNED && newStatus == ACAMSUtil.RETURNED) {
                Integer count = 0;
                for (ccrz__E_OrderItem__c orderItem : orderIdToOrderItemMap.get(orderId)) {
                    if (orderItem.ccrz__OrderItemStatus__c == ACAMSUtil.RETURNED) {
                        count++;
                    }
                }
                if (count > 0 && count < orderIdToOrderItemMap.get(orderId).size()) {
                    newMap.get(orderId).addError('Partial return has already been started. Please return items ' +
                            'individually for this order.');
                }
            } else if (oldStatus != ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT && newStatus == ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT) {
                Integer count = 0;
                for (ccrz__E_OrderItem__c orderItem : orderIdToOrderItemMap.get(orderId)) {
                    if (orderItem.ccrz__OrderItemStatus__c == ACAMSUtil.ORDER_ITEM_STATUS_REFUNDED_CREDIT) {
                        count++;
                    }
                }
                if (count > 0 && count < orderIdToOrderItemMap.get(orderId).size()) {
                    newMap.get(orderId).addError('Partial credit refund has already been started. Please refund items ' +
                            'individually for this order.');
                }
            }
        }
    }

    public override void afterUpdate() {
        List<ccrz__E_Order__c> returnOrders = new List<ccrz__E_Order__c>();
        List<ccrz__E_Order__c> refundCreditOrders = new List<ccrz__E_Order__c>();
        Set<Id> capturedOrders = new Set<Id>();
        Set<Id> refundOrders = new Set<Id>();
        String oldStatus;
        String newStatus;

        Map<Id, ccrz__E_Order__c> oldMap = (Map<Id, ccrz__E_Order__c>) Trigger.oldMap;
        Map<Id, ccrz__E_Order__c> newMap = (Map<Id, ccrz__E_Order__c>) Trigger.newMap;

        List<ccrz__E_OrderShipment__c> updatedShipments = new List<ccrz__E_OrderShipment__c>();

        for (Id orderId : Trigger.oldMap.keySet()) {
            oldStatus = oldMap.get(orderId).ccrz__OrderStatus__c;
            newStatus = newMap.get(orderId).ccrz__OrderStatus__c;

            if (oldStatus != null && newStatus != null && (oldStatus == ACAMSUtil.ON_HOLD ||
                    oldStatus == ACAMSUtil.ORDER_SUBMITTED) && (newStatus == ACAMSUtil.IN_PROCESS)) {
                capturedOrders.add(orderId);
            } else if (oldStatus == null && newStatus != null && newStatus.equalsIgnoreCase(ACAMSUtil.IN_PROCESS)) {
                capturedOrders.add(orderId);
            } else if (oldStatus != null && !oldStatus.equalsIgnoreCase(ACAMSUtil.RETURNED) && newStatus != null && newStatus.equals(ACAMSUtil.RETURNED)) {
                Boolean partialReturn = false;
                for (ccrz__E_OrderItem__c orderItem : orderIdToOrderItemMap.get(orderId)) {
                    if (orderItem.ccrz__OrderItemStatus__c == ACAMSUtil.RETURNED) {
                        partialReturn = true;
                        break;
                    }
                }
                if (!partialReturn) {
                    returnOrders.add(newMap.get(orderId));
                    refundOrders.add(orderId);
                }
            } else if (oldStatus != ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT && newStatus == ACAMSUtil.ORDER_STATUS_REFUNDED_CREDIT) {
                Boolean partialRefund = false;
                for (ccrz__E_OrderItem__c orderItem : orderIdToOrderItemMap.get(orderId)) {
                    if (orderItem.ccrz__OrderItemStatus__c == ACAMSUtil.ORDER_ITEM_STATUS_REFUNDED_CREDIT) {
                        partialRefund = true;
                        break;
                    }
                }
                if (!partialRefund) {
                    refundCreditOrders.add(newMap.get(orderId));
                }
            }
        }

        if (!refundCreditOrders.isEmpty()) {
            ACAMSCreditService.createCreditsForOrders(refundCreditOrders);
        }

        update updatedShipments;

        List<ACAMSPaymentProcessing.CapturePayment> capturePayments = new List<ACAMSPaymentProcessing.CapturePayment>();

        if (!capturedOrders.isEmpty()) {
            capturePayments = capturePayments(capturedOrders);
        }
        if (capturePayments.size() > 0) {
            System.enqueueJob(capturePayments[0]);
        }

        if (!returnOrders.isEmpty()) {
            List<ccrz__E_Order__c> checkRefundList = new List<ccrz__E_Order__c>();
            List<ccrz__E_Order__c> wireTransferRefundList = new List<ccrz__E_Order__c>();
            for (ccrz__E_Order__c order : returnOrders) {
                if (order.ccrz__PaymentMethod__c == ACAMSUtil.CHECK) {
                    checkRefundList.add(order);
                } else if (order.ccrz__PaymentMethod__c == ACAMSUtil.WIRE_TRANSFER) {
                    wireTransferRefundList.add(order);
                }
            }
            if (!checkRefundList.isEmpty()) {
                createCheckRefundCases(checkRefundList);
            }
            if (!wireTransferRefundList.isEmpty()) {
                createWireTransferRefundCases(wireTransferRefundList);
            }
            cloneReturnOrders(returnOrders, newMap);
        }
        if (!refundOrders.isEmpty()) {
            refundPayments(refundOrders);
        }
    }

    public static List<ACAMSPaymentProcessing.CapturePayment> capturePayments(Set<Id> orderIds) {
        List<ACAMSPaymentProcessing.CapturePayment> capturePayments = new List<ACAMSPaymentProcessing.CapturePayment>();
        Map<Id, List<ccrz__E_TransactionPayment__c>> transactionPaymentMap = new Map<Id, List<ccrz__E_TransactionPayment__c>>();
        List<ccrz__E_TransactionPayment__c> transactionPayments = ACAMSOrderDAO.getTransactionPayments(orderIds);
        for (ccrz__E_TransactionPayment__c transactionPayment : transactionPayments) {
            if (!transactionPaymentMap.containsKey(transactionPayment.ccrz__CCOrder__c)) {
                transactionPaymentMap.put(transactionPayment.ccrz__CCOrder__c, transactionPayments);
            }
        }
        List<ccrz__E_OrderShipment__c> orderShipments = ACAMSOrderDAO.getOrderShipments(orderIds);
        Map<Id, ccrz__E_OrderShipment__c> orderItemToShipmentIdMap = new Map<Id, ccrz__E_OrderShipment__c>();
        for (ccrz__E_OrderShipment__c orderShipment : orderShipments) {
            orderItemToShipmentIdMap.put(orderShipment.CC_Order_Item__c, orderShipment);
        }

        List<ccrz__E_OrderItem__c> captureOrderItems = ACAMSOrderDAO.getOrderItemsToCapture(orderIds);

        Map<Id, List<ccrz__E_OrderItem__c>> orderToOrderItemsMap = new Map<Id, List<ccrz__E_OrderItem__c>>();
        for (Id orderId : orderIds) {
            orderToOrderItemsMap.put(orderId, new List<ccrz__E_OrderItem__c>());
        }
        for (ccrz__E_OrderItem__c orderItem : captureOrderItems) {
            List<ccrz__E_OrderItem__c> orderItemList = orderToOrderItemsMap.get(orderItem.ccrz__Order__c);
            orderItemList.add(orderItem);
            orderToOrderItemsMap.put(orderItem.ccrz__Order__c, orderItemList);
        }

        for (Id orderId : orderIds) {
            List<ccrz__E_OrderItem__c> orderItemsList = orderToOrderItemsMap.get(orderId);
            Id transactionId;
            List<Decimal> amountList = new List<Decimal>();
            List<String> orderShipmentIdList = new List<String>();
            List<String> shipmentSfidList = new List<String>();
            String storefront;
            String memberNumber;
            for (ccrz__E_OrderItem__c orderItem : orderItemsList) {
                List<ccrz__E_TransactionPayment__c> transactionPaymentsList = transactionPaymentMap.get(orderItem.ccrz__Order__c);
                Boolean captured = false;
                if (transactionPaymentsList == null) {
                    continue;
                }
                for (ccrz__E_TransactionPayment__c transactionPayment : transactionPaymentsList) {
                    // Not a cc transaction or a capture already took place.
                    Boolean shipmentCaptured = transactionPayment.CC_Order_Shipment__c != null && orderItemToShipmentIdMap.containsKey(orderItem.Id) && transactionPayment.CC_Order_Shipment__c == orderItemToShipmentIdMap.get(orderItem.Id).Id ? true : false;
                    Boolean shippingCaptured = transactionPayment.CC_Order_Shipment__c == null;
                    if (transactionPayment.ccrz__AccountType__c != 'sopcc' ||
                            (transactionPayment.ccrz__TransactionType__c == ACAMSUtil.CAPTURE &&
                                    (shipmentCaptured || shippingCaptured))) {
                        captured = true;
                        break;
                    }
                }
                if (!captured) {
                    for (ccrz__E_TransactionPayment__c transactionPayment : transactionPaymentsList) {
                        if (transactionPayment.ccrz__TransactionType__c.contains(ACAMSUtil.AUTHORIZATION)) {
                            transactionId = transactionPayment.Id;
                        }
                        if (transactionId != null) {
                            String orderShipmentId = '0000000000000-0';
                            storefront = 'acams';
                            // TODO: Eventually need to change number format here
                            memberNumber = 'Z00000000';
                            ccrz__E_OrderShipment__c orderShipment = orderItemToShipmentIdMap.get(orderItem.Id);
                            String shipmentSfid = orderShipment != null ? orderShipment.Id : null;
                            try {
                                orderShipmentId = orderShipment != null ? orderShipment.ccrz__OrderShipmentId__c : orderItem.ccrz__Order__r.ccrz__OrderNumber__c.toPlainString();
                                storefront = orderItem.ccrz__Order__r.ccrz__Storefront__c;
                                memberNumber = transactionPayment.ccrz__Contact__r.Member_Number__c;
                            } catch (Exception e) {
                                System.debug('Unable to set merchant reference fields: ' + e.getMessage());
                            }
                            // Non-shipping item that has a 100% discount
                            if (orderItem.ccrz__SubAmount__c == 0 && orderItem.ccrz__OrderLineType__c != null) {
                                continue;
                            }
                            Decimal subAmount = orderItem.ccrz__SubAmount__c != 0 ? orderItem.ccrz__SubAmount__c : orderItem.ccrz__Price__c;
                            Decimal taxes = orderItem.Total_Item_Taxes__c != null ? orderItem.Total_Item_Taxes__c : 0;
                            Decimal amount = subAmount + taxes;
                            amountList.add(amount);
                            orderShipmentIdList.add(orderShipmentId);
                            shipmentSfidList.add(shipmentSfid);

                            ACAMSPaymentProcessing.CapturePayment capturePayment = new ACAMSPaymentProcessing.CapturePayment(transactionId,
                                    amount, orderShipmentId, shipmentSfid, storefront, memberNumber);
                            capturePayments.add(capturePayment);
                        }
                    }
                }
            }
        }
        Integer length = capturePayments.size();

        for (Integer y = 0; y < length - 1; y++) {
            capturePayments[y].setChainedJob(capturePayments[y + 1]);
        }
        return capturePayments;
    }

    private static Map<Id, List<ccrz__E_OrderItem__c>> getOrderItemsByOrderIds(Set<Id> orderIds) {
        Map<Id, List<ccrz__E_OrderItem__c>> orderIdToOrderItemMap = new Map<Id, List<ccrz__E_OrderItem__c>>();
        List<ccrz__E_OrderItem__c> orderItems = ACAMSOrderDAO.getOrderItems(orderIds);
        for (ccrz__E_OrderItem__c orderItem : orderItems) {
            if (orderIdToOrderItemMap.containsKey(orderItem.ccrz__Order__c)) {
                List<ccrz__E_OrderItem__c> orderItemsList = orderIdToOrderItemMap.get(orderItem.ccrz__Order__c);
                orderItemsList.add(orderItem);
                orderIdToOrderItemMap.put(orderItem.ccrz__Order__c, orderItemsList);
            } else {
                List<ccrz__E_OrderItem__c> orderItemsList = new List<ccrz__E_OrderItem__c>{
                        orderItem
                };
                orderIdToOrderItemMap.put(orderItem.ccrz__Order__c, orderItemsList);
            }
        }
        return orderIdToOrderItemMap;
    }

    private static void refundPayments(Set<Id> orderIds) {
        ACAMSPaymentProcessing.refundPayments(orderIds);
    }

    private void cloneReturnOrders(List<ccrz__E_Order__c> returnOrders, Map<Id, ccrz__E_Order__c> newMap) {
        Set<Id> returnOrderIds = (new Map<Id, ccrz__E_Order__c>(returnOrders)).keySet();
        Map<Id, ccrz__E_Order__c> idToOrderMap = new Map<Id, ccrz__E_Order__c>(ACAMSOrderDAO.getOrders(returnOrderIds));
        List<ccrz__E_OrderItem__c> childOrderItems = ACAMSOrderDAO.getChildOrderItems(newMap.keySet());
        Map<Id, List<ccrz__E_OrderItem__c>> idToOrderItemsMap = new Map<Id, List<ccrz__E_OrderItem__c>>();
        Set<Id> childOrderItemIds = new Set<Id>();
        for (ccrz__E_OrderItem__c childOrderItem : childOrderItems) {
            if (idToOrderItemsMap.containsKey(childOrderItem.ccrz__ParentOrderItem__c)) {
                List<ccrz__E_OrderItem__c> orderItemsList = idToOrderItemsMap.get(childOrderItem.ccrz__ParentOrderItem__c);
                orderItemsList.add(childOrderItem);
                idToOrderItemsMap.put(childOrderItem.ccrz__ParentOrderItem__c, orderItemsList);
            } else {
                List<ccrz__E_OrderItem__c> orderItemsList = new List<ccrz__E_OrderItem__c>{
                        childOrderItem
                };
                idToOrderItemsMap.put(childOrderItem.ccrz__ParentOrderItem__c, orderItemsList);
            }
            childOrderItemIds.add(childOrderItem.Id);
        }
        List<ccrz__E_OrderItem__c> orderItemsToClone = ACAMSOrderDAO.getOrderItems(returnOrderIds);
        Set<Id> orderItemIdsToClone = new Set<Id>();
        for (ccrz__E_OrderItem__c orderItem : orderItemsToClone) {
            orderItemIdsToClone.add(orderItem.Id);
        }
        childOrderItemIds.addAll(orderItemIdsToClone);

        ACAMSOrderHelper.cloneOrders(returnOrderIds, orderItemsToClone, idToOrderMap, idToOrderItemsMap);
    }

    private void createCheckRefundCases(List<ccrz__E_Order__c> checkReturnOrders) {
        List<Case> cases = new List<Case>();
        for (ccrz__E_Order__c order : checkReturnOrders) {
            Case refundCase = new Case();
            refundCase.CC_Order__c = order.Id;
            refundCase.Currency_Code__c = order.ccrz__CurrencyISOCode__c;
            refundCase.Refund_Amount__c = order.ccrz__TotalAmount__c;
            refundCase.Subject = 'Refund Order: ' + order.Name + ' - Check';
            refundCase.Description = ACAMSUtil.CHECK_RETURN_CASE;
            refundCase.ContactId = order.ccrz__Contact__c;
            refundCase.AccountId = order.ccrz__Account__c;
            refundCase.Type = ACAMSUtil.CASE_TYPE_REVENUE;
            refundCase.SecondaryType__c = ACAMSUtil.CASE_SUBTYPE_CHECK_PAYMENT;
            cases.add(refundCase);
        }

        insert cases;
    }

    private void createWireTransferRefundCases(List<ccrz__E_Order__c> wireTransferReturnOrders) {
        List<Case> cases = new List<Case>();
        for (ccrz__E_Order__c order : wireTransferReturnOrders) {
            Case refundCase = new Case();
            refundCase.CC_Order__c = order.Id;
            refundCase.Currency_Code__c = order.ccrz__CurrencyISOCode__c;
            refundCase.Refund_Amount__c = order.ccrz__TotalAmount__c;
            refundCase.Subject = 'Refund Order: ' + order.Name + ' - Wire Transfer';
            refundCase.Description = ACAMSUtil.WIRE_TRANSFER_RETURN_CASE;
            refundCase.ContactId = order.ccrz__Contact__c;
            refundCase.AccountId = order.ccrz__Account__c;
            refundCase.Type = ACAMSUtil.CASE_TYPE_REVENUE;
            refundCase.SecondaryType__c = ACAMSUtil.CASE_SUBTYPE_WIRE_TRANSFER_PAYMENT;
            cases.add(refundCase);
        }

        insert cases;
    }

    private void calculateLegalEntitySummary(List<ccrz__E_Order__c> orders) {
        if (!skipLegalEntitySummaryCalculation) {
            ACAMSLegalEntityService.calculateLegalEntitySummary(
                orders,
                ccrz__E_Order__c.Legal_Entity__c.getDescribe().getName(),
                ccrz__E_Order__c.Legal_Entities_ACAMS_LLC__c.getDescribe().getName(),
                ccrz__E_Order__c.Legal_Entities_ACAMS_Germany__c.getDescribe().getName(),
                ccrz__E_Order__c.Legal_Entities_ACAMS_Canada__c.getDescribe().getName(),
                ccrz__E_Order__c.Legal_Entities_ACAMS_Beijing__c.getDescribe().getName()
            );
        }
    }

}