public with sharing class ACAMSTransactionPaymentTriggerHandler extends CCAviTriggerHandler {
    private List<ccrz__E_TransactionPayment__c> newTransactionPayments;

    public ACAMSTransactionPaymentTriggerHandler() {
        this.newTransactionPayments = (List<ccrz__E_TransactionPayment__c>) Trigger.new;
    }

    public override void beforeInsert() {
        List<ccrz__E_TransactionPayment__c> captureList = new List<ccrz__E_TransactionPayment__c>();
        for (ccrz__E_TransactionPayment__c tp : newTransactionPayments) {
            if (tp.ccrz__TransactionType__c == 'capture') {
                captureList.add(tp);
            }
        }

        Set<Id> orderIds = new Set<Id>();
        for (ccrz__E_TransactionPayment__c tp : captureList) {
            orderIds.add(tp.ccrz__CCOrder__c);
        }

        List<ccrz__E_Order__c> orderList = ACAMSOrderDAO.getInvoiceOrders(orderIds);

        Map<Id, ccrz__E_Order__c> orderIdMap = new Map<Id, ccrz__E_Order__c>();
        for (ccrz__E_Order__c order : orderList) {
            if (!orderIdMap.containsKey(order.Id)) {
                orderIdMap.put(order.Id, order);
            }
        }

        List<ccrz__E_Invoice__c> invoiceUpdateList = new List<ccrz__E_Invoice__c>();
        for (ccrz__E_TransactionPayment__c tp : captureList) {
            ccrz__E_Order__c order = orderIdMap.get(tp.ccrz__CCOrder__c);
            if (order != null && order.ccrz__CCInvoices__r != null && !order.ccrz__CCInvoices__r.isEmpty() && order.ccrz__CCInvoices__r.get(0) != null) {
                ccrz__E_Invoice__c invoice = order.ccrz__CCInvoices__r.get(0);
                tp.ccrz__InvoiceAppliedFor__c = invoice.Id;
                invoice.ccrz__RemainingAmount__c = invoice.ccrz__RemainingAmount__c - tp.ccrz__Amount__c;
                if (invoice.ccrz__RemainingAmount__c == 0) {
                    invoice.ccrz__Status__c = 'Paid';
                    invoice.Finalized__c = true;
                }
                invoiceUpdateList.add(invoice);
            }
        }
        if (!invoiceUpdateList.isEmpty()) {
            System.enqueueJob(new ACAMSUtil.UpdateObject(invoiceUpdateList));
        }
    }
}