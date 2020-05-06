public with sharing class ACAMSOrderHelper {

    private static List<ccrz__E_Order__c> ordersToCreate = new List<ccrz__E_Order__c>();
    private static List<ccrz__E_OrderItem__c> orderItemsToCreate = new List<ccrz__E_OrderItem__c>();

    public static void cloneOrders(Set<Id> orderIds, List<ccrz__E_OrderItem__c> orderItemsToClone,
            Map<Id, ccrz__E_Order__c> idToOrderMap, Map<Id, List<ccrz__E_OrderItem__c>> idToOrderItemsMap) {
        Map<Id, ccrz__E_Order__c> idToClonedOrderMap = new Map<Id, ccrz__E_Order__c>();
        Map<Id, ccrz__E_OrderItem__c> idToClonedOrderItemMap = new Map<Id, ccrz__E_OrderItem__c>();
        for (Id orderId : orderIds) {
            ccrz__E_Order__c returnOrder = idToOrderMap.get(orderId).clone(false, true, false, false);
            returnOrder.ccrz__OrderNumber__c = null;
            returnOrder.ccrz__Name__c = ACAMSUtil.RETURNED_ORDER;
            returnOrder.ccrz__Order__c = orderId;
            returnOrder.ccrz__OrderDate__c = Date.today();
            returnOrder.ccrz__TaxAmount__c = 0;
            returnOrder.ccrz__ShipAmount__c = 0;
            ordersToCreate.add(returnOrder);
        }
        insert ordersToCreate;
        for (ccrz__E_Order__c order : ordersToCreate) {
            idToClonedOrderMap.put(order.ccrz__Order__c, order);
        }

        idToClonedOrderItemMap = cloneOrderItems(idToClonedOrderMap, orderItemsToClone, idToOrderItemsMap, idToClonedOrderItemMap);
        insert orderItemsToCreate;
        Map<Id, ccrz__E_OrderItem__c> productIdToOrderItemMap = new Map<Id, ccrz__E_OrderItem__c>();
        Set<Id> orderItemIdsToClone = new Set<Id>();
        for (ccrz__E_OrderItem__c orderItem : orderItemsToClone) {
            productIdToOrderItemMap.put(orderItem.ccrz__Product__c, orderItem);
            if (idToOrderItemsMap.containsKey(orderItem.Id)) {
                for (ccrz__E_OrderItem__c childOrderItem : idToOrderItemsMap.get(orderItem.Id)) {
                    productIdToOrderItemMap.put(childOrderItem.ccrz__Product__c, childOrderItem);
                }
            }
            orderItemIdsToClone.add(orderItem.Id);
        }
        for (ccrz__E_OrderItem__c orderItem : orderItemsToCreate) {
            if (productIdToOrderItemMap.containsKey(orderItem.ccrz__Product__c)) {
                idToClonedOrderItemMap.put(productIdToOrderItemMap.get(orderItem.ccrz__Product__c).Id, orderItem);
            }
        }

        Set<Id> clonedOrderIds = new Set<Id>();
        for (ccrz__E_Order__c order : ordersToCreate) {
            clonedOrderIds.add(order.Id);
        }
        List<ccrz__E_OrderItem__c> orderItemsList = ACAMSOrderDAO.getOrderItems(clonedOrderIds);
        List<ccrz__E_Order__c> ordersToUpdate = new List<ccrz__E_Order__c>();
        Map<Id, Decimal> orderIdToTotalAmountMap = new Map<Id, Decimal>();
        for (ccrz__E_OrderItem__c orderItem : orderItemsList) {
            orderItem.ccrz__Order__r.ccrz__TaxAmount__c += orderItem.Total_Item_Taxes__c != null ? orderItem.Total_Item_Taxes__c : 0;
            if (orderItem.ccrz__SubAmount__c == 0) {
                orderItem.ccrz__Order__r.ccrz__ShipAmount__c += orderItem.ccrz__Price__c;
            }
            orderItem.ccrz__Order__r.ccrz__OrderStatus__c = ACAMSUtil.RETURNED;
            orderItem.ccrz__Order__r.ccrz__OrderNumber__c = Long.valueOf(orderItem.ccrz__Order__r.Name.substring(2)) + Long.valueOf(ACAMSUtil.ORDER_NUMBER_START);
            orderIdToTotalAmountMap.put(orderItem.ccrz__Order__r.ccrz__Order__c, orderItem.ccrz__Order__r.ccrz__TotalAmount__c);
            ordersToUpdate.add(orderItem.ccrz__Order__r);
        }
        Set<ccrz__E_Order__c> ordersToUpdateSet = new Set<ccrz__E_Order__c>();
        ordersToUpdateSet.addAll(ordersToUpdate);
        ordersToUpdate.clear();
        ordersToUpdate.addAll(ordersToUpdateSet);
        update ordersToUpdate;

        List<ccrz__E_TransactionPayment__c> transactionPayments = ACAMSOrderDAO.getTransactionPayments(orderIds);
        Map<Id, List<ccrz__E_TransactionPayment__c>> orderIdToTransactionPaymentsMap = new Map<Id, List<ccrz__E_TransactionPayment__c>>();
        for (ccrz__E_TransactionPayment__c tp : transactionPayments) {
            if (orderIdToTransactionPaymentsMap.containsKey(tp.ccrz__CCOrder__c)) {
                List<ccrz__E_TransactionPayment__c> transactionPaymentsList = orderIdToTransactionPaymentsMap.get(tp.ccrz__CCOrder__c);
                transactionPaymentsList.add(tp);
                orderIdToTransactionPaymentsMap.put(tp.ccrz__CCOrder__c, transactionPaymentsList);
            } else {
                List<ccrz__E_TransactionPayment__c> transactionPaymentsList = new List<ccrz__E_TransactionPayment__c>{
                        tp
                };
                orderIdToTransactionPaymentsMap.put(tp.ccrz__CCOrder__c, transactionPaymentsList);
            }
        }
        List<ccrz__E_OrderShipment__c> orderShipments = ACAMSOrderShipmentDAO.getOrderShipmentsByOrderItems(orderItemIdsToClone);
        Set<String> orderShipmentIds = new Set<String>();
        for (ccrz__E_OrderShipment__c orderShipment : orderShipments) {
            orderShipmentIds.add(orderShipment.ccrz__OrderShipmentId__c);
        }
        List<ccrz__E_TransactionPayment__c> transactionsToRefund = new List<ccrz__E_TransactionPayment__c>();
        List<ccrz__E_Order__c> clonedOrdersList = ACAMSOrderDAO.getOrders(clonedOrderIds);
        Boolean fullRefund = false;
        for (ccrz__E_Order__c order : clonedOrdersList) {
            if (orderIdToTransactionPaymentsMap.containsKey(order.ccrz__Order__c)) {
                for (ccrz__E_TransactionPayment__c tp : orderIdToTransactionPaymentsMap.get(order.ccrz__Order__c)) {
                    if (order.ccrz__Order__r.ccrz__OrderStatus__c != ACAMSUtil.RETURNED &&
                            tp.ccrz__Amount__c == order.ccrz__TotalAmount__c &&
                            (orderShipmentIds.contains(tp.CC_Order_Shipment__r.ccrz__OrderShipmentId__c) ||
                                    tp.CC_Order_Shipment__r.ccrz__OrderShipmentId__c == null)) {
                        if (tp.ccrz__AccountType__c == 'sopcc' && !tp.ccrz__TransactionType__c.contains('authorization')) {
                            transactionsToRefund.add(tp);
                        }
                    } else if (order.ccrz__Order__r.ccrz__OrderStatus__c == ACAMSUtil.RETURNED) {
                        if (tp.ccrz__AccountType__c == 'sopcc' && !tp.ccrz__TransactionType__c.contains('authorization') && tp.ccrz__TransactionType__c == ACAMSUtil.CAPTURE) {
                            transactionsToRefund.add(tp);
                            fullRefund = true;
                        }
                    }
                }
            }
        }
        Set<Id> transactionIds = new Set<Id>();
        List<ccrz__E_TransactionPayment__c> transactionsToClone = new List<ccrz__E_TransactionPayment__c>();
        Set<Id> orderIdsWithTransactions = new Set<Id>();
        for (ccrz__E_TransactionPayment__c tp : transactionsToRefund) {
            transactionIds.add(tp.Id);
            ccrz__E_TransactionPayment__c clonedTp = tp.clone(false, true, false, false);
            if (idToClonedOrderMap.containsKey(tp.ccrz__CCOrder__c)) {
                clonedTp.ccrz__TransactionPaymentId__c = null;
                clonedTp.ccrz__TransactionType__c = ACAMSUtil.CREDIT;
                clonedTp.ccrz__TransactionTS__c = Datetime.now();
                clonedTp.ccrz__CCOrder__c = idToClonedOrderMap.get(tp.ccrz__CCOrder__c).Id;
                if (fullRefund) {
                    if (!orderIdsWithTransactions.contains(tp.ccrz__CCOrder__c)) {
                        clonedTp.ccrz__Amount__c = tp.ccrz__CCOrder__r.ccrz__TotalAmount__c;
                        clonedTp.ccrz__RequestAmount__c = tp.ccrz__CCOrder__r.ccrz__TotalAmount__c;
                        transactionsToClone.add(clonedTp);
                        orderIdsWithTransactions.add(tp.ccrz__CCOrder__c);
                    }
                } else {
                    transactionsToClone.add(clonedTp);
                }
            }
        }
        insert transactionsToClone;

        if (!fullRefund) {
            ACAMSPaymentProcessing.refundTransactionsFuture(transactionIds);
        }
    }

    private static Map<Id, ccrz__E_OrderItem__c> cloneOrderItems(Map<Id, ccrz__E_Order__c> idToClonedOrderMap,
            List<ccrz__E_OrderItem__c> orderItems, Map<Id, List<ccrz__E_OrderItem__c>> idToOrderItemsMap,
            Map<Id, ccrz__E_OrderItem__c> idToClonedOrderItemMap) {
        for (ccrz__E_OrderItem__c orderItem : orderItems) {
            ccrz__E_OrderItem__c returnOrderItem = orderItem.clone(false, true, false, false);
            returnOrderItem.ccrz__Order__c = idToClonedOrderMap.get(orderItem.ccrz__Order__c) != null ? idToClonedOrderMap.get(orderItem.ccrz__Order__c).Id : null;
            returnOrderItem.Original_Order_Item__c = orderItem.Id;
            insert returnOrderItem;
            idToClonedOrderItemMap.put(orderItem.Id, returnOrderItem);
            if (idToOrderItemsMap.containsKey(orderItem.Id)) {
                for (ccrz__E_OrderItem__c childOrderItem : idToOrderItemsMap.get(orderItem.Id)) {
                    ccrz__E_OrderItem__c returnChildOrderItem = childOrderItem.clone(false, true, false, false);
                    returnChildOrderItem.ccrz__Order__c = idToClonedOrderMap.get(childOrderItem.ccrz__Order__c) != null ? idToClonedOrderMap.get(childOrderItem.ccrz__Order__c).Id : null;
                    returnChildOrderItem.ccrz__ParentOrderItem__c = returnOrderItem.Id;
                    returnChildOrderItem.Original_Order_Item__c = childOrderItem.Id;
                    orderItemsToCreate.add(returnChildOrderItem);
                }
            }
        }
        return idToClonedOrderItemMap;
    }

}